# Audiobook automation (p510)

End-to-end audiobook **acquisition + management** on the p510 media server,
wired into the existing Transmission, Prowlarr, SABnzbd, Audiobookshelf and the
local Ollama. Two acquisition sources (AudioBookBay torrents + NZBGeek Usenet),
automatic import into Audiobookshelf with LLM-cleaned metadata and optional M4B
chaptering, and a natural-language MCP interface.

> **Legal note:** AudioBookBay distributes copyrighted material without
> authorization; NZBGeek is a paid Usenet indexer. The pipeline is
> source-agnostic and works identically for LibriVox / public-domain / owned
> content. Treat ABB as one configurable indexer.

## Components

| Module / pkg | What it does | Where |
|---|---|---|
| `features.audiobookbay-automated` | Flask web UI: search AudioBookBay, send magnet → Transmission | `audiobookbay-automated.nix` (port 5078) |
| `features.audiobook-import` | Timer (5 min) → Ollama metadata → m4b merge → Audiobookshelf | `audiobook-import.nix` + `.py` |
| `features.audiobook-mcp` | FastMCP SSE server: NL search/grab over both sources + library | `audiobook-mcp.nix` (port 3012) |
| `pkgs.customPkgs.m4b-tool` | Merge multi-file books → chaptered M4B | `pkgs/m4b-tool` |
| `qwen2.5:7b` (Ollama) | Strict-JSON metadata extraction from release names | p510 `onDemandModels` |

### Flow

```text
 NL request (Claude → audiobook MCP)        Web UI (/audiobooks-dl)
         │                                          │
   search_abb / search_usenet              search + "send"
         │                                          │
   add_abb → Transmission                  add → Transmission
   grab_usenet → SABnzbd
         └──────────────┬───────────────────────────┘
                        ▼ completed downloads
        audiobook-import (every 5 min, qwen2.5 + m4b-tool)
                        ▼
   /mnt/media/Media/Audiobooks/<Author>/[<Series>/][<n> - ]<Title>/  + metadata.json
                        ▼
              Audiobookshelf auto-scan
```

## How to use

### 1. Web UI (manual ABB browsing)

Open **`https://p510.tail833f7.ts.net/audiobooks-dl`** (tailnet) or
`http://p510:5078` (LAN). Search a title, click **Send** on a result — the
magnet is queued in Transmission and saved under
`/mnt/media/downloads/torrents/audiobooks/<Title>/`. The import timer files it
into Audiobookshelf within ~5 minutes.

### 2. Natural language via Claude (the `audiobook` MCP)

The MCP endpoint `http://p510:3012/sse` is registered as the `audiobook` MCP
server (see `home/development/claude-code-mcp.nix`). Ask Claude things like:

- *"Use the audiobook tools to search AudioBookBay for Project Hail Mary."*
- *"Search Usenet for the Stormlight Archive and grab the first M4B result."*
- *"Is Dune already in my Audiobookshelf library?"*

Tools exposed: `search_abb`, `add_abb`, `search_usenet`, `grab_usenet`,
`search_library`, `recent_library_items`. The agent searches, you pick, it
grabs; the import pipeline finishes the job.

### 3. Fully automatic import

Nothing to do — `audiobook-import.timer` runs every 5 minutes, parses each new
completed folder with qwen2.5, optionally merges to M4B, and places it in the
library. Sources are hardlinked (torrent seeding continues) and marked with a
`.imported` file so they are processed once.

```bash
# inspect / force a run
systemctl status audiobook-import.timer
sudo systemctl start audiobook-import.service
journalctl -u audiobook-import.service -f
```

## Configuration knobs

```nix
# hosts/p510/configuration.nix
features.audiobookbay-automated = {
  enable = true;
  listenLanInterface = "eno1";
  abbHostname = "audiobookbay.lu";   # any compatible host
  savePathBase = "/mnt/media/downloads/torrents/audiobooks";
};

features.audiobook-import = {
  enable = true;
  model = "qwen2.5:7b";              # Ollama model for metadata
  mergeToM4b = true;                 # merge multi-file → chaptered M4B
  interval = "*:0/5";                # scan cadence
};

features.audiobook-mcp = {
  enable = true;
  listenLanInterface = "eno1";
};
```

## One-time setup / follow-ups

- **NZBGeek Usenet results:** in Prowlarr (`http://p510:9696`) ensure NZBGeek
  has the **Audiobook (3030)** category enabled and a SABnzbd download client
  configured. `grab_usenet` only handles `protocol: usenet` results.
- **Audiobookshelf library tools:** `search_library` / `recent_library_items`
  need an ABS API token. Mint one in Audiobookshelf, then:
  `agenix -e secrets/audiobook-mcp-env.age` and set `ABS_API_KEY=...`.
- Secrets live in `secrets/audiobook-mcp-env.age`
  (`PROWLARR_API_KEY`, `SABNZBD_API_KEY`, `ABS_API_KEY`).

## Troubleshooting

```bash
# services
systemctl status audiobookbay-automated audiobook-mcp audiobook-import.timer

# MCP endpoint up?
curl -i --max-time 4 http://p510:3012/sse        # expect 200 (SSE stream)

# Ollama model present?
ollama list | grep qwen2.5

# import not picking a folder up?
#  - folder mtime must be older than stableSeconds (120s)
#  - remove the .imported marker to reprocess
journalctl -u audiobook-import.service -n 50
```
