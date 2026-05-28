---
description: |
  Resume an escalated build-feature with human guidance. Use after /build-feature has escalated (e.g. after 3 failed reviewer rounds). Invoke from inside the project directory. Usage: /continue-feature <your instructions>
allowed-tools: Agent, Task, Bash, Read, Write
permissionMode: bypassPermissions
---

# /continue-feature

Resume work on an existing build-feature after a human-required escalation. Must be invoked from within the project directory (the directory that contains `.feature-builder/`).

```
/continue-feature <instructions>
```

- `<instructions>`: Free-form text describing what to change and how to resolve any implementer/reviewer conflict. The entire `$ARGUMENTS` value is treated as guidance.

## Setup

1. Verify `.feature-builder/` exists in the current directory. If not, print an error and stop:
   ```
   Error: No .feature-builder/ directory found in the current directory. Run this command from inside the project directory where build-feature was invoked.
   ```
3. Read the following files (they must exist):
   - `.feature-builder/feature-brief.md`
   - `.feature-builder/plan.md`
4. Read the following files if they exist:
   - `.feature-builder/escalation.md` — understand why it escalated
   - `.feature-builder/run-log.md` — understand prior round history
5. Set `$HUMAN_GUIDANCE`:
   - **If `$ARGUMENTS` is non-empty**: set `$HUMAN_GUIDANCE` to `$ARGUMENTS`.
   - **If `$ARGUMENTS` is empty**: display the conflict to the user by printing in the conversation:
     ```
     ## Escalation / Conflict
     <contents of escalation.md, or "(no escalation file found)" if absent>
     ```
     Then ask directly:
     > How would you like to resolve this? Describe what changes should be made or what direction to take.
     Wait for their response and use it as `$HUMAN_GUIDANCE`. Do not proceed until a non-empty response is received.
6. Resolve the canonical remote: `git remote | grep -q '^upstream$' && echo upstream || echo origin` — store as `$REMOTE`.
7. Resolve the default branch: `git remote show $REMOTE | grep 'HEAD branch' | awk '{print $NF}'`. Store as `$DEFAULT_BRANCH`.
8. Append `[$(date)] Resuming via /continue-feature. Human guidance provided: yes` to `.feature-builder/run-log.md`.

## Stage R0 — Write Human Guidance Brief

Write `.feature-builder/human-guidance.md`:

```markdown
# Human Guidance

## Instructions from Human
<$HUMAN_GUIDANCE>

## Prior Escalation Reason
<contents of escalation.md if it exists, otherwise "(no escalation file found)">

## What to Do
Apply the human's instructions as a corrective brief. Treat each instruction as a required change.
Where the instructions resolve a reviewer objection, implement the resolution literally.
Where instructions are silent on a point, use your best judgement consistent with the plan.
```

Log completion to `run-log.md`.

## Stage R0.5 — Amend the Plan

Invoke the `planner` agent with:
- `.feature-builder/feature-brief.md`
- `.feature-builder/plan.md` (the existing plan to amend)
- `.feature-builder/human-guidance.md`
- `.feature-builder/escalation.md` (if it exists)
- Full read access to the project directory

Instruct the planner to **amend `plan.md` in place** to reflect the human guidance and resolve the escalation, rather than producing a plan from scratch. The planner should:
- Preserve steps that are unaffected by the guidance.
- Update, remove, or add steps as directed by the human guidance.
- Emit CLARIFY if the guidance is ambiguous and a question would meaningfully change the amended plan (follow the same CLARIFY loop as in `build-feature`: ask the user, write answers to `clarification-response.md`, re-invoke planner).
- Emit ESCALATE if the guidance contradicts the feature brief in an unresolvable way.

If the planner emits ESCALATE: write to `.feature-builder/escalation.md` and stop.

Log completion to `run-log.md`.

## Stage R1 — Corrective Implementation Pass

Invoke the `implementer` agent with:
- `.feature-builder/plan.md`
- `.feature-builder/assumptions.md` (if it exists)
- `.feature-builder/human-guidance.md` as the corrective brief
- Full read/write access to the project directory

The corrective brief replaces the reviewer's failure list. The implementer should treat `human-guidance.md` as authoritative and apply it before re-running tests and the linter.

If the implementer emits ESCALATE: write to `.feature-builder/escalation.md` and stop with:
```
Escalated during corrective implementation. See .feature-builder/escalation.md.
```

Log completion to `run-log.md`.

## Stage R2 — Review Loop (fresh counter)

Reset round counter to 0. Max 3 rounds:

1. Invoke the `reviewer` agent with: `feature-brief.md`, `plan.md`, the output of `git diff $DEFAULT_BRANCH`, and any project `CLAUDE.md`.
2. If verdict is **PASS**: proceed to Stage R3.
3. If verdict is **FAIL**: pass the structured failure list back to the `implementer` as a corrective brief, increment round counter, repeat.
4. If verdict is **ESCALATE** or round counter hits 3: write to `.feature-builder/escalation.md` and stop with:
   ```
   Escalated after review loop. See .feature-builder/escalation.md.
   Run /continue-feature again with updated guidance to retry.
   ```

Log each round verdict to `run-log.md`.

## Stage R3 — Wrap Up

Invoke the `reviewer` agent one final time in "PR description mode": produce `.feature-builder/pr-description.md` summarising what was built, why, and any notable decisions or deviations from the original plan.

Log completion to `run-log.md`.

## Stage R4 — Draft PR

Run all commands from the current directory.

Derive `$SLUG` from the current branch name: `git rev-parse --abbrev-ref HEAD | sed 's|feature/||'`.

Check whether a PR already exists for this branch:
```
gh pr view --json url -q .url 2>/dev/null
```

**If a PR already exists** (`$EXISTING_PR_URL` non-empty):
1. Update the PR body with the revised description:
   ```
   gh pr edit $EXISTING_PR_URL --body-file .feature-builder/pr-description.md
   ```
2. Print: `Updated existing PR: $EXISTING_PR_URL`

**If no PR exists yet**:
1. Push the feature branch:
   ```
   git push -u origin feature/$SLUG
   ```
2. Read `.feature-builder/pr-description.md` for the PR body.
3. Create a **draft** pull request:
   ```
   gh pr create --draft \
     --title "<slug>: <first line of pr-description>" \
     --body-file .feature-builder/pr-description.md \
     --base $DEFAULT_BRANCH
   ```
   Capture the returned URL as `$PR_URL`.
4. Assign to yourself:
   ```
   gh pr edit $PR_URL --add-assignee @me
   ```

Log the PR URL to `run-log.md`.

Print a final summary: branch name and PR URL.
