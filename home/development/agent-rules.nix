# Global instructions for Codex and Antigravity, generated from the files
# Claude already reads, so every agent follows the same rules and process
# (#1832). Codex reads ~/.codex/AGENTS.md; Antigravity reads ~/.gemini/AGENTS.md.
#
# Neither agent can load a skill or run a hook, so the workflow templates and
# the PARR text are inlined rather than referenced.
{ lib, pkgs, ... }:
let
  managedPolicy = builtins.readFile ../../modules/programs/claude-code-managed-claude.md;

  # Drop the YAML frontmatter; everything after the closing `---` is the body.
  skill = builtins.readFile ./claude-code-skills/artifact-workflow/SKILL.md;
  skillBody = lib.concatStringsSep "\n---\n" (lib.drop 1 (lib.splitString "\n---\n" skill));

  text = lib.concatStringsSep "\n" [
    (builtins.readFile ./agent-rules/global.md)
    "## PARR protocol\n"
    (builtins.readFile ../../modules/programs/parr-protocol.txt)
    (lib.replaceStrings
      [ "The procedure and templates are in the `artifact-workflow` skill. Load it\nbefore writing any of these files." ]
      [ "The procedure and templates follow below." ]
      managedPolicy)
    skillBody
  ];

  agentsMd =
    assert lib.assertMsg (!lib.hasInfix "Load it" text)
      "agent-rules: the managed policy's skill sentence changed; update the replaceStrings in agent-rules.nix";
    assert lib.assertMsg (!lib.hasInfix "name: artifact-workflow" text)
      "agent-rules: SKILL.md frontmatter was not stripped";
    pkgs.writeText "global-agents.md" text;
in
{
  home.file.".codex/AGENTS.md".source = agentsMd;
  home.file.".gemini/AGENTS.md".source = agentsMd;
}
