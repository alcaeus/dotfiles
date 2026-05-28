# Global Agent Rules

## Hard Stop Conditions (always escalate to human)
- About to execute destructive irreversible actions (dropping DB columns, deleting untracked files, force-pushing)
- Ticket acceptance criteria are contradictory or cannot be resolved from the codebase
- Reviewer loop has failed 3 consecutive rounds
- Any MCP or tool call fails unrecoverably

## Forbidden Actions
- Never push to main/master or to an "upstream" origin
- Never `git worktree remove` — leave cleanup to the human
- Never modify files outside the current worktree root
- Never commit `.feature-builder/` contents

## Definition of Done
- All acceptance criteria from the ticket are met
- Tests written and passing
- Linter and type checker passing (use whatever is configured in the project)
- Reviewer has issued a PASS verdict
- `pr-description.md` written

## Commit Style
- Logical, atomic commits per plan step
- Message format: `<ticket-id>: <description>` — ticket ID first, then an imperative verb phrase (e.g. `PHPC-2486: Require non-null namespace arguments`)
- No trailing period. No Conventional Commits `feat:`/`fix:` prefix — the ticket ID is the scope
- For untracked housekeeping with no ticket, omit the ticket prefix entirely

## PR Description Style
- Ticket reference on its own line at the top (just the ID, no label)
- Prose explanation of what was done and why — include trade-offs and things deliberately NOT done
- Use Markdown bullet lists for enumerated items; backtick-format all class names, method names, constants
- Call out unfinished work with `- [ ]` todo checkboxes; prefix with `[PoC]` when appropriate
- Explicitly note future work and suggest splitting into separate tickets where scope would balloon
- Tag specific reviewers by name when seeking targeted input

## Code Style & Design Values

### General
- **Prefer deletion over addition**: smallest-possible surface area; remove handlers, checks, and duplicated logic before adding new ones
- **Consistency over local optimization**: naming and structural consistency across a codebase outweighs micro-optimisations
- **Defer to language/framework defaults**: let PHP's default handlers (debug output, serialization, comparison) do their job rather than reimplementing them
- **Bound PRs to their stated purpose**: defer unrelated improvements to separate tickets; do not conflate refactoring with feature work
- **Boolean return types over int sentinels**: prefer `bool` when a function only signals success/failure

### PHP
- PSR naming: `PascalCase` classes, `camelCase` methods/properties
- Think carefully about semantic correctness of interface implementations (e.g. what `Countable::count()` should actually return)
- Be alert to PHP version compatibility; flag when a change requires a version bump
- For deprecations, provide an explicit migration path and use a `read_property` handler workaround when PHP lacks property-level deprecation

### C (PHP extension)
- Use `phongo_` prefix consistently (not `php_phongo_`); structs follow `phongo_<name>_t`; macros in `SCREAMING_SNAKE_CASE`
- Memory safety is the top priority: always check for missing `bson_destroy`, missing `Z_TRY_ADDREF_P` on zvals passed to ownership-taking functions, buffer overflows, and incorrect `erealloc` usage
- Prefer macros to eliminate repetitive boilerplate (class declarations, struct accessors) but flag legibility trade-offs for reviewer sign-off

### Testing
- `.phpt` files for C extension tests; PHPUnit for PHP library tests
- Prefer deterministic assertions over broad wildcards (`%s`, `%d`, `%A`) — only use wildcards when the value is genuinely non-deterministic
- Test filenames must match what the test actually exercises
- Cover deprecation notices explicitly; do not hide them behind wildcards
- Use debug PHP builds in CI to catch return-type violations

## Code Review Tone (when reviewing others)
- Collaborative and educational: explain *why*, not just *what* — cite PHP internals, RFCs, or source lines to back up points
- Mark non-blocking comments clearly: prefix with "Minor:" or suggest deferring to a separate ticket
- Use GitHub suggestion blocks for concrete proposed changes
- Cross-reference related PRs, tickets, and external resources
- Engage substantively with AI reviewer comments — accept valid findings, push back with clear reasoning on false positives

## Self-Documentation in Code
- Leave inline comments in PRs to narrate non-obvious decisions, especially around memory management and side effects
- Proactively explain surprising test changes in PR descriptions
- Explicitly document deliberate omissions ("refrained from X to keep scope bounded")

## Escalation Output
Write to `.feature-builder/escalation.md` and exit. Do not wait for input.
