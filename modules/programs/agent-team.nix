# One role map for Claude Code, Codex and agy (#3263).
{
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
  limits = { subagents = 4; depth = 1; };
}
