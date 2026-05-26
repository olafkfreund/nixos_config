# Design: LLM-Curated "Just-Finished" Recommendations

> Created: 2026-05-26
> Status: Approved (design) — ready for implementation planning
> Host: p510 (media server)
> Topic: gemma + n8n discovery/auto-request layer over the Plex ecosystem

## Summary

When you finish a movie or TV show in Plex, a local LLM (gemma4:e4b on p510)
proposes a few *real*, taste-matched titles you don't already own. The picks
land as **pending Overseerr requests** plus a **Home Assistant push** that
explains each choice. You approve in Overseerr; acquisition then proceeds
through the existing Radarr/Sonarr → download-client → Plex pipeline unchanged.

The LLM adds the one thing the *arr stack cannot: taste reasoning about *what*
to bring in. The*arr stack remains the muscle that brings it in. No existing
acquisition or organization behavior changes.

## Goals & success criteria

- Finishing a film/series surfaces 3 relevant, real (non-hallucinated) titles
  not already in the library or already requested.
- Picks arrive as pending Overseerr requests + an HA push with a one-line "why"
  per pick and a deep link to Overseerr's approval screen.
- Zero new request UI (reuse Overseerr's approval queue).
- A TV binge produces at most one recommendation cycle per show per day.
- p510 stays self-contained: no runtime dependency on p620.

## Non-goals (v1)

- Music and book/audiobook recommendations (Phases 2–3).
- Natural-language / chat control (explicitly deferred subsystem).
- Library cleanup / file sorting (separate subsystem).
- Fully autonomous auto-add (approval stays in the loop).

## Locked decisions (from design interview)

| Decision | Choice | Rationale |
|---|---|---|
| Primary outcome | Discovery & auto-requests | Highest-leverage LLM use; *arr stack already handles acquisition/organization |
| Autonomy | Propose & approve via Overseerr | Reuses Overseerr's native approval queue + notifications; builds trust |
| Rec engine | Grounded re-ranking on free sources | 4B model hallucinates if it freelances; grounding on real candidates fixes it; no new API keys |
| Trigger | Event-driven ("just finished") | Contextual, timely; needs no chat interface |
| Notify | Home Assistant push | Instant phone push suits the "just finished on the couch" moment |
| Noise control | Movie on finish; TV debounced 1×/show/day | Avoids per-episode binge spam without finale detection |
| LLM endpoint (derived) | Local gemma4:e4b @ 127.0.0.1:11434 | Already reserved "for n8n"; keeps p510 self-contained |
| n8n host (derived) | p510 | Co-located with Tautulli/Overseerr/Lidarr/ollama → all calls localhost |

## Architecture (all components on p510)

```text
Plex play ─▶ Tautulli (Webhook notification agent, "Watched" event)
                │  POST payload: title, media_type, tmdb/tvdb id, show/season/episode
                ▼
            ┌─────────── n8n (new service, :5678) ───────────┐
            │ 1 debounce   (movie=always; TV=1×/show/day)     │
            │ 2 candidates ◀─ Overseerr discover/similar/recs │
            │ 3 taste      ◀─ Tautulli get_history            │
            │ 4 rank+why   ◀─▶ gemma4:e4b @ 127.0.0.1:11434   │
            │ 5 dedup      ◀─ Overseerr library/requests      │
            │ 6 request    ─▶ Overseerr (pending)             │
            │ 7 notify     ─▶ Home Assistant notify (push)    │
            └──────────────────────────────────────────────────┘
                                              │ user approves in Overseerr
                                              ▼  → Radarr/Sonarr acquire (unchanged)
```

## Components

- **Tautulli** (event source) — add a Webhook notification agent on the "Watched"
  trigger, POSTing item metadata to the n8n webhook URL.
- **n8n** (orchestrator) — NEW NixOS service on p510 (`services.n8n`), behind a
  feature flag, hardened (DynamicUser/ProtectSystem). Holds the workflow and
  credentials.
- **gemma4:e4b via ollama** (ranker) — existing on p510; on-demand load; called
  over localhost OpenAI-compatible/ollama API.
- **Overseerr** (candidate source + approval + acquisition trigger) — provides
  TMDB-backed similar/recommended candidates (no extra key) and the pending-request
  approval queue.
- **Home Assistant** (notification sink) — `notify` service → companion-app push.

## Data flow (v1 pipeline)

1. **Trigger** — Tautulli "Watched" webhook → n8n `/webhook/just-finished`.
2. **Debounce** — movie → proceed; TV → skip if `show:date` key already seen
   today (n8n static data).
3. **Candidates** — Overseerr API similar/recommended for the finished title →
   set of real TMDB titles.
4. **Taste** — Tautulli `get_history` (recent N plays) as the preference signal.
5. **Rank** — gemma receives `{just_finished, candidates[], recent_history[]}`
   and returns top-3 **chosen only from `candidates[]`**, each with a one-line
   "why," as strict JSON.
6. **Dedup** — drop titles already in library or already requested (Overseerr).
7. **Act** — create pending Overseerr requests for survivors (auto-approve OFF).
8. **Notify** — n8n → HA `notify` push: the picks, the "why," and a deep link to
   Overseerr's approval screen.

## gemma contract (anti-hallucination)

- gemma **selects and orders from the candidate array only**; it never invents
  titles. It writes the rationale text.
- n8n maps each returned pick back to a candidate by TMDB id. **Any pick whose id
  is not in the input candidate set is discarded.**
- Output is strict JSON, validated by n8n. On parse failure: one stricter
  re-prompt; if it still fails, fall back to the top-N candidates unranked (no "why").
- This bounds the model to filter/rank/explain — the task a 4B model does reliably.

## Known wrinkles (carried into later phases)

- **Music approval differs:** Lidarr has no pending queue and auto-searches on
  add. So music picks must be **held in n8n** and only added to Lidarr when the
  user taps an **actionable button in the HA push** (companion app → callback
  webhook → n8n). → Phase 2.
- **Books can't use this trigger:** Audiobookshelf is invisible to Tautulli and
  there is no ebook pipeline (no Readarr). → Phase 3 (ABS webhook + Readarr
  decision).

## Secrets & configuration

New agenix secrets:

- `n8n-encryption-key` — n8n credential store key.
- `overseerr-api-key` — post requests + query discovery.
- `tautulli-api-key` — pull watch history for taste.
- `home-assistant-token` — long-lived token for the `notify` call.

Lidarr API key (Phase 2) read from `config.xml` at runtime, matching the existing
recyclarr pattern (no secret needed).

New module `modules/services/n8n.nix` (feature-flagged, hardened), enabled on
p510. Follows docs/PATTERNS.md; no `mkIf true`, explicit imports, runtime secret
loading only.

## Error handling & guardrails

- Hard daily cap on total requests created.
- gemma JSON validation + single re-prompt + unranked fallback.
- If Overseerr / HA / ollama is unreachable: log + one HA "engine error" ping; no
  partial state written.
- Dedup against library + existing requests always on.
- On-demand gemma load latency on first call after idle is accepted.

## Testing strategy

- **Trigger:** Tautulli "send test webhook" → assert n8n run fires.
- **Ranking:** validate gemma prompt produces valid JSON over sample candidate
  sets; confirm out-of-set picks are discarded.
- **End-to-end:** finish a title → a pending Overseerr request appears + an HA
  push arrives.
- **Build:** `just test-host p510` for the new n8n module.

## Phasing

- **v1** — Movies + TV: full pipeline above.
- **Phase 2** — Plex-played music: Lidarr add-on-approve via HA action button.
- **Phase 3** — Books: ABS webhook + Readarr (ebooks) decision / audiobook routing.
- **Phase 4 (optional)** — External taste APIs (Trakt, Last.fm/ListenBrainz);
  weekly-digest complement to the event trigger.

## Implementation notes (from spec review — pin down during planning)

- **"Watched" = threshold, not EOF.** Tautulli's "Watched" event fires at a
  configurable watch-completion threshold (default ~90%), not literal end-of-file.
  This is *why* the per-show/day debounce exists (every binged episode crosses the
  threshold). Match the debounce semantics to this.
- **Payload must carry the id explicitly.** Tautulli does not include
  `themoviedb_id`/`thetvdb_id` in the default webhook body — the custom JSON
  payload template must add `{themoviedb_id}` / `{thetvdb_id}` (and title/type/
  show/season) explicitly. This is the single most likely wiring surprise; the
  implementation plan should specify the exact payload template.
- **Overseerr deep link.** Confirm whether Overseerr exposes a stable per-request
  approval URL vs. only a generic pending-requests view; the HA digest's link
  depth depends on it.
- **n8n exposure.** v1 calls are localhost-only, but Phase 2's HA action-button
  callback needs n8n's `/webhook/...` reachable — consider mirroring the existing
  `tailscale-serve.nix` pattern (which already maps `/overseerr`, `/tautulli`) for
  n8n at that point.

## Decision log

- Chose grounded re-ranking over pure-gemma because gemma4:e4b (~4B) hallucinates
  non-existent titles, producing dead-end Overseerr requests.
- Chose Overseerr-native approval over a custom UI because Overseerr already ships
  an approval queue + notification agents.
- Chose local gemma over the p620 LiteLLM router to avoid a cross-host runtime
  dependency; the model was already reserved on p510 for n8n.
- Chose event-driven over weekly digest per user preference (contextual timing);
  weekly digest demoted to optional Phase 4.
- Chose per-show/day debounce over finale-detection to avoid the extra
  Sonarr/TMDB lookup while still killing binge spam.
