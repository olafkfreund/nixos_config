{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.programs.claude-code-commands;

  # /team — global slash command. Takes a task as $ARGUMENTS, decomposes
  # into independent subtasks, spawns an agent team with one teammate
  # per subtask, and assigns each subtask. Policy choices:
  #   - Permissive: always spawn a team, even for a single subtask
  #   - Match lead model: teammates inherit the lead's current /model
  # Both decided in the PR that introduced this file.
  #
  # Reference: https://code.claude.com/docs/en/agent-teams
  teamCommand = ''
    ---
    description: Decompose a task and dispatch it to an agent team — one teammate per independent subtask
    argument-hint: <task description>
    ---

    # Team mode

    You are coordinating an **agent team** to work on this task:

    $ARGUMENTS

    ## Required workflow

    Follow these steps in order. Do not start implementation yourself —
    your job is decomposition, spawning, coordination, and synthesis.

    ### 1. Decompose into independent subtasks

    Break the task into 1–5 self-contained pieces. Each subtask must:
    - Be workable in parallel (no implicit ordering dependencies)
    - Produce a concrete artifact (a finding, a file edit, a tested change)
    - Be sized to one coherent piece of work (not "do everything in repo X")

    If subtasks share a file, call out the coordination point explicitly
    so teammates can negotiate via the shared task list and `SendMessage`.

    ### 2. Pick the team size

    **One teammate per subtask.** Cap at 5; if you genuinely identified
    more than 5 independent subtasks, group the smallest ones until you
    fit. If you only found 1 subtask, that's fine — spawn a one-person
    team. (Per the policy chosen when this command was authored, the
    refusal-fallback to a sub-agent is not used; we always spawn.)

    ### 3. Show me the plan before spawning

    Output, in this exact shape:

    ```
    Subtasks (N):
      1. <name> — <one-line scope>
      2. <name> — <one-line scope>
      ...

    Team size: N teammates
    Teammate model: match the lead (inherit my current /model selection)
    Coordination points:
      - <file or area> shared between teammates A and B (if any)
      - or "none — subtasks are fully independent"
    ```

    ### 4. Spawn the team

    Issue a single natural-language instruction to create the team. For
    each teammate, include in the spawn prompt:

    - The teammate's name (so I can reference it via Shift+Down later)
    - The specific subtask scope and acceptance criteria
    - All required context — teammates don't inherit your conversation
      history, so be explicit about the files, conventions, and
      constraints they need to know
    - Any coordination notes ("teammate X owns file Y; ask them before
      editing it")

    **Model**: explicitly tell the team to use my current model for each
    teammate. Per the agent-teams docs, teammates don't inherit the
    lead's `/model` selection automatically — you must say "use the same
    model as the lead" or set Default teammate model in `/config`.

    **Plan approval**: for any subtask that involves destructive changes
    (schema migrations, mass renames, deletions, force-pushes), spawn
    that teammate with `Require plan approval before they make any
    changes`. State the rejection criteria in the lead's prompt so I
    can approve consistently ("only approve plans that include
    rollback steps").

    ### 5. Wait, don't implement

    Once the team is running, **do not start working on any subtask
    yourself**. Your job is to:
    - Monitor for `Needs input` states and respond
    - Approve or reject teammate plans against the criteria you set
    - Re-broadcast cross-cutting decisions
    - Synthesize results when teammates finish

    If you catch yourself starting to implement, stop and remind
    yourself: "the team owns the work; I own the coordination."

    ### 6. Synthesize and clean up

    When every teammate has finished:
    - Read each teammate's final output via Shift+Down + Space (peek)
    - Produce one unified summary back to me: what changed, what passed,
      what's still open, what to do next
    - **Clean up the team explicitly** by asking each teammate to shut
      down and then running `Clean up the team`. Per the docs, cleanup
      must be run by the lead, never by teammates.

    ## Reminders

    - Each teammate consumes quota independently. 5 teammates ≈ 5× a
      normal session's spend.
    - Teammates can't spawn their own teams (no nesting).
    - `/resume` doesn't restore in-process teammates — if I resume this
      session and the team is gone, you'll need to spawn a new one.
    - Use `/tasks` from inside any teammate's session to see the shared
      task list.
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
  #   CREW_MODEL        — model alias (default qwen3:14b)
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
      default = "qwen3:14b";
      example = "claude-sonnet-4-6";
      description = ''
        Model name as the configured endpoint advertises it. For our
        LiteLLM router these are the aliases in model_list (qwen3:14b,
        qwen3, claude-sonnet-4-6, gemma4, …). Pick whichever balance
        of speed/quality you want — the default qwen3:14b matches the
        previous bare-ollama behaviour.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".claude/commands/team.md".text = teamCommand;
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
