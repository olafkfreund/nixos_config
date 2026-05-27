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
  "secrets/api-github-token.age".publicKeys = allUsers ++ allHosts;
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

  # Plex auth token for the Plex MCP server (features.plex-mcp on p510).
  # Contains ONLY the X-Plex-Token value. Set the real token with:
  #   agenix -e secrets/plex-token.age
  "secrets/plex-token.age".publicKeys = allUsers ++ [ p510 ];

  # SABnzbd confidential settings (ConfigObj INI) merged via
  # services.sabnzbd.secretFiles on p510 — holds the Easynews news-server
  # username/password. Edit with: agenix -e secrets/sabnzbd-secrets.age
  "secrets/sabnzbd-secrets.age".publicKeys = allUsers ++ [ p510 ];

  # arr-suite-mcp environment file (EnvironmentFile) on p510 — *arr API keys
  # (SONARR/RADARR/PROWLARR/OVERSEERR_API_KEY) for the MCP daemon. Refresh with:
  #   agenix -e secrets/arr-suite-mcp-env.age
  "secrets/arr-suite-mcp-env.age".publicKeys = allUsers ++ [ p510 ];
}
