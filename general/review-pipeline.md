# Review Pipeline Composition

Optional reference for projects building their own custom review pipeline. A project that wants to compose this styleguide's review with other project-owned review types (test validation, logic review, security review, documentation review, scaffolding smoke tests, etc.) into a single coordinated workflow can use the patterns in this file as a starting point. Nothing in this file is required to use the styleguide; the styleguide's own agents are governed by `general/review-orchestration.md`.

Not for the formatter skills. The formatter skills (`/format-code`, `/format-review`, `/format-rewrite`) always run the style-review framework in `general/review-orchestration.md`. That framework is itself a pipeline of dispatched reviewer tasks and applies in full whenever style review runs. This file does not modify that framework; it offers patterns a project may adopt for its own outer workflow that calls style review as one of several review types.

For the cross-cutting reviewer doctrine that governs every cold reviewer the styleguide ships — Shared Reviewer Direction (find siblings on pattern-class findings) and the Lead-Side Companion (sibling scan on reviewer findings) — see `general/review-orchestration.md` § Shared Reviewer Direction and § Lead-Side Companion: Sibling Scan on Reviewer Findings. Those rules live with the styleguide's orchestration, not in this file, because they apply to every reviewer the styleguide dispatches regardless of whether the project wraps style review in a larger pipeline.

---

## Dispatch Plan Format

A dispatch plan is a tabular orchestration artifact the lead and the user reference together to coordinate the workflow. The dispatch plan is distinct from the JSON task manifest in `general/review-orchestration.md` Step 4: the manifest is a programmatic input to the style-review framework's own internal task decomposition; the dispatch plan is a human-readable orchestration table for the project's outer multi-review-type workflow.

### Unique row labels

Every row in the dispatch plan has a unique `<letter><number>` label (`A1`, `B1`, `C1`, `C2`, etc.). The label is the row's identity in conversation: "proceed with A through F", "re-run J1 on the latest tests".

Descriptive tokens in the row-identity column (`lead`, `make test`, `fix`, `verify`, `-`) are forbidden. Multiple rows often share the same descriptive token in a real workflow (five rows may be `make test` runs at different sync points), and shared tokens make rows unreferenceable.

The agent column names which subagent runs the row's work — typically Sonnet for fix-application and verification, Opus for high-judgment review tasks. The agent column is informational, not addressing. Lead-orchestrated work (fix-application, `make test` verification, style-framework invocation) gets its own group letter and `<letter>1` row label, with the dispatched subagent named in the agent column.

The plan is a static structural document. Execution events — re-runs, progress, failures, retries — are tracked outside the plan (memory, session state). The plan's letter assignments are stable across re-runs.

### Re-reviews are not new lettered groups

When a review needs to re-run after a fix pass, the re-run is a logical instruction ("re-run Group C against the corrected tests"), not a new lettered group in the plan. The same role (or a fresh cold copy with the same role and same prompt) re-executes Group C. The group letter does not change.

Do not invent notation like `C'`, `C2`, `C+`, or `C-retry` for re-runs. Re-runs are dynamic execution events tracked in memory or session state; the plan's letter assignments are stable.

A sequence of re-runs that introduces re-numbering compounds: each re-review of an upstream group cascades into renumbering of every downstream group, defeating the addressability the lettering provides.

The exception is when fix-application or verification is genuinely a new step in the workflow, not a re-run of an existing group. New steps get new letters per the sync-barrier rule below.

### Sync barriers always start a new group letter

A sync barrier in the dispatch plan — the rule that all prior rows must complete before any subsequent row dispatches — always starts a new group letter. No exceptions for preserving a "familiar" letter or grouping "conceptually similar" work under the same letter.

The letter is a positional index tied to when the work runs in the workflow, not a stable identity for a workstream. When a new sync-separated phase is inserted (for example, a scaffolding smoke test between test validation and debug), downstream letters shift to accommodate it.

Two stages that conceptually feel related — logic review and security review, for instance — but are separated by a sync barrier are different groups with different letters. The sync barrier is the absolute discriminator; conceptual similarity is not grounds to combine groups.

### Fix-application is its own group

In a project-defined multi-review-type workflow, cross-stage fix-application is a group, not lead-inline work. A Sonnet agent runs under lead direction (the lead consolidates findings; the agent applies them); the lead does not edit by hand. This rule governs the project lead's outer workflow — fix-application that spans findings from multiple review types (style + logic + security + tests) needs its own dispatched group with a letter, addressable for re-runs and partial application.

This is both a correctness rule and an addressability rule. Lead time is the scarce resource in a multi-review-type workflow, and cross-stage fix-application is well-defined enough for Sonnet to execute. Giving the step a group letter makes it referenceable: "re-run I1 on the remaining H findings" is specific; "re-run the fix-application after logic" is not.

The same applies to verification runs (`make test` invocations, build steps, smoke tests). They are Sonnet-dispatched, letter-addressable, and not lead-inline actions.

The exception is when a single mechanical edit is so trivially scoped that dispatching a Sonnet agent is more overhead than the edit itself. In that case the lead may apply the edit directly, but it does not appear as a row in the dispatch plan — it is a one-off action between dispatched groups, not part of the workflow structure.

Note that this rule does not modify how fix-application works *inside* the style-review framework. When `/format-code` runs (whether as a standalone user invocation or as one stage of a project's multi-review-type workflow), the style-review framework's own fix-application rule — the lead applies style fixes directly — still governs that stage. This file's "Fix-application is its own group" rule applies one level up, to cross-stage fix-application across multiple review types' findings.
