{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.programs.claude-code-commands;

  # /team — run an approved plan/ as manager, dispatching steps per coders: (#2650).
  teamCommand = ''
    ---
    description: "Run an approved plan/ as manager: dispatch each step to coder, agy or codex as its coders: field says"
    argument-hint: <path to approved plan/>
    ---

    # Team manager mode

    Target plan: `$ARGUMENTS`

    Follow these steps in order. Do not start implementation before checking the gate, never spawn Opus teammates, and remember that Claude never approves the plan.

    1. **Verify the gate**: Refuse unless `$ARGUMENTS` is an existing `plan/` file with frontmatter `status: approved`. If `$ARGUMENTS` is empty, not under `plan/`, or still `status: draft`, stop and tell the user.
    2. **Read `coders:`**: Parse the plan's `coders:` frontmatter mapping and step list, and list the planned dispatch per step before executing.
    3. **Dispatch each step in plan order**:
       - `coder` → spawn one Sonnet `coder` agent for the task and send any later `coder` steps to that same agent via `SendMessage`.
       - `agy` or `codex` → run via the `handoff` skill (`agent-run`) in the background.
       - Unlisted steps → the model-split default: the `coder` for a plan with three or more editing steps or files, otherwise yourself. Never agy or Codex unless `coders:` names them; deleting an entry is the user's opt-out.
    4. **Verify and commit after each step**: Run the step's check, commit the verified change on the task branch, and note which worker completed the step (including any fallback if a handoff failed).
    5. **Parallel steps**: Run steps in parallel only when the plan explicitly marks them independent and their touched files are disjoint. Run each parallel `agy` or `codex` step in its own temporary worktree created with `git worktree add ../<repo>-<issue>-s<n> HEAD`, once its check passes, apply the diff back to the task worktree with `git -C <wt> add -A && git -C <wt> diff --cached --binary | git apply` (plain `git diff` drops new files), commit it before applying the next one (`agent-run` refuses a dirty worktree), and remove the temporary worktree with `git worktree remove --force <wt>`. On a failed apply, remove the temporary worktree and rerun that step sequentially in the task worktree.
    6. **Final reviews**: When all implementation steps are committed, run a fresh Opus review alongside every provider listed in the plan's `reviewers:` (via `second-opinion`, in parallel and read-only).
    7. **Report**: Summarize the outcome and report which worker did each step.
  '';

  agentTeamCommand = ''
    ---
    description: Turn the Codex/agy agent team on or off for this host (#2650)
    argument-hint: on | off | status
    allowed-tools: Bash(agent-team:*)
    ---
    !agent-team $ARGUMENTS
  '';
  # /crew — global slash command. Hands a task description to a fleet
  # LLM (default: p620's LiteLLM router, which proxies local Ollama
  # models), parses the model's `<file path="…">…</file>` tags into
  # actual files resolved against the user's current cwd, runs
  # `nix-instantiate --parse` for any .nix files it wrote, then prints
  # a git diff.
  #
  # Why LiteLLM and not bare Ollama? Bare ollama only binds to 127.0.0.1
  # on p620, so razer + p510 can't reach it. LiteLLM is already exposed
  # on tailscale0:4000 with per-host bearer-key auth (api-router-<host>
  # agenix secret), so the same /crew works on every host without any
  # network-exposure changes to the ollama daemon itself.
  #
  # The bundled run_crew.py reads four env knobs:
  #   CREW_ENDPOINT     — chat-completion URL (default p620's LiteLLM)
  #   CREW_MODEL        — model alias (default qwen3.8:27b)
  #   CREW_API_KEY_FILE — path to bearer-token file
  #                       (default /run/agenix/api-router-<hostname>)
  #   CREW_REPO_ROOT    — where <file> tag paths land (default cwd)
  runCrewPy = ./run_crew.py;

  crewCommand = ''
    ---
    description: Run the local Qwen developer crew to generate, modify, and self-correct files locally.
    argument-hint: <task description>
    allowed-tools: Bash(*)
    ---
    # Local Developer Crew Orchestration

    You are the cloud Manager orchestrator (Claude). Your task is to
    delegate the raw file generation, coding, and initial syntax
    validation to the local Qwen developer crew via the LiteLLM router
    on p620.

    Execute the crew script with the user's task description (the
    script resolves file paths against the current working directory,
    so files land where the user is working):

    !CREW_ENDPOINT=${cfg.endpoint} CREW_MODEL=${cfg.model} python3 ${runCrewPy} "$ARGUMENTS"

    ## Review Protocol
    Once the script has executed:
    1. Parse the output and any git diff printed by the local worker.
    2. Confirm the syntax checks passed successfully.
    3. Review the changes for architectural soundness and compliance
       with the project's conventions.
    4. Present the verified git diff to the user for final approval.
  '';
in
{
  options.programs.claude-code-commands = {
    enable = mkEnableOption ''
      Declarative Claude Code user-level slash commands at
      ~/.claude/commands/. Adds /team, /crew and /blog — see source file
      for details.
    '';

    endpoint = mkOption {
      type = types.str;
      default = "http://p620:4000/v1/chat/completions";
      example = "http://127.0.0.1:11434/v1/chat/completions";
      description = ''
        OpenAI-compatible chat-completion endpoint that /crew talks to.
        Defaults to p620's LiteLLM router on the tailnet, which proxies
        the local Ollama service and accepts the per-host
        `api-router-<host>` bearer key. Override only if you have a
        different proxy in front of your model.
      '';
    };

    model = mkOption {
      type = types.str;
      default = "qwen3.8:27b";
      example = "claude-sonnet-4-6";
      description = ''
        Model name as the configured endpoint advertises it. For our
        LiteLLM router these are the aliases in model_list (qwen3.8:27b,
        qwen3, claude-sonnet-4-6, gemma4, …). Pick whichever balance
        of speed/quality you want — the default matches the persistent
        model on p620, so /crew hits an already-loaded model instead of
        forcing an evict-and-load on every run.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".claude/commands/team.md".text = teamCommand;
    home.file.".claude/commands/agent-team.md".text = agentTeamCommand;
    home.file.".claude/commands/crew.md".text = crewCommand;
    # /blog — bundled as a source file rather than inline text because the
    # command body is full of shell ${...} and Liquid {{ }} braces that a
    # Nix '' string would try to interpolate. Deploys to every host that
    # enables this module (p620, p510, razer).
    home.file.".claude/commands/blog.md".source = ./blog.md;

    # /dns — GoDaddy DNS management. Source-file mode so the body's $ARGUMENTS
    # and bash invocations aren't touched by Nix string interpolation. Pairs
    # with the `dns` skill at home/development/claude-code-skills/dns/.
    home.file.".claude/commands/dns.md".source = ./dns.md;
  };
}
