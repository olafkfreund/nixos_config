// Visibility only: deploy, p510 and bus rules stay with the managed settings hooks
// in modules/programs/claude-code-managed.nix, which run before any mod.
export type Verdict = { kind: 'pass' } | { kind: 'deny'; reason: string }

// The double-quoted message of `git commit -m/-am/--message`.
const COMMIT_MSG = /git\s+(?:-C\s+\S+\s+)?commit\b[^|;]*?(?:\s-[a-z]*m|\s--message[=\s])\s*"([^"]*)/
// home-manager in command position (after a separator, not inside prose).
const HM_SWITCH = /(?:^|[;&|(\n])\s*(?:sudo\s+)?home-manager\b[^;&|\n]*\sswitch\b/

// `gh run watch` / `gh pr checks --watch` in command position, and their arguments.
const GH_WATCH = /(?:^|[;&|(\n])\s*gh\s+(run\s+watch|pr\s+checks)\b([^;&|\n]*)/g
// The account has 5,000 requests an hour, shared by every session and tool on
// it; the defaults poll every 3 s (run watch) and 10 s (pr checks), and ran it
// dry three days running (nixarchy#1948).
const MIN_INTERVAL = 30

function unthrottledWatch(cmd: string): boolean {
  for (const [, sub, args = ''] of cmd.matchAll(GH_WATCH)) {
    if (sub.startsWith('pr') && !/(?:^|\s)--watch\b/.test(args)) continue
    const i = /(?:^|\s)(?:--interval[=\s]|-i\s*)(\d+)/.exec(args)
    if (!i || Number(i[1]) < MIN_INTERVAL) return true
  }
  return false
}

export function classify(cmd: string): Verdict {
  const msg = COMMIT_MSG.exec(cmd)?.[1]
  // A quoted heredoc ($(cat <<'EOF' ...)) expands nothing, so it is safe.
  if (msg !== undefined && !/^\$\(cat\s+<<-?\s*'/.test(msg) && /`|\$\(/.test(msg))
    return {
      kind: 'deny',
      reason: "backticks or $( inside a double-quoted commit message run as commands; use git commit -F - <<'MSG'",
    }
  if (HM_SWITCH.test(cmd))
    return { kind: 'deny', reason: 'Home Manager is a flake module here; never run home-manager switch' }
  if (unthrottledWatch(cmd))
    return {
      kind: 'deny',
      reason: `gh run watch / gh pr checks --watch poll every few seconds and drain the account's API limit; pass --interval ${MIN_INTERVAL} or more (e.g. --interval 60)`,
    }
  return { kind: 'pass' }
}
