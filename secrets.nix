# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeccj+vW/qyKepgXK0oXZfVFMf1kwmqj4uBHmjU2fz8 olafkfreund"; # Replace with your actual public key

  # Host public keys - extract with: ssh-keyscan <hostname>
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGmMyP9g9NugO44juiITFn4IcdMIWa0mATh3C7+L1mq+"; # Updated 2025-08-11
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaUdl4g8muVf0AUZDq9toM+I7q9Y8dYoPJMZDocfZLd root@nixos"; # Verify when online
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeaICX13Cw/ErM1Wag3P2letYRGXf3zIiuzPBQMlPAL root@nixos"; # Confirmed
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxuY6knpMg87Gh0F8aqaG6Mi/8qm423pc618lDm9FtL root@nixos"; # Confirmed
  samsung = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILIVKSO3cW6QumULIpscYrcvaqAXeIwgwkYBtNW8K1AY"; # Updated 2025-08-11 - correct key
  samsung-rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCkrKMqnJ4f21gARUub1Qp2LpDHY3zhrOIj9vQFZomcvWon73QFggbU3TEczKMV8iso0vDY3EGPdyHolv1WnPhf//vZLvG8WR/haeJ2EpuQAq723/owptKbtxY76ltj2E7n+tRTikvEI5rizuaBtjqZSV8DwiY9yLK/FXgqgvU6Waq9slpuYT5PELW8U3JXAkH0YyaqMGpGW4bE6V/nXZYZLijBp+nxIHlX5qCv85V9cacAFltY/TPLVyHVBz4izSLG0TN3h4ioQz51yOLapA3lhFmQWTDnUAK5VFLNWjqdT69UbCHjjPHAW5Fx8+eLn2SloZlEQFpQ3iKBrwhsssNqoSkhC6HnnXkQsS7UPeYF1W3FwncQpd3GSwlgR4s8WEsaLhErk4Z7CjPL0LP1FYOMAo1KANnTzr28RJYGkVSFyLLYJkU/n+vF+F+ZBiOLaSp+wUKDhbTESOdahkEQO7P0qFTD8ze+cp1DqXvI7avLutdF/pApRoHyzJl0hvNpzWnXkbWvqJAUlp/+zqgUt5xx+OSXJkMVf/XxzGPXTT/NL9fAw9MiVfTjJp3BXKl+exWqCI7z7BLzqZXvsejxoDVSXvoyTk6cxUGQAwfQJTNQoa+d2GgJnYP07jlN46ulkq18oVoOAfZTydrB+OhZIK0uxgVq5fm20NM71P5E2M8kYw== root@nixos";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 dex5550 samsung-rsa ]; # Samsung uses RSA key to avoid Ed25519 circular dependency
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
  "secrets/api-github-token.age".publicKeys = allUsers ++ allHosts;

  # System secrets
  "secrets/github-token.age".publicKeys = allUsers ++ workstations;
  "secrets/wifi-password.age".publicKeys = allUsers ++ [ razer ];
  "secrets/postgres-password.age".publicKeys = allUsers ++ servers;
  "secrets/nextcloud-admin-password.age".publicKeys = allUsers ++ servers;

  # Tailscale secrets
  "secrets/tailscale-auth-key.age".publicKeys = allUsers ++ allHosts;
}
