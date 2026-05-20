{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
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
in
{
  options.programs.claude-code-commands = {
    enable = mkEnableOption ''
      Declarative Claude Code user-level slash commands at
      ~/.claude/commands/. Adds /team — see source file for details.
    '';
  };

  config = mkIf cfg.enable {
    home.file.".claude/commands/team.md".text = teamCommand;
  };
}
