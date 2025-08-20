# This file defines which keys can decrypt which secrets
# Run: agenix -e <secret-name>.age
let
  # User public keys
  olafkfreund = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeccj+vW/qyKepgXK0oXZfVFMf1kwmqj4uBHmjU2fz8 olafkfreund";

  # Host public keys - extract with: ssh-keyscan <hostname>
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2qbg0iSYU7x4k0tJcGdy7Nu8mSWqU0dg7WBv0lH7Zk";
  razer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaUdl4g8muVf0AUZDq9toM+I7q9Y8dYoPJMZDocfZLd root@nixos";
  p510 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeaICX13Cw/ErM1Wag3P2letYRGXf3zIiuzPBQMlPAL root@nixos";
  dex5550 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFxuY6knpMg87Gh0F8aqaG6Mi/8qm423pc618lDm9FtL root@nixos";
  samsung = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL3Hd1qnxQuXyH3VaVgpRttaTUcr3vl1vo69ZsI/AExN";

  # Key groups
  allUsers = [ olafkfreund ];
  allHosts = [ p620 razer p510 dex5550 samsung ];
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
  "secrets/wifi-password.age".publicKeys = allUsers ++ workstations;
  "secrets/tailscale-auth-key.age".publicKeys = allUsers ++ allHosts;
}
