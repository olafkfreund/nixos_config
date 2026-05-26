# Runtime setup: "Just-Finished" recommendation workflow

> Companion to docs/plans/2026-05-26-plex-llm-recommendations-design.md
> These steps run AFTER `features.n8n.enable = true` is deployed to p510 and
> need a running n8n + your live API keys. n8n is at <http://127.0.0.1:5678> on
> p510 (loopback only — reach it via `ssh -L 5678:127.0.0.1:5678 p510` or add a
> tailscale-serve path).

## 0. First-run

1. Tunnel to n8n: `ssh -L 5678:localhost:5678 p510`, open <http://localhost:5678>.
2. Create the owner account (local, stays on p510).
3. The encryption key is already provided by NixOS (agenix → `N8N_ENCRYPTION_KEY_FILE`),
   so credentials you add below survive rebuilds.

## 1. Credentials to add (Settings → Credentials)

Create these as n8n credentials (encrypted in n8n's store by the agenix key):

| Name | Type | Value / fields |
|---|---|---|
| Overseerr | Header Auth | header `X-Api-Key` = Overseerr API key (Overseerr → Settings → General → API Key) |
| Tautulli | (used as query param, no cred needed) | API key from Tautulli → Settings → Web Interface → API |
| Home Assistant | Header Auth | header `Authorization` = `Bearer <long-lived token>` (HA → profile → Long-Lived Access Tokens) |
| Ollama | (none) | local `http://127.0.0.1:11434`, no auth |

## 2. Tautulli webhook (the trigger)

Tautulli → Settings → Notification Agents → Add → **Webhook**.

- **Webhook URL:** `http://127.0.0.1:5678/webhook/just-finished`
- **Trigger:** enable **Watched** (fires at the ~90% completion threshold — this is
  why the workflow debounces TV per-show/day; every binged episode crosses it).
- **Data → Watched → JSON template** (CRITICAL — default body lacks the ids):

```json
{
  "event": "watched",
  "media_type": "{media_type}",
  "title": "{title}",
  "year": "{year}",
  "grandparent_title": "{grandparent_title}",
  "season_num": "{season_num00}",
  "episode_num": "{episode_num00}",
  "tmdb_id": "{themoviedb_id}",
  "tvdb_id": "{thetvdb_id}",
  "rating_key": "{rating_key}",
  "user": "{user}"
}
```

> `media_type` is `movie` or `episode`. For episodes, `{themoviedb_id}` may resolve
> to the episode rather than the show; if so, use `{thetvdb_id}` + an Overseerr
> `/search` to get the show's TMDB id (see node 3 note). Verify the real payload
> with Tautulli's "Test Notification" → check n8n's webhook execution.

## 3. Workflow (node by node)

Webhook → Code(debounce) → HTTP(candidates) → HTTP(history) → Code(prompt) →
HTTP(ollama) → Code(validate+dedup) → HTTP(Overseerr request) → HTTP(HA notify).

**Node 1 — Webhook** (`n8n-nodes-base.webhook`)

- HTTP Method POST, Path `just-finished`, Response "When last node finishes".

**Node 2 — Code (debounce)** — drops TV repeats within a day:

```js
const s = $getWorkflowStaticData('global');
const i = $json.body ?? $json;
const today = new Date().toISOString().slice(0,10);
if (i.media_type === 'movie') return [{ json: i }];
s.seen = s.seen || {};
// prune keys not from today
for (const k of Object.keys(s.seen)) if (!k.endsWith(today)) delete s.seen[k];
const key = (i.grandparent_title || i.title) + '|' + today;
if (s.seen[key]) return [];          // already triggered for this show today
s.seen[key] = true;
return [{ json: i }];
```

**Node 3 — HTTP (Overseerr candidates)** — cred: Overseerr

- Movie: `GET http://127.0.0.1:5055/api/v1/movie/{{$json.tmdb_id}}/recommendations`
- TV:    `GET http://127.0.0.1:5055/api/v1/tv/{{showTmdbId}}/recommendations`
- For TV without a show TMDB id, first `GET /api/v1/search?query={{title}}` to
  resolve it. Optionally also call `/similar` and merge.
- Each result carries `mediaInfo.status` (5 = available, 3/4 = requested) — used
  for dedup in node 7.

**Node 4 — HTTP (Tautulli history)** — taste signal

- `GET http://127.0.0.1:8181/api/v2?apikey=<TAUTULLI_KEY>&cmd=get_history&length=25`
- Extract recent `title` / `grandparent_title` list.

**Node 5 — Code (build prompt)** — assemble the gemma request payload:

```js
const finished = $('Webhook').item.json.body ?? $('Webhook').item.json;
const cands = ($('Overseerr candidates').item.json.results || [])
  .filter(c => !c.mediaInfo || c.mediaInfo.status < 3)        // not owned/requested
  .slice(0, 40)
  .map(c => ({ tmdb_id: c.id, title: c.title || c.name,
               year: (c.releaseDate||c.firstAirDate||'').slice(0,4),
               overview: (c.overview||'').slice(0,300) }));
const history = ($('Tautulli history').item.json.response.data.data || [])
  .map(h => h.grandparent_title || h.title).slice(0, 25);
return [{ json: { finished, candidates: cands, history } }];
```

**Node 6 — HTTP (ollama / gemma)** — cred: none, local

- `POST http://127.0.0.1:11434/api/chat`, JSON body:

```json
{
  "model": "gemma4:e4b",
  "stream": false,
  "format": "json",
  "messages": [
    {"role": "system", "content": "You are a media curator. Choose ONLY from the CANDIDATES array — never invent titles or ids. Pick at most 3 the viewer will most likely enjoy after JUST_FINISHED, given their recent HISTORY. Prefer strong thematic/tonal matches and variety; never pick anything already in HISTORY. Respond with strict JSON: {\"picks\":[{\"tmdb_id\":<int from candidates>,\"title\":\"<exact candidate title>\",\"why\":\"one short sentence\"}]}."},
    {"role": "user", "content": "={{ JSON.stringify({ just_finished: $json.finished.title, history: $json.history, candidates: $json.candidates }) }}"}
  ]
}
```

- `format: json` forces parseable output from ollama.

**Node 7 — Code (validate + dedup)** — enforce the anti-hallucination contract:

```js
const out = JSON.parse($json.message.content);
const valid = new Map(($('Build prompt').item.json.candidates).map(c => [c.tmdb_id, c]));
const finished = $('Build prompt').item.json.finished;
const isTv = finished.media_type === 'episode';
const picks = (out.picks || [])
  .filter(p => valid.has(p.tmdb_id))     // candidate-only: drop hallucinations
  .slice(0, 3)
  .map(p => ({ tmdb_id: p.tmdb_id, title: valid.get(p.tmdb_id).title,
               why: String(p.why || '').slice(0, 160), mediaType: isTv ? 'tv':'movie' }));
return picks.map(json => ({ json }));
```

**Node 8 — HTTP (Overseerr create request)** — cred: Overseerr, runs per pick

- `POST http://127.0.0.1:5055/api/v1/request`
- Body: `{ "mediaType": "{{$json.mediaType}}", "mediaId": {{$json.tmdb_id}} }`
  (for a tv request, also add `"seasons": "all"` to the body).
- **Auto-approve nuance:** Overseerr auto-approves requests made with an *admin*
  API key. To keep picks **pending**, either (a) create a dedicated non-admin
  Overseerr user without auto-approve and request on its behalf
  (`"userId": <id>`), or (b) accept auto-add and treat the HA push as the
  notification (closer to the "fully autonomous" mode). Pick per your taste; the
  design intends (a).

**Node 9 — HTTP (Home Assistant notify)** — cred: Home Assistant, runs once (merge picks first with an Aggregate/Code node)

- `POST http://<ha-host>:8123/api/services/notify/<your_mobile_app>`
- Body:

```json
{ "title": "Finished {{finishedTitle}} — picks pending",
  "message": "{{picks.map((p,i)=>`${i+1}. ${p.title} — ${p.why}`).join('\n')}}",
  "data": { "url": "http://<overseerr>/requests" } }
```

## 4. End-to-end test

1. Tautulli → the Webhook agent → **Test Notification** → confirm n8n logs an
   execution and the payload has `tmdb_id`/`media_type`.
2. Manually run the workflow on that payload; confirm gemma returns valid JSON and
   only in-candidate picks survive node 7.
3. Confirm pending requests appear in Overseerr and the HA push arrives.
4. Finish a real title in Plex → full path fires.

## 5. Phase 2/3 hooks (not built yet)

- **Music:** add a branch — Plex-played music in the Tautulli payload
  (`media_type == 'track'`) → Lidarr `/api/v1/...` similar-artist candidates →
  gemma rank → HA push with an **actionable button** whose callback hits a second
  n8n webhook that adds the artist to Lidarr (Lidarr has no pending queue).
- **Books:** separate Audiobookshelf webhook trigger; ebooks need Readarr added.
