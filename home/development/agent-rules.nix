# Global instructions for Codex and Antigravity, generated from the files
# Claude already reads, so every agent follows the same rules and process
# (#1832). Codex reads ~/.codex/AGENTS.md; Antigravity reads ~/.gemini/AGENTS.md.
#
# Policy and templates are inlined so they do not depend on skill selection.
{ lib, pkgs, ... }:
let
  managedPolicy = builtins.readFile ../../modules/programs/claude-code-managed-claude.md;

  # Drop the YAML frontmatter; everything after the closing `---` is the body.
  skill = builtins.readFile ./claude-code-skills/artifact-workflow/SKILL.md;
  skillBody = lib.concatStringsSep "\n---\n" (lib.drop 1 (lib.splitString "\n---\n" skill));

  workflow = [
    (lib.replaceStrings
      [ "The procedure and templates are in the `artifact-workflow` skill. Load it\nbefore writing any of these files." ]
      [ "The procedure and templates follow below." ]
      managedPolicy)
    skillBody
  ];

  agentsMd = protocol:
    let
      text = lib.concatStringsSep "\n" (
        [ (builtins.readFile ./agent-rules/global.md) ] ++ protocol ++ workflow
      );
    in
    assert lib.assertMsg (!lib.hasInfix "Load it" text)
      "agent-rules: the managed policy's skill sentence changed; update the replaceStrings in agent-rules.nix";
    assert lib.assertMsg (!lib.hasInfix "name: artifact-workflow" text)
      "agent-rules: SKILL.md frontmatter was not stripped";
    pkgs.writeText "global-agents.md" text;
in
{
  home.file.".codex/AGENTS.md".source = agentsMd [
    (builtins.readFile ./agent-rules/codex-standards.md)
  ];
  home.file.".gemini/AGENTS.md".source = agentsMd [
    "## PARR protocol\n"
    (builtins.readFile ../../modules/programs/parr-protocol.txt)
  ];
}
