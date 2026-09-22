{ config
, lib
, pkgs
, inputs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.claude-code-skills;

  # Upstream's own NotebookLM skill ships inside the package. python3.sitePackages
  # rather than a hard-coded python3.14, so a default-Python bump does not
  # silently break the links.
  nlmData = "${pkgs.customPkgs.notebooklm-mcp-cli}/${pkgs.python3.sitePackages}/notebooklm_tools/data";

  # Our notebooklm playbook plus upstream's skill as a supporting reference, not
  # a second skill: as a separate `nlm-skill` its near-identical triggers loaded
  # two overlapping playbooks per request. Linked from the store rather than
  # copied into this repo, so the ~1000-line reference follows the nightly bump.
  notebooklmTree = pkgs.runCommand "skill-notebooklm" { } ''
    cp -r ${./notebooklm} $out
    chmod u+w $out
    ln -s ${nlmData}/SKILL.md $out/reference.md
    ln -s ${nlmData}/references $out/references
  '';

  # Where each agent reads skills; the only place these paths are written.
  # Codex 0.155 and Antigravity 1.2 both read ~/.agents/skills. Nothing
  # installed reads ~/.gemini/skills or Pi's directory -- add a row when one does.
  agentDirs = {
    claude = ".claude/skills";
    agents = ".agents/skills"; # Codex and Antigravity
    codex = ".codex/skills"; # Codex only
  };

  # Every skill written in this repo, and the agents it goes to.
  everyAgent = [ "claude" "agents" ];
  localSkills = {
    gog = { src = ./gog; to = everyAgent; };
    notebooklm = { src = notebooklmTree; to = everyAgent; };
    artifact-workflow = { src = ./artifact-workflow; to = everyAgent; }; # #1832
    dns = { src = ./dns; to = everyAgent; };
    obsidian = { src = ./obsidian; to = everyAgent; };
    "1password" = { src = ./1password; to = everyAgent; };
    nixos-standards = { src = ./nixos-standards; to = everyAgent; };
    fides = { src = ./fides; to = everyAgent; };
    backstage-patterns = { src = ./backstage-patterns; to = everyAgent; };
    linkedin-post = { src = ./linkedin-post; to = everyAgent; };
    reddit-post = { src = ./reddit-post; to = everyAgent; };
    cosmic-ui-design-skill = { src = ./cosmic-ui-design-skill; to = everyAgent; };
    # Its MCP server is configured for Claude and Codex, not Antigravity.
    agent-bus = { src = ./agent-bus; to = [ "claude" "codex" ]; };
    # Claude only: for codex/agy it would let reviewers delegate to each other (#1831).
    second-opinion = { src = ./second-opinion; to = [ "claude" ]; };
    # Claude only: the cloud model drafts; it does not review or commit (#1928, #1929).
    ask-ollama-cloud = { src = ./ask-ollama-cloud; to = [ "claude" ]; };
  };
  # Not here on purpose: parr-run and run-aws-demo describe private
  # infrastructure (this repo is public), and the `skills` CLI owns its own.
in
{
  imports = [ inputs.nix-skills.homeManagerModules.default ];

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
    # Our nix-skills collection (#1958), for three agents at once. Left out:
    # devenv-project overlaps nixarchy's machine-specific `devenv` skill, and
    # nixos-wiki is a snapshot of what the mcp-nixos server searches live.
    # Gemini CLI's ~/.gemini/skills has no agent entry in nix-skills;
    # Antigravity's ~/.gemini/config/skills does.
    programs.nix-skills = {
      enable = true;
      agents = [ "claude" "codex" "antigravity" ];
      skills = [ "nix-language" "nixpkgs-development" "microvm-nix" "home-manager" ];
    };

    home.file = lib.mkMerge ([
      # Vendor link to the borghei/Claude-Skills repo. Bump with:
      #   nix flake update claude-skills-borghei
      # then test-build and deploy.
      {
        ".claude/skills/claude-code-mastery".source =
          "${inputs.claude-skills-borghei}/engineering/claude-code-mastery";
      }
    ] ++ lib.mapAttrsToList
      (name: skill: lib.genAttrs' skill.to (agent:
        lib.nameValuePair "${agentDirs.${agent}}/${name}" {
          source = skill.src;
          # Per-file links inside a real directory: the directories also hold
          # nixarchy's and nix-skills' links, so owning them would fight both.
          recursive = true;
          # Replaces the regular files these skills were before they moved here.
          force = true;
        }))
      localSkills);
  };
}
