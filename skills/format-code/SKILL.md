---
name: format-code
description: Fix code style violations autonomously. Use when the user says "format", "fix style", "clean up code", or as a post-generation formatting pass. This is the mode code generators must use for post-generation review.
---

# Format Code

Fix style violations in the project's code autonomously. Do not prompt the user for each change - apply all fixes directly, run tests, and report a summary.

This skill is a thin entry point. The orchestration logic (task decomposition, model assignments, required reading, scope handling, group cohesion exceptions, quality signals) lives in `general/review-orchestration.md`. This file specifies only the fix-mode behavior that wraps the framework.

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

## Mode: Fix

This skill operates in fix mode. It produces corrections and applies them directly, rather than presenting suggestions for user approval. Use `format-review` for the interactive review mode.

## Procedure

1. **Load the style guide** per the section above.

2. **Determine scope** per Section 3 Step 1 of the orchestration framework. Default is changed lines only (`git diff` and `git diff --staged`); `--all` reviews the entire codebase.

3. **Produce the task manifest** per Section 3 Steps 2-5 of the framework.

4. **Enumerate dispatches before launching.** Write out the dispatches you are about to make as a numbered list. Each item: task type (1.1-1.6), model, file scope, required reading. Compare your list against the framework's Section 3 Step 4 manifest schema and Step 6 launch rules - count of dispatches, model assignments, dependency ordering. If the list deviates from the framework (fewer dispatches, model substitution, merged tasks, in-context execution of any reviewer task), stop and explain the deviation; do not proceed with it. This step exists because the lead's natural reflex is to optimize away dispatches that "look mechanical" or "don't need an agent." The framework's task breakdown is load-bearing and the cold-context property is what's being preserved, not LLM reasoning. See orchestration framework Section 1.

5. **Launch tasks** per Section 3 Step 6 of the framework. Tasks 1.1, 1.2, 1.3, 1.4, and 1.5 in parallel; Task 1.6 after 1.1 completes.

6. **Compile results** per Section 3 Step 7 of the framework.

7. **Apply fixes** - the lead agent applies all confirmed violations directly using the Edit tool. This rule covers fix application only, not reviewer-task execution (those remain dispatched per Step 5). Follow the framework's rule that the lead does not delegate style fixes to subagents (Sonnet lacks the judgment to distinguish similar cases). When deciding what counts as confirmed, follow `general/review-orchestration.md` § Engagement Is Unconditional; Effort Is Not a Valid Filter — every reviewer finding gets engaged, none get bucketed-out on effort or aesthetic grounds, and every disposition (apply / reject-with-rule-grounded-reason / escalate-to-user / defer-with-rule-grounded-reason) is recorded in the summary.

8. **Run post-edit checks** - after applying fixes, re-dispatch Task 1.1 with the language's post-edit checks (line length, anything else the language marks as post-edit), then re-dispatch Task 1.6 to classify the new results. Apply any verification fixes. "Re-dispatch" means launch the task as a fresh subagent per the framework - do not run the checks inline in the lead's context.

9. **Run the project's test suite** - style corrections must not change behavior.

10. **If tests fail**, diagnose and fix. Verify again that tests pass.

11. **Report a summary** of changes: file, rule, what was fixed.

## Important

- Do NOT execute reviewer tasks (1.1-1.6) in lead context. Every reviewer task is a dispatch, including mechanical-check tasks that look like simple grep/awk runs. The framework's cold-context property requires fresh subagents. This rule and the "lead applies fixes directly" rule below govern different procedural phases — review (dispatched) vs fix-application (lead) — and do not collapse into a "lead does the whole workflow" mandate. Per `general/agents.md` § Framework Pattern, the lead's role is mechanical execution against the manifest produced in Step 4 (Enumerate dispatches), not freelance reasoning about which steps to perform inline.
- Do NOT delegate style-fix *judgment* to Sonnet subagents (which findings represent real violations, what the correct fix shape is). The lead applies fixes directly at the fix-application step — see `general/CLAUDE.md` § Post-Generation Review § Scope of "lead applies fixes directly" for the boundary. At scale, "applies fixes directly" includes batch tools the lead invokes against its own consolidated finding set: a script that applies a textual transformation across many findings, with semantics preserved and verified by the test suite, is the lead's mechanical execution at that step, not delegation. The mechanical/judgment distinction is per-finding: a script that fans out a fix the lead has already classified is fix-application; a Sonnet subagent asked to classify which findings are real is delegation, which is what this rule bans.
- Do NOT change program logic or behavior - only fix style.
- ESpec matchers (`be_integer()`, `be_alive()`, `be_truthy()`) are function calls - do NOT remove their parentheses.
- Trailing commas are valid in collections but NOT in function argument lists.
- When in doubt about whether something is a violation, leave it as-is.
- Apply the framework's group cohesion exception: if a change is part of a group of related code, evaluate the group as a whole. This may mean touching unchanged lines within the group to maintain visual consistency.

## When Used as Post-Generation Review

When invoked as a subagent after code generation, scope to all files the generator created or modified. The generator should pass the list of files. Use `--all` semantics for those files (review the full content), since this is cleaning up the agent's own output rather than reviewing an existing codebase.
