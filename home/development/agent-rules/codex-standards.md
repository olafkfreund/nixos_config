# Codex global standards

> Agent OS User Standards
> Adapted from `~/.claude/CLAUDE.md` on 2026-09-16.
> Maintained copy: update this tracked file and rebuild to change Codex instructions.

## Purpose

This file directs Codex to use your personal Agent OS standards for all development work.
These global standards define your preferred way of building software across all projects.

---

## Expert Reasoning Protocol (MANDATORY)

**⚠️ CRITICAL: You MUST follow this iterative reasoning cycle for EVERY task, no matter how simple it appears.**

### Phase 1: PLAN (Before ANY action)

> If an approved `plan/` file exists for the task (see the managed artifact
> workflow), this phase is a citation of the plan step being executed, not a new plan.
> If implementation deviates, update `plan/` in the same commit as the code.

Before writing code, running commands, or making changes:

1. **Understand the Goal**
   - What is the user actually trying to achieve?
   - What are the success criteria?
   - What constraints exist (time, resources, compatibility)?

2. **Decompose the Problem**
   - Break the task into discrete, testable steps
   - Identify dependencies between steps
   - Estimate complexity of each step

3. **Assess Current State**
   - What files/systems exist?
   - What is the current behaviour?
   - What could break?

4. **Formulate Strategy**
   - Choose approach and justify WHY
   - Identify alternatives considered
   - List assumptions being made

5. **Define Checkpoints**
   - How will you verify each step worked?
   - What does "done" look like?

**Output format for PLAN phase:**

```markdown
## 🎯 PLAN

**Goal:** [one sentence]
**Success criteria:** [bullet list]

**Steps:**
1. [step] → verify by [check]
2. [step] → verify by [check]
...

**Approach:** [chosen strategy]
**Why this approach:** [reasoning]
**Assumptions:** [list]
**Risks:** [potential issues]
```

### Phase 2: ACT (Execute ONE step at a time)

Execute steps sequentially, never in bulk:

1. **Announce** what you're about to do
2. **Execute** exactly ONE step
3. **Capture** the output/result
4. **Verify** the checkpoint before proceeding

**Rules:**

- NEVER chain multiple commands without checking results
- NEVER assume a step succeeded—verify it
- STOP immediately if something unexpected happens
- Show your work—include command outputs

**Output format for ACT phase:**

```markdown
## ⚡ ACT: [step description]

**Executing:** [command or action]
**Expected result:** [what should happen]

[actual output]

**Checkpoint:** [pass/fail + evidence]
```

### Phase 3: REFLECT (After each step AND at completion)

After each action, perform honest self-assessment:

1. **Did it work?** Compare actual vs expected
2. **Side effects?** Did anything unexpected happen?
3. **Still on track?** Does the plan still make sense?
4. **New information?** What did we learn?
5. **Quality check:** Is this the RIGHT solution, not just A solution?

**Output format for REFLECT phase:**

```markdown
## 🔍 REFLECT

**Result:** [success/partial/failure]
**Expected vs Actual:** [comparison]
**Side effects:** [none/list]
**New insights:** [what we learned]
**Plan still valid:** [yes/needs adjustment]
**Quality assessment:** [is this good enough?]
```

### Phase 4: REVISE (When needed)

If reflection reveals issues:

1. **Diagnose** the root cause, not just symptoms
2. **Update** the plan with new information
3. **Consider** if the approach itself needs changing
4. **Document** what went wrong and why

**Triggers for REVISE:**

- Step failed or produced unexpected results
- Discovered new constraints or requirements
- Found a better approach mid-execution
- User provided new information

**Output format for REVISE phase:**

```markdown
## 🔄 REVISE

**Issue:** [what went wrong]
**Root cause:** [why it happened]
**Options:**
  A. [option] - pros/cons
  B. [option] - pros/cons

**Decision:** [chosen path]
**Updated plan:** [new steps if changed]
```

### Mandatory Behaviours

#### Always

- Read existing code/files BEFORE modifying
- Run tests after changes (if tests exist)
- Use version control awareness (check git status)
- Prefer small, reversible changes
- Validate inputs and assumptions

#### Never

- Skip the PLAN phase, even for "simple" tasks
- Execute multiple steps without reflection
- Assume success without verification
- Make bulk changes without checkpoints
- Ignore errors or warnings

#### On Failure

- STOP and REFLECT before retrying
- Don't repeat the same action expecting different results
- Consider if you're solving the right problem
- Ask user for clarification if stuck after 2 attempts

### Quality Gates

Before declaring a task complete:

- [ ] All success criteria met?
- [ ] All checkpoints passed?
- [ ] No unaddressed warnings or errors?
- [ ] Code/changes are clean and documented?
- [ ] Would you be proud of this work?

**Final output:**

```markdown
## ✅ COMPLETE

**Achieved:** [summary]
**Verified by:** [evidence]
**Files changed:** [list]
**Follow-up recommended:** [if any]
```

### Example Cycle

User: "Add a config file parser to my CLI"

**PLAN:** Understand CLI structure → identify config format → design parser interface → implement → test → integrate

**ACT 1:** Read existing CLI code structure
**REFLECT 1:** Found it uses clap, no existing config. Plan valid.

**ACT 2:** Create config struct with serde
**REFLECT 2:** Compiles. Matches expected fields.

**ACT 3:** Add file reading logic
**REFLECT 3:** Works for happy path. Need error handling.

**REVISE:** Add proper error types before continuing.

**ACT 4:** Implement error handling
**REFLECT 4:** All error cases covered. Tests pass.

**ACT 5:** Integrate with main CLI
**REFLECT 5:** CLI now loads config. Manual test passed.

**COMPLETE:** Config parser added with full error handling.

---

## Global Standards

Agent-OS standards and workflow templates (read on demand, not auto-loaded):

- Standards: `~/.agent-os/standards/{tech-stack,code-style,best-practices}.md` —
  note the tech-stack defaults describe a Rails/PostgreSQL/React stack;
  per-project standards override them.
- Claude workflow commands: `/plan-product`, `/create-spec`, `/execute-tasks`,
  `/analyze-product` are Claude commands, not native Codex commands. In Codex,
  follow the included artifact workflow and available task-relevant skills.
- If a referenced standards file is missing, report its absence rather than
  inventing its contents.

NixOS-specific standards live in the installed `nixos` skill and applicable
specialized NixOS skills (load on demand).
