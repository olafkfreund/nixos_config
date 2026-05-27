# Secrets (agenix)

## The problem

Secrets — API keys, passwords, tokens — must live somewhere. Two tempting
approaches are both wrong:

- **Plaintext in git** leaks the moment the repo is shared.
- **`builtins.readFile` at evaluation** copies the secret into the
  world-readable `/nix/store`, which is arguably worse.

## The solution

This repo uses **agenix**: secrets are **age-encrypted** files that are safe to
commit, and they are decrypted to a runtime path **at activation**, never during
evaluation.

```nix
# WRONG — secret ends up in the Nix store
services.myservice.password = builtins.readFile "/secrets/pass";

# CORRECT — reference a runtime path produced by agenix
age.secrets."api-anthropic".file = ../secrets/api-anthropic.age;
services.myservice.passwordFile = config.age.secrets."api-anthropic".path;
```

## How access control works

`secrets/secrets.nix` maps each `.age` file to the public keys allowed to
decrypt it — per host and per user. Only a host that holds the matching private
key can read a secret destined for it.

```nix
# secrets/secrets.nix (shape)
{
  "api-anthropic.age".publicKeys = [ p620 razer olafkfreund ];
  "user-password-olafkfreund.age".publicKeys = [ p620 p510 razer ];
}
```

Encrypted `.age` files **are committed**; plaintext is **never** committed.

## Managing secrets

A helper script wraps the common operations:

```bash
./scripts/manage-secrets.sh status          # what exists, who can read it
./scripts/manage-secrets.sh create NAME      # create + encrypt a new secret
./scripts/manage-secrets.sh edit NAME        # decrypt, edit, re-encrypt
./scripts/manage-secrets.sh rekey            # re-encrypt all to current keys
```

After adding a host or rotating a key, run `rekey` so every secret is encrypted
to the new set of recipients.

## Where secrets are used

The most prominent consumers are the AI providers — `api-openai`,
`api-anthropic`, `api-gemini` are loaded at runtime and exposed under
`/run/agenix/`. User passwords follow the `user-password-<name>.age` convention.

## Why agenix here

- Secrets travel **with** the configuration (in git) without being exposed.
- Decryption is **bound to host keys**, so a leaked repo is not a leaked secret.
- It composes cleanly with NixOS `*File` options, keeping evaluation pure.
