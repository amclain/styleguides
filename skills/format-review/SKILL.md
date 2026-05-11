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

Read these files in full (single Read call per file, no offset or limit, per the "Reading This Guide" rule in `general/CLAUDE.md`). If the Read tool errors that a file exceeds its size limit, read it in sequential chunks via `offset`+`limit` and treat the union as a single full read; do not skip the file or read only part of it.

1. `<repo_root>/general/CLAUDE.md` - general principles, operating modes, and the "Reading This Guide" rule
2. `<repo_root>/general/review-orchestration.md` - the multi-agent orchestration framework and per-language instantiations
3. `<repo_root>/<lang>/CLAUDE.md` - the language guide for the files being reviewed
4. `<repo_root>/general/testing.md` - if any file in scope is a test file (cross-language testing principles)
5. `<repo_root>/<lang>/testing.md` - if any file in scope is a test file (load on demand; not propagated to subagents via `@` import, so list its path in the dispatch prompt for any task whose scope includes test files)
6. Any additional mechanics references the language guide specifies for frameworks in use

Do not improvise the orchestration or substitute training-data patterns for the rules. The framework captures specific failure modes that generic approaches miss.

## Mode: Review

This skill operates in review mode. It produces findings and presents them as numbered suggestions for the user to accept or reject. Use `format-code` for the autonomous fix mode.

## Procedure

1. **Load the style guide** per the section above.

2. **Determine scope** per Section 3 Step 1 of the orchestration framework. Default is changed lines only (`git diff` and `git diff --staged`); `--all` reviews the entire codebase.

3. **Produce the task manifest** per Section 3 Steps 2-5 of the framework.

4. **Enumerate dispatches before launching.** Write out the dispatches you are about to make as a numbered list. Each item: task type (1.1-1.6), model, file scope, required reading. Compare your list against the framework's Section 3 Step 4 manifest schema and Step 6 launch rules - count of dispatches, model assignments, dependency ordering. If the list deviates from the framework (fewer dispatches, model substitution, merged tasks, in-context execution of any reviewer task), stop and explain the deviation; do not proceed with it. This step exists because the lead's natural reflex is to optimize away dispatches that "look mechanical" or "don't need an agent." The framework's task breakdown is load-bearing and the cold-context property is what's being preserved, not LLM reasoning. See orchestration framework Section 1.

5. **Launch tasks** per Section 3 Step 6 of the framework. Tasks 1.1, 1.2, 1.3, 1.4, and 1.5 in parallel; Task 1.6 after 1.1 completes.

6. **Compile results** per Section 3 Step 7 of the framework.

7. **Do NOT run post-edit checks** - review mode does not apply fixes, so post-edit checks (line length, etc.) have nothing to verify. They run only in fix mode.

8. **Present the findings** as a terse numbered list (see Output Format below). Every reviewer finding must reach the user as an item or named group; follow `general/review-orchestration.md` § Engagement Is Unconditional; Effort Is Not a Valid Filter. Bucketing-as-skipping ("I dropped the cosmetic ones," "too many alignment sites to surface") is the banned move — the user makes the accept/reject call, not the lead.

9. **Wait for user input.** Apply only what the user asks for.

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

- Do NOT execute reviewer tasks (1.1-1.6) in lead context. Every reviewer task is a dispatch, including mechanical-check tasks that look like simple grep/awk runs. The framework's cold-context property requires fresh subagents.
- Do NOT delegate style fixes to Sonnet subagents. The lead applies all fixes directly.
- Do NOT change program logic or behavior - only flag style issues.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT flag their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- When in doubt about whether something is a violation, do not flag it.
- Suggestions, not mandates - the user decides.
- Apply the framework's group cohesion exception when presenting suggestions: if a change is part of a group of related code, the suggestion may include touching unchanged lines within the group to maintain visual consistency. Note this in the suggestion text.
