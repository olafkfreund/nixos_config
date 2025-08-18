let
  # P620 host key only
  p620 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2qbg0iSYU7x4k0tJcGdy7Nu8mSWqU0dg7WBv0lH7Zk";
in
{
  # Use only host key for secrets
  "secrets/api-openai.age".publicKeys = [ p620 ];
  "secrets/api-anthropic.age".publicKeys = [ p620 ];
  "secrets/api-gemini.age".publicKeys = [ p620 ];
  "secrets/api-github-token.age".publicKeys = [ p620 ];
  "secrets/tailscale-auth-key.age".publicKeys = [ p620 ];
  "secrets/user-password-olafkfreund.age".publicKeys = [ p620 ];
  "secrets/wifi-password.age".publicKeys = [ p620 ];
}
