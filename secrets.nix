# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeccj+vW/qyKepgXK0oXZfVFMf1kwmqj4uBHmjU2fz8 olafkfreund";

  # Host public keys - extract with: ssh-keyscan <hostname>
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2qbg0iSYU7x4k0tJcGdy7Nu8mSWqU0dg7WBv0lH7Zk";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaUdl4g8muVf0AUZDq9toM+I7q9Y8dYoPJMZDocfZLd root@nixos";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeaICX13Cw/ErM1Wag3P2letYRGXf3zIiuzPBQMlPAL root@nixos";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 ];
  workstations = [ p620 razer ];
in
{
  # User passwords
  "secrets/user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;

  # API Keys - Available on all hosts for development/AI tools
  "secrets/api-openai.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-gemini.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-anthropic.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-groq.age".publicKeys = allUsers ++ allHosts;
  # Ollama cloud-models API key (Ollama Turbo / hosted models). Exposed to the
  # ollama systemd daemon on hosts that opt in via
  # `features.ollama-server.cloudApiKeyFile`, and to interactive shells as
  # OLLAMA_API_KEY via load-api-keys. Edit: agenix -e secrets/api-ollama.age
  "secrets/api-ollama.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-github-token.age".publicKeys = allUsers ++ allHosts;
  # n8n personal API key (JWT) for the self-hosted instance at
  # https://n8n.freundcloud.org.uk. Exported as N8N_API_KEY system-wide via
  # load-api-keys; used by scripts/MCP servers/CLI tools that drive n8n.
  "secrets/api-n8n.age".publicKeys = allUsers ++ allHosts;
  # n8n MCP-server Bearer token (distinct from the personal REST API JWT).
  # Issued via n8n's MCP Server settings UI; auths the streamable-http endpoint
  # at https://n8n.freundcloud.org.uk/mcp-server/http. Exposed to Claude Code as
  # N8N_MCP_TOKEN by the MCP client wrapper, never as a system-wide env var.
  "secrets/api-n8n-mcp.age".publicKeys = allUsers ++ allHosts;
  # Synechron GitHub API token (PAT). All hosts; exported as
  # SYNECHRON_GITHUB_API_TOKEN via load-api-keys. Edit: agenix -e secrets/synechron-github-api.age
  "secrets/synechron-github-api.age".publicKeys = allUsers ++ allHosts;
  # gogcli refresh-token export (gog auth tokens export). Decrypted to
  # /run/agenix/gogcli-token, imported into gog's file keyring on every host.
  "secrets/gogcli-token.age".publicKeys = allUsers ++ allHosts;
  "secrets/obsidian-api-key.age".publicKeys = allUsers ++ workstations;
  "secrets/api-linkedin-cookie.age".publicKeys = allUsers ++ workstations;

  # Atlassian MCP secrets (cloud mode - API tokens)
  "secrets/api-jira-token.age".publicKeys = allUsers ++ workstations;
  "secrets/api-confluence-token.age".publicKeys = allUsers ++ workstations;

  # Atlassian MCP secrets (self-hosted mode - Personal Access Tokens)
  "secrets/api-jira-pat.age".publicKeys = allUsers ++ workstations;
  "secrets/api-confluence-pat.age".publicKeys = allUsers ++ workstations;

  # System secrets
  "secrets/wifi-password.age".publicKeys = allUsers ++ workstations;
  "secrets/tailscale-auth-key.age".publicKeys = allUsers ++ allHosts;

  # GNOME Remote Desktop RDP password. Plaintext, applied to grdctl at
  # user login via the systemd-user oneshot in
  # modules/desktop/gnome-remote-desktop.nix. Single shared password
  # across hosts — each host has its own libsecret keyring entry, but
  # the source-of-truth here means we don't hand-type per host.
  "secrets/grd-rdp-password.age".publicKeys = allUsers ++ allHosts;

  # LiteLLM router master key (p620 only — self-hosted Anthropic-compat
  # proxy for Ollama coding models). Plaintext rotation: see docs/plans/2026-05-22-ollama-p620-litellm-design.md §5.
  "secrets/litellm-master-key.age".publicKeys = allUsers ++ [ p620 ];

  # Per-host virtual bearer keys for the LiteLLM router. Same plaintext as
  # the master, encrypted to each client host so the apiKeyHelper script
  # on that host can read it. (Phase 3 of the Ollama+LiteLLM design.)
  "secrets/api-router-p620.age".publicKeys = allUsers ++ [ p620 ];
  "secrets/api-router-razer.age".publicKeys = allUsers ++ [ razer ];

  # HuggingFace read token for the meeting-transcribe pipeline (p620 only —
  # only the processor needs it; whisperX uses it to download the
  # pyannote/speaker-diarization-3.1 weights on first run). Setup:
  #   1. Create account at https://huggingface.co/join
  #   2. Accept terms at https://huggingface.co/pyannote/speaker-diarization-3.1
  #      AND https://huggingface.co/pyannote/segmentation-3.0
  #   3. Generate read token at https://huggingface.co/settings/tokens
  #   4. ./scripts/manage-secrets.sh create api-huggingface  (paste token)
  "secrets/api-huggingface.age".publicKeys = allUsers ++ [ p620 ];

  # Plex auth token for the Plex MCP server (features.plex-mcp on p510).
  # Contains ONLY the X-Plex-Token value. Set the real token with:
  #   agenix -e secrets/plex-token.age
  "secrets/plex-token.age".publicKeys = allUsers ++ [ p510 ];

  # Backstage developer portal (features.backstage on p510 — epic #731).
  # Each file holds a single value, no leading/trailing whitespace.
  # Rotation procedure: docs/backstage.md "Secret rotation" section.
  "secrets/backstage-postgres-password.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-github-token.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-github-oauth-client-id.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-github-oauth-client-secret.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-gitlab-token.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-mcp-token.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/backstage-github-webhook-secret.age".publicKeys = allUsers ++ [ p510 ];

  # SABnzbd confidential settings (ConfigObj INI) merged via
  # services.sabnzbd.secretFiles on p510 — holds the Easynews news-server
  # username/password. Edit with: agenix -e secrets/sabnzbd-secrets.age
  "secrets/sabnzbd-secrets.age".publicKeys = allUsers ++ [ p510 ];

  # arr-suite-mcp environment file (EnvironmentFile) on p510 — *arr API keys
  # (SONARR/RADARR/PROWLARR/OVERSEERR_API_KEY) for the MCP daemon. Refresh with:
  #   agenix -e secrets/arr-suite-mcp-env.age
  "secrets/arr-suite-mcp-env.age".publicKeys = allUsers ++ [ p510 ];

  # audiobook-mcp environment file (EnvironmentFile) on p510 — backend API
  # keys for the audiobook MCP server: PROWLARR_API_KEY, SABNZBD_API_KEY and
  # (optional) ABS_API_KEY for Audiobookshelf library lookups. Edit with:
  #   agenix -e secrets/audiobook-mcp-env.age
  "secrets/audiobook-mcp-env.age".publicKeys = allUsers ++ [ p510 ];

  # media-bot environment file (EnvironmentFile) on p510 — household
  # Telegram bot. Contains: TELEGRAM_BOT_TOKEN, OLLAMA_BASE_URL,
  # OLLAMA_MODEL, plus *arr API keys and PLEX_TOKEN (duplicated from
  # arr-suite-mcp-env + plex-token for single-EnvironmentFile simplicity;
  # rotate in both places). Edit with:
  #   agenix -e secrets/media-bot-env.age
  "secrets/media-bot-env.age".publicKeys = allUsers ++ [ p510 ];

  # media-bot user whitelist (YAML) on p510 — maps Telegram user IDs to
  # display names and Plex usernames. Reloadable at runtime via
  # `systemctl reload media-bot` (SIGHUP). Edit with:
  #   agenix -e secrets/media-bot-users.age
  "secrets/media-bot-users.age".publicKeys = allUsers ++ [ p510 ];

  # Kometa (Plex Meta Manager) environment file (EnvironmentFile) for the
  # oci-containers.containers.kometa unit on p510. Contains
  # TMDB_API_KEY + PLEX_TOKEN (latter duplicated from plex-token.age for
  # single-EnvironmentFile simplicity; rotate in both places). Edit with:
  #   agenix -e secrets/kometa-env.age
  # Once you've filled in the real TMDB key:
  #   sudo systemctl restart podman-kometa.service
  "secrets/kometa-env.age".publicKeys = allUsers ++ [ p510 ];

  # Plex-Auto-Languages container env file. PLEX_URL + PLEX_TOKEN (token
  # duplicated from plex-token.age). Edit with:
  #   agenix -e secrets/plex-auto-languages-env.age
  "secrets/plex-auto-languages-env.age".publicKeys = allUsers ++ [ p510 ];

  # GoDaddy account login (sign-in name, password, customer-service PIN,
  # service email). Plain account credentials — NOT an API key. Stored here
  # for safekeeping / disaster recovery. To enable scripted DNS management
  # you separately need an API key+secret from https://developer.godaddy.com/keys
  # (gated behind the paid tier as of 2024). Edit with:
  #   ./scripts/manage-secrets.sh edit godaddy-account
  "secrets/godaddy-account.age".publicKeys = allUsers ++ [ p620 ];

  # GoDaddy Production API key + secret (developer.godaddy.com/keys).
  # Format: 4 lines — "Key" / <key> / "Secret" / <secret>. Used for scripted
  # DNS management (Terraform n3integration/godaddy provider, ad-hoc curl).
  # Endpoint: https://api.godaddy.com/  (NOT api.ote-godaddy.com — that's the
  # test sandbox). Edit with:
  #   ./scripts/manage-secrets.sh edit api-godaddy
  "secrets/api-godaddy.age".publicKeys = allUsers ++ [ p620 ];

  # Tailscale Kubernetes Operator OAuth client credentials. JSON blob:
  #   {"client_id":"…","client_secret":"…"}
  # Create the OAuth client at https://login.tailscale.com/admin/settings/oauth
  # with scopes: Devices Core, Auth Keys, Services (write); tag tag:k8s-operator.
  # Then: ./scripts/manage-secrets.sh create tailscale-k8s-operator-oauth
  # Consumed by modules/containers/k3d.nix on p510; the k3d bootstrap unit
  # turns it into the tailscale/operator-oauth Secret the Tailscale operator
  # Helm chart expects (keys: client_id, client_secret).
  "secrets/tailscale-k8s-operator-oauth.age".publicKeys = allUsers ++ [ p510 ];

  # NZBGet ControlPassword. Loaded into a MainConfigInclude file at
  # service preStart so the value never appears in the systemd unit's
  # ExecStart (where the previous plaintext was visible via /proc).
  # Sonarr/Radarr/audiobook-import-import are configured against the
  # current value — DO NOT rotate without updating those callers too.
  # Edit with: agenix -e secrets/nzbget-password.age
  "secrets/nzbget-password.age".publicKeys = allUsers ++ [ p510 ];

  # n8n encryption key (p510 only). Encrypts n8n's own credential store so the
  # Overseerr/Tautulli/Home-Assistant API keys entered in the n8n UI survive
  # rebuilds and never land in the Nix store. Random value, not hand-typed.
  # See docs/plans/2026-05-26-plex-llm-recommendations-design.md.
  "secrets/n8n-encryption-key.age".publicKeys = allUsers ++ [ p510 ];

  # Cloudflare Tunnel credentials for p510 — public ingress under
  # freundcloud.org.uk (Cloudflare-managed zone), behind Starlink CGNAT.
  # One-time bootstrap procedure documented in
  # modules/services/cloudflared.nix header. Both files are produced by the
  # cloudflared CLI:
  #   cert.pem       — from `cloudflared login` (zone-scoped Cloudflare API token)
  #   credentials.json — from `cloudflared tunnel create p510-home` (tunnel-specific)
  # Edit with:
  #   ./scripts/manage-secrets.sh edit cloudflared-cert
  #   ./scripts/manage-secrets.sh edit cloudflared-credentials
  "secrets/cloudflared-cert.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/cloudflared-credentials.age".publicKeys = allUsers ++ [ p510 ];

  # ── Factory k8s namespace bootstrap secrets (#807) ───────────────────────
  # Each .age file holds a complete kubectl-applicable Secret manifest. The
  # k3d-cluster-bootstrap unit on p510 reads these via age and
  # `kubectl apply -f` each one, so a cluster delete + recreate restores
  # SkillAI / rolehunter / shared factory-secrets durably (no out-of-band
  # `kubectl create secret` step required).
  #
  # Edit any of these by hand if you need to rotate a value:
  #   ./scripts/manage-secrets.sh edit factory-secret-<name>
  # The value MUST remain a valid k8s Secret YAML (metadata.namespace must
  # be `factory`, .data values must be base64). On next k3d-cluster-bootstrap
  # restart, kubectl apply picks up the change idempotently.
  "secrets/factory-secret-cloudflared-factory.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-factory-secrets.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-factory-cli-creds.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-ghcr-pull.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-skillai-db.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-skillai-app.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-rolehunter-db.age".publicKeys = allUsers ++ [ p510 ];
  "secrets/factory-secret-rolehunter-app.age".publicKeys = allUsers ++ [ p510 ];
}
