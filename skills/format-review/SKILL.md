---
name: format-review
description: Review code for style violations and walk through them with the user. Use when the user says "style review", "review my code", "check style", or wants to understand style issues before fixing them.
---

# Format Review

Review the project's code for style violations and present them as numbered suggestions. The user decides which to apply.

This skill is a thin entry point. The orchestration logic (task decomposition, model assignments, required reading, scope handling, group cohesion exceptions, quality signals) lives in `general/review-orchestration.md`. This file specifies only the review-mode behavior that wraps the framework.

## Loading the Style Guide

The style guide must be loaded before reviewing. Derive the styleguides repo path from one of:
1. The `@` import in the project's CLAUDE.md (strip `general/CLAUDE.md` to get the repo root)
2. The `deps/styleguides/` directory if it exists

Read these files in full (single Read call per file, no offset or limit, per the "Reading This Guide" rule in `general/CLAUDE.md`):

1. `<repo_root>/general/CLAUDE.md` - general principles, operating modes, and the "Reading This Guide" rule
2. `<repo_root>/general/review-orchestration.md` - the multi-agent orchestration framework and per-language instantiations
3. `<repo_root>/<lang>/CLAUDE.md` - the language guide for the files being reviewed
4. `<repo_root>/<lang>/testing.md` - if any file in scope is a test file (typically `@` imported; load explicitly if not)
5. Any additional mechanics references the language guide specifies for frameworks in use

Do not improvise the orchestration or substitute training-data patterns for the rules. The framework captures specific failure modes that generic approaches miss.

## Mode: Review

This skill operates in review mode. It produces findings and presents them as numbered suggestions for the user to accept or reject. Use `format-code` for the autonomous fix mode.

## Procedure

1. **Load the style guide** per the section above.
2. **Determine scope** per Section 3 Step 1 of the orchestration framework. Default is changed lines only (`git diff` and `git diff --staged`); `--all` reviews the entire codebase.
3. **Follow the framework** - produce a task manifest per Section 3 Steps 2-5, launch tasks per Step 6, compile results per Step 7. The framework specifies which tasks, which models, which files to read, and how to filter findings to the scope.
4. **Do NOT run post-edit checks** - review mode does not apply fixes, so post-edit checks (line length, etc.) have nothing to verify. They run only in fix mode.
5. **Present the findings** as a terse numbered list (see Output Format below).
6. **Wait for user input.** Apply only what the user asks for.

## Output Format

Present findings as a terse numbered list:

```
1. lib/device/modbus.ex:15 - @impl true should name the behaviour: @impl GenServer
2. lib/device/modbus.ex:22 - GenServer.on_start() has parens on zero-arity type: GenServer.on_start
3. spec/device/modbus_spec.exs:1 - .Test suffix should be .Spec for ESpec
```

Do not explain reasoning unless the user asks. The user can:
- `explain #N` - explain the reasoning behind suggestion N
- `apply #N` - apply a specific suggestion
- `apply all` - apply all suggestions
- `skip` - dismiss all suggestions

When applying suggestions, use the Edit tool directly. Do not delegate to subagents.

## Important

- Do NOT delegate style fixes to Sonnet subagents. The lead applies all fixes directly.
- Do NOT change program logic or behavior - only flag style issues.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT flag their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- When in doubt about whether something is a violation, do not flag it.
- Suggestions, not mandates - the user decides.
- Apply the framework's group cohesion exception when presenting suggestions: if a change is part of a group of related code, the suggestion may include touching unchanged lines within the group to maintain visual consistency. Note this in the suggestion text.
