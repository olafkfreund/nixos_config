# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeccj+vW/qyKepgXK0oXZfVFMf1kwmqj4uBHmjU2fz8 olafkfreund"; # Replace with your actual public key

  # Host public keys - extract with: ssh-keyscan <hostname>
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+0dkuZaRIzLUtOHYeMyA3LFfjvwmr6bbC9VD6pxSg0 root@nixos";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaUdl4g8muVf0AUZDq9toM+I7q9Y8dYoPJMZDocfZLd root@nixos";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeaICX13Cw/ErM1Wag3P2letYRGXf3zIiuzPBQMlPAL root@nixos";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxuY6knpMg87Gh0F8aqaG6Mi/8qm423pc618lDm9FtL root@nixos";
  samsung = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGBgArYvKdbVDU+10o0mP1psxrUuFVUdnkZFK4KOPz+t root@samsung";
  samsung-rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCkrKMqnJ4f21gARUub1Qp2LpDHY3zhrOIj9vQFZomcvWon73QFggbU3TEczKMV8iso0vDY3EGPdyHolv1WnPhf//vZLvG8WR/haeJ2EpuQAq723/owptKbtxY76ltj2E7n+tRTikvEI5rizuaBtjqZSV8DwiY9yLK/FXgqgvU6Waq9slpuYT5PELW8U3JXAkH0YyaqMGpGW4bE6V/nXZYZLijBp+nxIHlX5qCv85V9cacAFltY/TPLVyHVBz4izSLG0TN3h4ioQz51yOLapA3lhFmQWTDnUAK5VFLNWjqdT69UbCHjjPHAW5Fx8+eLn2SloZlEQFpQ3iKBrwhsssNqoSkhC6HnnXkQsS7UPeYF1W3FwncQpd3GSwlgR4s8WEsaLhErk4Z7CjPL0LP1FYOMAo1KANnTzr28RJYGkVSFyLLYJkU/n+vF+F+ZBiOLaSp+wUKDhbTESOdahkEQO7P0qFTD8ze+cp1DqXvI7avLutdF/pApRoHyzJl0hvNpzWnXkbWvqJAUlp/+zqgUt5xx+OSXJkMVf/XxzGPXTT/NL9fAw9MiVfTjJp3BXKl+exWqCI7z7BLzqZXvsejxoDVSXvoyTk6cxUGQAwfQJTNQoa+d2GgJnYP07jlN46ulkq18oVoOAfZTydrB+OhZIK0uxgVq5fm20NM71P5E2M8kYw== root@nixos";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 dex5550 samsung samsung-rsa ];
  workstations = [ p620 razer ];
  servers = [ p510 dex5550 ];
in
{
  # User passwords
  "secrets/user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;

  # API Keys - Available on all hosts for development/AI tools
  "secrets/api-openai.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-gemini.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-anthropic.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-qwen.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-langchain.age".publicKeys = allUsers ++ allHosts;
  "secrets/api-github-token.age".publicKeys = allUsers ++ allHosts;

  # System secrets
  "secrets/github-token.age".publicKeys = allUsers ++ workstations;
  "secrets/ssh-host-ed25519-key.age".publicKeys = allUsers ++ allHosts;
  "secrets/wifi-password.age".publicKeys = allUsers ++ [ razer ];
  "secrets/docker-auth.age".publicKeys = allUsers ++ allHosts;
  "secrets/postgres-password.age".publicKeys = allUsers ++ servers;
  "secrets/nextcloud-admin-password.age".publicKeys = allUsers ++ servers;
  "secrets/smtp-password.age".publicKeys = allUsers ++ allHosts;

  # Gmail OAuth2 secrets for email integration
  "secrets/gmail-oauth2-client-secret.age".publicKeys = allUsers ++ allHosts;
  "secrets/gmail-oauth2-refresh-token-primary.age".publicKeys = allUsers ++ allHosts;
  "secrets/gmail-oauth2-refresh-token-secondary.age".publicKeys = allUsers ++ allHosts;

  # Tailscale secrets
  "secrets/tailscale-auth-key.age".publicKeys = allUsers ++ allHosts;
}
