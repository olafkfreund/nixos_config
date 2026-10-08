// Visibility only: deploy, p510 and bus rules stay with the managed settings hooks
// in modules/programs/claude-code-managed.nix, which run before any mod.
export type Verdict = { kind: 'pass' } | { kind: 'deny'; reason: string }

export function classify(cmd: string): Verdict {
  if (/git\s+commit\b[^|;]*\s-m\s*"[^"]*(`|\$\()/.test(cmd))
    return {
      kind: 'deny',
      reason: "backticks or $( inside a double-quoted commit message run as commands; use git commit -F - <<'MSG'",
    }
  if (/(^|[\s;&|])home-manager\s+switch/.test(cmd))
    return { kind: 'deny', reason: 'Home Manager is a flake module here; never run home-manager switch' }
  return { kind: 'pass' }
}
