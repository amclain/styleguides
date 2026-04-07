---
name: format-review
description: Review code for style violations and walk through them with the user. Use when the user says "style review", "review my code", "check style", or wants to understand style issues before fixing them.
---

# Format Review

Review the project's code for style violations and present them as numbered suggestions. The user decides which to apply.

## Loading the Style Guide

The style guide must be loaded before reviewing. Derive the styleguides repo path from one of:
1. The `@` import in the project's CLAUDE.md (strip `general/CLAUDE.md` to get the repo root)
2. The `deps/styleguides/` directory if it exists

Read these files in order:
1. `<repo_root>/general/CLAUDE.md` - general principles and operating modes
2. The language guide detected from file extensions (e.g. `<repo_root>/elixir/CLAUDE.md`)
3. Any `@` imports at the top of the language guide (e.g. `elixir/testing.md`)

The style guide contains all the rules. Apply them as documented.

## Scope

Default: all files changed since the last commit (`git diff` and `git diff --staged`). Read full files for context; flag issues only in changed lines.

If invoked with `--all`, review the entire codebase.

## Output Format

Present violations as a terse numbered list:

```
1. lib/device/modbus.ex:15 - @impl true should name the behaviour: @impl GenServer
2. lib/device/modbus.ex:22 - GenServer.on_start() has parens on zero-arity type: GenServer.on_start
3. spec/device/modbus_spec.exs:1 - .Test suffix should be .Spec for ESpec
```

Do not explain reasoning unless the user asks. The user can:
- `explain #N` -explain the reasoning behind suggestion N
- `apply #N` -apply a specific suggestion
- `apply all` -apply all suggestions
- `skip` -dismiss all suggestions

## Procedure

1. Load the style guide (see above)
2. Identify changed files via `git diff --name-only` and `git diff --staged --name-only`
3. Run mechanical checks on the changed files (see the format-code skill for the checklist) - these find patterns that are difficult to detect by reading code
4. Read each changed file

The following passes are distinct review concerns (see format-code skill for full details on each). For small diffs, run all passes sequentially. For large diffs or `--all` reviews, each pass should be a separate cold agent reporting to the orchestrator.

5. **Structural pass** - file-level ordering and grouping (see format-code for full checklist)
6. **Mechanical check review** - evaluate grep/awk results against style rules
7. **Identifier scan** - apply the detokenize technique from the general guide's Precision Over Length rule to detect abbreviations and grammar problems
8. **Comment quality pass** - redundant comments, comments-as-names signals, "what" comments that should be "why". When a comment explains what a literal value represents, the representation is wrong - flag the representation, not just the comment.
9. **Code style pass** - line-level formatting, whitespace, idioms, brace placement

After all passes:

10. Present the numbered list (all findings combined, grouped by pass)
11. Wait for user input
12. Apply requested changes using the Edit tool

## Important

- Do NOT delegate style fixes to Sonnet subagents. Sonnet lacks the judgment to distinguish between similar style cases and will apply rules incorrectly. Apply all fixes directly as the Opus review agent.
- Do NOT change program logic or behavior - only flag style issues
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT flag their parentheses
- Trailing commas are valid in collections but NOT in function argument lists
- When in doubt about whether something is a violation, do not flag it
- Suggestions, not mandates - the user decides
