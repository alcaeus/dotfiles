---
description: |
  Autonomously implement a feature from a GitHub or JIRA ticket, or from a plain-text description. Creates a new branch, fetches or synthesizes ticket context, plans, implements, reviews the work, and opens a draft PR on GitHub requesting your review. Usage: /build-feature <ticket-id-or-url> OR /build-feature <plain description of the feature>
allowed-tools: Agent, Task, Bash, Read, Write
permissionMode: bypassPermissions
---

# /build-feature

Autonomously implement a feature. Argument: a ticket ID or URL (e.g. `PROJ-123`, a GitHub issue URL) **or** a plain-text description of the feature to build.

## Logging convention

Throughout this workflow, append structured entries to `$WORKDIR/.feature-builder/run-log.md` using this format:

```
[<ISO timestamp>] <stage>: <message>
```

For agent invocations, write two entries — one before invoking (`started`) and one after (`completed in Xs` or `failed: <reason>`). For management commands (git, gh), write an entry on failure with the command's stderr output. On success only log if it's a meaningful milestone (e.g. PR URL).

## Setup Phase
1. Determine the current project from the working directory. Resolve the canonical remote: `git remote | grep -q '^upstream$' && echo upstream || echo origin` — store as `$REMOTE`. Identify the GitHub org/repo from `git remote get-url $REMOTE`.
2. **If `$ARGUMENTS` is empty**: ask the user directly in the conversation:
   > What would you like to build? Provide a ticket ID/URL or a plain-text description of the feature.
   Wait for their response and use it as `$ARGUMENTS` before continuing. Do not proceed until a non-empty response is received.
3. Determine the input type:
   - **Ticket**: `$ARGUMENTS` matches a JIRA-style key (`[A-Z]+-\d+`) or starts with `https://`.
   - **Description**: anything else.
4. Derive a short slug for branch naming:
   - Ticket: use the ticket ID (e.g. `PROJ-123`).
   - Description: slugify the first ~5 words (lowercase, hyphens, no punctuation), e.g. `add-user-export-endpoint`.
5. Check the current branch: `git rev-parse --abbrev-ref HEAD`. If it does **not** start with `feature/`, create a new worktree on a new branch:
   - Determine the worktree path: the parent directory of `$PWD` plus `/$SLUG` (e.g. if `$PWD` is `~/Code/doctrine/mongodb-odm/main`, use `~/Code/doctrine/mongodb-odm/$SLUG`).
   - Create the worktree and branch in one command:
     ```
     git worktree add <worktree-path> -b feature/$SLUG
     ```
   - If this fails, log `setup: git worktree add failed: <stderr>` and stop.
   - Set `$WORKDIR` to `<worktree-path>`. All subsequent work (file edits, commits, agent invocations) happens inside `$WORKDIR`.
   If the current branch **already** starts with `feature/`, skip worktree creation and set `$WORKDIR` to `$PWD`.
6. Create `.feature-builder/` in `$WORKDIR`.
7. Log `setup: starting build-feature for "$ARGUMENTS" on branch feature/$SLUG in $WORKDIR`.

## Stage 1 — Feature Brief
**If the input is a ticket:** Log `stage-1: ticket-fetcher started`. Invoke the `ticket-fetcher` agent with the ticket ID/URL and the GitHub remote URL. Output must be written to `$WORKDIR/.feature-builder/feature-brief.md`. Log `stage-1: ticket-fetcher completed in Xs` (or `failed: <reason>` and stop).

**If the input is a description:** Write `$WORKDIR/.feature-builder/feature-brief.md` directly with the following structure (no agent needed):
```
# Feature Brief

## Source
Plain-text description (no ticket)

## Description
<the full $ARGUMENTS text>

## Acceptance Criteria
<derive 3-7 concrete, testable criteria from the description>

## Out of Scope
<note anything the description does NOT mention>
```

Log `stage-1: feature-brief.md written (<N> acceptance criteria derived)`.

## Stage 2 — Planning
Run the following loop (no hard round limit — continue until plan is produced or a stop condition is hit):

1. Log `stage-2: planner started (round <N>)`. Invoke the `planner` agent with: `feature-brief.md`, full read access to `$WORKDIR`, and `clarification-response.md` if it exists from a prior round. Log `stage-2: planner completed in Xs`.
2. If the planner emits **ESCALATE**: log `stage-2: planner escalated`, write to `escalation.md` and stop.
3. If the planner emits **CLARIFY**:
   - Read `.feature-builder/clarification-request.md`.
   - Ask the user each question directly in the conversation, clearly stating they come from the planner and that answers will be fed back automatically.
   - Write the user's answers to `.feature-builder/clarification-response.md`:
     ```
     # Clarification Responses

     ## Question N
     <restate the question>
     **Answer:** <user's answer>
     ```
   - Log `stage-2: clarification round <N> complete, re-invoking planner`.
   - Return to step 1.
4. If the planner produces `plan.md`: log `stage-2: plan.md produced` and proceed to Stage 3.

## Stage 3 — Implementation Loop
Log `stage-3: implementer started`. Invoke the `implementer` agent with: `plan.md`, `assumptions.md`, and full read/write access to `$WORKDIR`.
The implementer runs its own internal retry loop (see agent definition).
If the implementer emits an ESCALATE signal, log `stage-3: implementer escalated`, write it to `escalation.md` and stop.
Log `stage-3: implementer completed in Xs (<N> internal retry rounds)`.

## Stage 4 — Review Loop
Resolve the default branch first: `git remote show $REMOTE | grep 'HEAD branch' | awk '{print $NF}'`. Use this as `$DEFAULT_BRANCH` throughout.

Max 3 rounds:
- Log `stage-4: reviewer started (round <N>)`. Invoke the `reviewer` agent with: `feature-brief.md`, `plan.md`, the output of `git -C $WORKDIR diff $DEFAULT_BRANCH`, and any project `CLAUDE.md`. Log `stage-4: reviewer completed in Xs — verdict: <PASS|FAIL|ESCALATE>`.
- If verdict is PASS: proceed to Stage 5.
- If verdict is FAIL: log `stage-4: passing failure list to implementer (round <N>)`, pass the structured failure list back to the `implementer` as a corrective brief, increment round counter, repeat.
- If verdict is ESCALATE or round counter hits 3: log `stage-4: escalating after <N> rounds`, write to `escalation.md` and stop.

## Stage 5 — Wrap Up
Log `stage-5: reviewer (PR description mode) started`. Invoke the `reviewer` agent one final time in "PR description mode": produce `.feature-builder/pr-description.md` summarising what was built, why, and any notable decisions or deviations from the original plan. Log `stage-5: pr-description.md written`.

## Stage 6 — Draft PR
1. Push the feature branch to the `origin` remote (run from `$WORKDIR`):
   ```
   git -C $WORKDIR push -u origin feature/$SLUG
   ```
   If this fails, log `stage-6: git push failed: <stderr>` and stop.
2. Read `.feature-builder/pr-description.md` for the PR body.
3. Create a **draft** pull request targeting `$DEFAULT_BRANCH` (resolved in Stage 4):
   ```
   gh pr create --draft \
     --title "<ticket-id or slug>: <first line of pr-description>" \
     --body-file .feature-builder/pr-description.md \
     --base $DEFAULT_BRANCH
   ```
   Capture the returned PR URL as `$PR_URL`. If this fails, log `stage-6: gh pr create failed: <stderr>` and stop.
4. Assign the PR to yourself so it appears in your GitHub queue:
   ```
   gh pr edit $PR_URL --add-assignee @me
   ```
   (GitHub does not allow requesting a review from the PR author, so assignment is used instead.)
   If this fails, log `stage-6: gh pr edit --add-assignee failed: <stderr>` (non-fatal, continue).
5. Log `stage-6: draft PR created at $PR_URL`.
6. Print a final summary to stdout: branch name and PR URL.
