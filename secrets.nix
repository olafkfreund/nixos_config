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

  # Key groups
  allUsers = [olafkfreund];
  allHosts = [p620 razer p510 dex5550];
  workstations = [p620 razer];
  servers = [p510 dex5550];
in {
  "secrets/user-password-olafkfreund.age".publicKeys = allUsers ++ allHosts;
  "secrets/github-token.age".publicKeys = allUsers ++ workstations;
  "secrets/ssh-host-ed25519-key.age".publicKeys = allUsers ++ allHosts;
  "secrets/wifi-password.age".publicKeys = allUsers ++ [razer];
  "secrets/docker-auth.age".publicKeys = allUsers ++ allHosts;
  "secrets/postgres-password.age".publicKeys = allUsers ++ servers;
  "secrets/nextcloud-admin-password.age".publicKeys = allUsers ++ servers;
  "secrets/smtp-password.age".publicKeys = allUsers ++ allHosts;
}
