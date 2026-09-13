{ config
, lib
, pkgs
, inputs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.programs.claude-code-skills;

  # Upstream's own NotebookLM skill ships inside the package; see the
  # notebooklm block below. python3.sitePackages rather than a hard-coded
  # python3.14, so a default-Python bump does not silently break the links.
  nlmData = "${pkgs.customPkgs.notebooklm-mcp-cli}/${pkgs.python3.sitePackages}/notebooklm_tools/data";
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
    #
    # Installed for three agents, not just Claude Code (#1785). Codex and
    # Antigravity/Gemini both read ~/.codex/skills and ~/.gemini/skills, and
    # both directories are already populated — but only by nixarchy, which
    # symlinks its own skills in from its store tree. Nothing carried THIS
    # repo's skills across, so the gog playbook did not exist in either tool.
    #
    # Per-file rather than whole-directory on purpose: those two directories
    # hold nixarchy's symlinks, so owning the directory would fight it. One
    # home.file per path adds the gog subdirectory and leaves the siblings be.
    home.file.".claude/skills/gog/SKILL.md".source = ./gog/SKILL.md;
    home.file.".claude/skills/gog/evals.json".source = ./gog/evals.json;
    home.file.".codex/skills/gog/SKILL.md".source = ./gog/SKILL.md;
    home.file.".gemini/skills/gog/SKILL.md".source = ./gog/SKILL.md;

    # Local notebooklm skill — the playbook for notebooklm-mcp-cli (#1785).
    # Installed for the same three agents as gog.
    #
    # It deliberately does NOT copy the command surface: `nlm --ai` emits about
    # a thousand lines of AI-oriented docs from the installed binary, and
    # upstream ships every few days, so a transcription here would be wrong
    # within a week. The file carries what those docs cannot know instead --
    # that artifacts are a three-step async flow, that quota is a rolling
    # window worth checking before generating, that credentials are per-host,
    # and that a single error is not expired cookies.
    # Upstream's skill (`nlm skill install` just copies data/SKILL.md out, byte
    # for byte) is linked as a supporting reference INSIDE our skill, not
    # installed as a second one: as a separate `nlm-skill` it carried
    # near-identical triggers, so every NotebookLM request loaded two
    # overlapping playbooks. Supporting files are not skills and trigger
    # nothing; our SKILL.md points at them. Linked from the store path rather
    # than copied into this repo, so the ~1000-line reference follows the
    # nightly package bump instead of going stale.
    home.file.".claude/skills/notebooklm/SKILL.md".source = ./notebooklm/SKILL.md;
    home.file.".claude/skills/notebooklm/evals.json".source = ./notebooklm/evals.json;
    home.file.".claude/skills/notebooklm/reference.md".source = "${nlmData}/SKILL.md";
    home.file.".claude/skills/notebooklm/references".source = "${nlmData}/references";
    home.file.".codex/skills/notebooklm/SKILL.md".source = ./notebooklm/SKILL.md;
    home.file.".codex/skills/notebooklm/reference.md".source = "${nlmData}/SKILL.md";
    home.file.".codex/skills/notebooklm/references".source = "${nlmData}/references";
    home.file.".gemini/skills/notebooklm/SKILL.md".source = ./notebooklm/SKILL.md;
    home.file.".gemini/skills/notebooklm/reference.md".source = "${nlmData}/SKILL.md";
    home.file.".gemini/skills/notebooklm/references".source = "${nlmData}/references";

    # Local dns skill — /dns playbook for GoDaddy DNS management.
    # The companion shell CLI lives next to SKILL.md and self-decrypts
    # the GoDaddy API secret from agenix at invocation time.
    home.file.".claude/skills/dns/SKILL.md".source = ./dns/SKILL.md;
    home.file.".claude/skills/dns/scripts/dns.sh" = {
      source = ./dns/scripts/dns.sh;
      executable = true;
    };

    # Local obsidian skill — playbook for the three vaults under ~/Documents.
    # Deliberately steers most work to the plain file tools (a vault is just
    # Markdown) and reserves notesmd-cli for renames, which must rewrite links
    # across ~2950 notes. The conventions it documents were measured from the
    # vaults, not assumed — notably that links here are 6:1 Markdown-style
    # over [[wikilinks]] and that frontmatter is rare.
    home.file.".claude/skills/obsidian/SKILL.md".source = ./obsidian/SKILL.md;

    # Local agent-bus skill — the shared Matrix room on p510 where agents
    # leave each other notes, reached as MCP tools rather than by driving a
    # terminal. Lives here rather than in nixarchy on purpose: the MCP
    # endpoint is tailnet-only, so shipping it to every nixarchy machine
    # would put authoritative-looking instructions on machines that cannot
    # reach it -- which is exactly why the SSH board's skill was pulled.
    home.file.".claude/skills/agent-bus/SKILL.md".source = ./agent-bus/SKILL.md;

    # Local 1password skill — `op` CLI playbook. Pure prose, no companion
    # script: every useful invocation needs an unlocked desktop-app session,
    # so there is nothing to automate around.
    home.file.".claude/skills/1password/SKILL.md".source = ./1password/SKILL.md;
  };
}
