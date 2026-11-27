# One role map for Claude Code, Codex and agy (#3263).
let
  roles = {
    manager = {
      claude = { model = "opus"; effort = "high"; };
      codex = { model = "gpt-6.2-astra"; effort = "high"; };
      agy = { model = "gemini-4-neon"; effort = "high"; };
    };
    reviewer = {
      claude = { model = "opus"; effort = "medium"; };
      codex = { model = "gpt-6.2-astra"; effort = "medium"; };
      agy = { model = "gemini-4-neon"; effort = "medium"; };
    };
    worker = {
      claude = { model = "sonnet"; effort = "medium"; };
      codex = { model = "gpt-6.2-sol"; effort = "medium"; };
      agy = { model = "gemini-4-hydrogen"; effort = "medium"; };
    };
    explorer = {
      claude = { model = "haiku"; effort = "low"; };
      codex = { model = "gpt-6-luna"; effort = "low"; };
      agy = { model = "gemini-4-hydrogen"; effort = "low"; };
    };
  };
  # One row of the policy table (#3264).
  row = name:
    let r = roles.${name};
    in "| ${name} | `${r.claude.model}` (${r.claude.effort}) | `${r.codex.model}` (${r.codex.effort}) | `${r.agy.model}-${r.agy.effort}` |";
in
{
  inherit roles;
  limits = { subagents = 4; depth = 1; };
  table = ''
    | Role | Claude Code | Codex | agy |
    | ---- | ----------- | ----- | --- |
    ${row "manager"}
    ${row "reviewer"}
    ${row "worker"}
    ${row "explorer"}'';
}
