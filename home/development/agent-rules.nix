# Global instructions for Codex and Antigravity, generated from the files
# Claude already reads, so every agent follows the same rules and process
# (#1832). Codex reads ~/.codex/AGENTS.md; Antigravity reads ~/.gemini/AGENTS.md.
#
# Policy and templates are inlined so they do not depend on skill selection.
{ config, lib, pkgs, ... }:
let
  # Hosts that import hosts/common/nixos/llm-index.nix (p620, razer): tool instructions (#2882); empty elsewhere.
  llmIndex = lib.optional (lib.attrByPath [ "services" "llm-index" "enable" ] false config)
    config.services.llm-index.agentInstructions;

  team = import ../../modules/programs/agent-team.nix;

  # Everything from the Claude Code mechanics heading on is Claude's alone; the
  # Team policy above it is shared, with the role table filled in (#3264).
  policyParts = lib.splitString "\n## Claude Code mechanics (Claude Code only)"
    (builtins.readFile ../../modules/programs/claude-code-managed-claude.md);
  managedPolicy =
    assert lib.assertMsg (lib.length policyParts == 2)
      "agent-rules: expected exactly one Claude Code mechanics heading in claude-code-managed-claude.md; update the marker in agent-rules.nix";
    builtins.replaceStrings [ "@team_table@" ] [ team.table ] (lib.head policyParts);

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
    assert lib.assertMsg (!lib.hasInfix "Claude Code mechanics" text)
      "agent-rules: the Claude-only mechanics section leaked into the Codex/Antigravity rules";
    assert lib.assertMsg (!lib.hasInfix "@team_table@" text)
      "agent-rules: the @team_table@ placeholder was not replaced";
    assert lib.assertMsg (lib.hasInfix "## Team policy" text)
      "agent-rules: the Team policy section is missing";
    assert lib.assertMsg (lib.stringLength text < 32768)
      "agent-rules: AGENTS.md is over Codex's 32 KiB cap";
    pkgs.writeText "global-agents.md" text;
in
{
  home.file.".codex/AGENTS.md".source = agentsMd ([
    (builtins.readFile ./agent-rules/codex-standards.md)
    "## PARR protocol\n"
    (builtins.readFile ../../modules/programs/parr-protocol.txt)
  ] ++ llmIndex);
  home.file.".gemini/AGENTS.md".source = agentsMd ([
    (builtins.readFile ./agent-rules/agy-standards.md)
    "## PARR protocol\n"
    (builtins.readFile ../../modules/programs/parr-protocol.txt)
  ] ++ llmIndex);
}
