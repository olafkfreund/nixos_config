{ config
, lib
, inputs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.claude-code-skills;
in
{
  options.programs.claude-code-skills = {
    enable = mkEnableOption ''
      Declarative Claude Code skill catalogue (borghei).

      Symlinks selected skill subdirectories from the
      `claude-skills-borghei` flake input into ~/.claude/skills/ so
      Claude Code picks them up on launch. The other ~18 imperatively
      installed skills under that directory (managed via the `skills`
      CLI) are untouched.
    '';
  };

  config = mkIf cfg.enable {
    # Vendor link to the borghei/Claude-Skills repo. Bump with:
    #   nix flake update claude-skills-borghei
    # then test-build and deploy.
    home.file.".claude/skills/claude-code-mastery".source =
      "${inputs.claude-skills-borghei}/engineering/claude-code-mastery";

    # Local gog skill — /gog playbook for Gmail/Tasks/Calendar/Chat/Meet/etc.
    # via the gogcli (`gog`) CLI. Sourced from this repo, not a flake input.
    home.file.".claude/skills/gog/SKILL.md".source = ./gog/SKILL.md;
    home.file.".claude/skills/gog/evals.json".source = ./gog/evals.json;
  };
}
