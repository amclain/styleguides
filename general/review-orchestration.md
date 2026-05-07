# Style Review Orchestration Framework

This document defines the orchestration framework for multi-agent style reviews and the concrete instantiations for each supported language. It is the single source of truth for how reviews are decomposed, which models are assigned to which tasks, and what checks run in what order.

A lead agent reads this document, identifies the target language, and produces a concrete task plan from the framework section plus the target language's instantiation section. Task agents execute the plan. The lead collects results and produces a final report.

This framework applies to both review mode (suggestions presented to the user) and fix mode (autonomous corrections). See `skills/format-code/SKILL.md` and `skills/format-review/SKILL.md` for the user-facing entry points.

## Integrating this framework from a larger orchestration

When a larger workflow (project dev plan, CI pipeline, code-generation skill, release process) needs to include style review as a step, the lead agent of that larger workflow **assumes the review-lead role directly** when it reaches the review step. It does not spawn a separate agent to act as review lead. This is not a preference - Claude Code's agent model forbids the alternative: subagents cannot launch their own subagents (see `general/agents.md` § Roles § Lead), and the reviewer subagents at Tasks 1.1 through 1.6 must be launched by the agent that *is* the lead. A "cold review lead" as a subagent cannot orchestrate the subagents it would need.

This is safe because the cold-review principle (`general/agents.md` § Warm vs Cold Agents § Bias Risk) targets generator bias: an agent that wrote the code should not review it. A project lead that delegated code generation to a subagent has no generator bias - it did not author the code. The bias check lives at the reviewer-subagent layer (Tasks 1.1 through 1.6), which the framework already runs cold by design: each reviewer subagent starts fresh, loads only its required reading, and has no project context.

**Agent-callable entry point:** `skills/format-code` - autonomous fix mode. The project lead loads the skill, reads this framework, instantiates it for the current scope, launches the read-only reviewer subagents, collects findings, and applies fixes. The skill is instructions the project lead follows itself - not a handoff to a separate agent.

**Direct-user-invocation entry points** (an agent invokes them on the user's behalf in response to a direct user request, but a larger orchestration must NOT chain them as a programmatic step):
- `format-review` - interactive suggestion mode; requires a human in the loop for accept or reject decisions.
- `format-rewrite` - rewrites the codebase to match the guide, disregarding codebase precedence. High blast radius; the `--rewrite` modifier is reserved for deliberate user invocation on fresh scaffolds.

**Do NOT, from inside a larger orchestration:**
- Decompose style review into Tasks 1.1 through 1.6 in the larger plan's own documents (this framework is the source of truth).
- Pick models for style-review subtasks (the framework assigns them).
- Copy mechanical check commands or task templates into the larger plan.
- Restate the task breakdown in project CLAUDE.md.
- Spawn a subagent and ask it to "lead" the review - the architecture does not support nested orchestration, and the subagent cannot launch the reviewers it would need.

Project-specific overlays (fix-applicator rules, codebase-precedence exceptions, external-API vocabulary the project integrates with) live in project CLAUDE.md and are read by the framework when invoked. They do not belong in the larger orchestration's own documents.

When a project composes style review with other review types (test validation, logic review, security review, etc.) into a coordinated multi-review-type workflow, the project's own orchestration layer handles dispatch plan format, group identity, re-review semantics, and cross-review-type fix-application — see `general/review-pipeline.md` for that project-side doctrine. This framework continues to govern style review itself regardless of whether other review types run alongside.

The reviewer subagents at Tasks 1.1 through 1.6 inherit the **Shared Reviewer Direction** below (find siblings on pattern-class findings, recording rules, anti-boilerplate clause). Dispatch prompts for Tasks 1.3 (identifier scan) and 1.5 (code style) in particular benefit from the rule: one identifier flagged for a prohibited abbreviation almost always has siblings in the same codebase, and one code-style finding for a rule almost always has other sites of the same construct that violate the same rule.

The style-review lead also runs the **Lead-Side Companion** rule (sibling scan on reviewer findings). For every Task 1.x finding before accepting it: name the invariant, classify codebase-wide vs local, scan or trust the reviewer based on scope-of-scan evidence in the reviewer's report. The classification step's output is recorded with the finding when it goes to the user. This is defense in depth: Tasks 1.3 and 1.5 reviewers run cold and may scope-restrict their scan to the diff or pattern-match on syntactic shape, missing siblings the lead can surface from a wider read.

## Contents

1. Framework (language-agnostic) - task types, dependency graph, orchestration, error handling, quality signals. Applies to every language.
2. Language instantiations - concrete checks, templates, and rule catalogs for each language that has been instantiated. The Part 1 framework applies to languages not yet listed here; the language instantiation supplies leaf data (mechanical grep patterns, prohibited abbreviations, file ordering templates, documentation format) that Part 1 references via placeholders.
   - 2.1 C

**When a language has no Part 2 instantiation,** the lead still runs Tasks 1.2 through 1.6 using the language's `<lang>/CLAUDE.md` as the rule source. Task 1.1 (Mechanical Checks) has no pre-written grep patterns to run - skip it and record the gap; the Code Style Pass (1.5) catches the same violations with lower efficiency. Do not invent mechanical checks ad hoc in a single review - if a pattern is worth checking mechanically, add it to the language instantiation section in a separate change.

**Line length** is the one check every language needs even without a Part 2 section. Run it post-edit (see Check phases). Pattern:

```bash
awk 'length > LIMIT { print FILENAME":"NR": "length" chars" }' <file> [<file> ...]
```

Substitute the language's limit. Multi-file awk runs produce a cumulative `NR`, not per-file line numbers - inspect one file at a time if the line number must match the file. This command is covered by the project's `Bash(awk:*)` allowlist; a project that scopes its allowlist tighter must include this pattern.

---

# Part 1: Framework

## Prerequisites

Before instantiation, the lead agent must have:
- A list of files to review and, for default (non-`--all`) reviews, the set of changed line ranges per file (see Review Scope below)
- The full text of the required reading (see below) loaded
- Project-level context from first-run checks or memory: indentation convention, build system, test framework, any codebase conventions that override defaults

## Required Reading

The general rule for loading the style guide - read in full, no skimming, no training-data reliance - is defined in `general/CLAUDE.md`'s "Reading This Guide" section and applies to every agent role. This section specifies *which* files a review task requires.

Both the lead agent and every task agent it launches must perform the required reading before any other work. Task agents do not receive excerpts from the lead - they read the files themselves. Excerpts introduce failure modes the full read avoids: the lead might omit a rule it considers irrelevant that turns out to matter, or excerpts may lose cross-references that make rules interpretable (an excerpt of a brace rule may omit the exception in a different section). A full read is less fragile than a curated excerpt, and the cost is small compared to the code being reviewed.

**Required files depend on what is in scope for the review:**

| Scope condition | Files to read |
|---|---|
| Always | `general/CLAUDE.md` (which `@` imports `general/collaboration.md`), this framework document |
| Reviewing `<lang>` code | `<lang>/CLAUDE.md` |
| Reviewing test files (any language) | `general/testing.md` |
| Reviewing test files for `<lang>` | `<lang>/testing.md` (load on demand; not propagated to subagents via `@` import, so list its path in the dispatch prompt for any task whose scope includes test files) |
| Reviewing code that uses a framework with a mechanics reference (e.g. Unity, ESpec, a DI library) | The mechanics reference file for that framework |

**What NOT to read pre-emptively:**
- Files for languages not in scope
- Mechanics references for frameworks not used by the files being reviewed
- Historical documents (ingested reports, training notes)

The lead agent loads the required files before Step 1 of instantiation (Determine Scope). Each task template includes a Required Reading block populated by the lead in Step 5, so task agents load the same files independently.

**Detection** of agents that skipped the reading is covered by the negative quality signals in Section 5 and by the general rule in `general/CLAUDE.md`.

## Review Scope: Changed Lines vs. Entire File

A default style review targets the lines that were added or modified, not the entire content of the files that contain them. A file with a one-line change gets a one-line review, not a full-file reformat.

**Default scope (non-`--all`):** changed lines only.
- Collect the diff: `git diff` and `git diff --staged` produce both the affected files and the line ranges within each file.
- Agents read the **full file** for context (rules like naming consistency, structural ordering, and cross-reference checks require surrounding code) but report findings **only on lines within the diff**.
- Pre-existing violations in unchanged code are not flagged. That code is the responsibility of whoever originally wrote it, and reformatting it creates diff noise that obscures the actual change.

**`--all` scope:** entire file content for every file in the set.

This distinction must propagate through every task. The lead builds a scope object per file (`{file, changed_lines: [(start, end), ...]}`) and each task template receives it. Task agents use the changed line set to filter their findings before returning.

**Structural Pass is a special case.** Declaration ordering is a file-level property, not a line-level property. A structural finding should fire only when a changed line **introduces** a structural violation - for example, adding a new function in the wrong section. Modifying a function body does not trigger a structural finding even though the function's position relative to other declarations is unchanged. The Structural Pass task instructions explicitly handle this.

### Group Cohesion Exception

The diff-scoping rule has a judgment-based exception: when a changed line is part of a **group of related code**, the agent evaluates the group as a whole, not just the changed line. This may require touching unchanged lines in the group to keep the group visually cohesive.

This exception exists because visual consistency within groups is a readability principle (see "Consistent Formatting Within Groups" in `general/CLAUDE.md`). A change that creates a mismatch inside a group degrades readability of code the author did not touch, even though none of the guide's line-level rules are violated.

**What counts as a group** (examples, not exhaustive):
- Multiple clauses of the same function
- Multiple branches of the same `case`/`switch`/`cond`
- Fields of a struct or record
- Steps of a pipeline
- A sequence of test setup calls (`allow`/`accept`, mock configuration)
- A sequence of similarly-structured configuration entries

**How to apply the exception:**

When the change is inside a group, the agent has two directions to choose from:

1. **Match the existing group style.** If the group has an established format and the change is a small addition, reformat the change to match. This is the default when the existing style is clear and the change is minor.

2. **Reformat the group to be cohesive with the change.** If the change's natural form differs from the existing group style (e.g. a new clause has multiple statements and needs block form, while the existing one-liners use shorthand), reformat the existing clauses to match the new one. This is appropriate when the new form is more natural for the content and the group is small enough that reformatting is minimal.

**Example (illustrative, not a literal language rule):**

A new one-line function clause is added to a group that uses `do/end` block form:

```
# existing (unchanged before the edit)
def foo(list) do
  foo(list, [])
end

def foo([head | rest], acc) do
  foo(rest, [acc | head])
end

# change: add the base case
def foo([], acc), do: acc
```

The new clause uses `do:` shorthand, but the existing clauses use `do/end`. The group is now inconsistent. The agent has two choices:

```
# option A: match the existing group style
def foo(list) do
  foo(list, [])
end

def foo([], acc) do
  acc
end

def foo([head | rest], acc) do
  foo(rest, [acc | head])
end
```

```
# option B: reformat the group to shorthand (only if shorthand is appropriate for all clauses)
def foo(list), do: foo(list, [])
def foo([], acc), do: acc
def foo([head | rest], acc), do: foo(rest, [acc | head])
```

Option B is not appropriate here because the recursive clause has multiple expressions, so option A is the right choice. The agent touches the unchanged `def foo([], acc), do: acc` and rewrites it as a `do/end` block for cohesion.

**When NOT to apply the exception:**

- The unchanged code is not part of a group with the changed line - it is merely adjacent.
- The group is large and reformatting would produce substantial diff noise unrelated to the actual change.
- The existing group already has inconsistencies that pre-date the change (the change should not be used as an excuse to clean up pre-existing inconsistencies).
- The user explicitly requested minimal diff.

**Who makes this call:** the Code Style Pass (Task 1.5). This is judgment work that requires holding the group's structure and format in context simultaneously - exactly what Opus is for. Task templates for 1.5 must explicitly allow this exception; the other tasks (mechanical checks, identifier scan, comment quality) do not touch group cohesion and stick to strict diff scoping.

---

## 1. Task Types

### The task breakdown is load-bearing - do not combine task types

Each of the six task types below is scoped around a single cognitive concern. The decomposition is designed around attention capacity (see `general/agents.md`), not around which tasks look similar or which models are available. Combining task types puts multiple concerns on one agent: Haiku drops concerns under multi-concern load, Sonnet degrades silently, Opus degrades vocally but still degrades.

The lead does not optimize the recommended plan by merging agents to reduce overhead. If the plan calls for six agents, launch six agents. The overhead of additional agents is negligible compared to the cost of degraded output from overloaded agents.

Decomposition **within** a task type is allowed (splitting the Code Style Pass across file groups when reviews are large). Decomposition **across** task types is not.

Model assignment per task type is also load-bearing. Do not reassign a task to a different model to save cost or reduce overhead. Each assignment reflects the attention profile required by the task.

### Check phases (pre-edit vs post-edit)

Mechanical checks have a phase:
- **Pre-edit checks** run at the start of the review and find violations in the code as it currently exists.
- **Post-edit checks** run after the lead has applied fixes and verify the post-edit state. Running them before edits wastes effort on text that will change.

**Line length is always a post-edit check in every language.** A line's length depends on what is on it, and edits change the content - renames, refactors, and reflow all affect line length. The lead cannot verify its own edits against line length until the edits are made. This rule applies regardless of language.

Other checks may be pre-edit or post-edit depending on the language - the per-language instantiation marks each check with its phase.

In review mode (no edits applied), only pre-edit checks run. In fix mode, pre-edit checks run at the start and post-edit checks run after the lead applies fixes.

---

### 1.1 Mechanical Checks

**Purpose**: Run regex/pattern-based matching to find candidate violations that are hard to spot by reading code. Results are inputs to the Mechanical Check Review task (1.6) - not findings on their own.

**Model**: Single-concern task, no judgment required. Command execution and output collection. Haiku or Sonnet, with the caveat below.

**Haiku caveat under tool-availability uncertainty.** Haiku's narrowing-under-pressure failure mode (see `general/agents.md` - Attention Fatigue) manifests on Bash-heavy mechanical-check tasks as substituting model-internal output for actual tool execution. When a Bash call is denied or unavailable, Haiku tends to skip the call and synthesize a plausible result from the input file's content rather than stop and report. Sonnet under the same conditions runs the procedure and surfaces the denial cleanly. Prefer Sonnet for Task 1.1 in environments where the first-run permission check has not been completed, or where the project's permissions may have changed since first run. After the first-run check has verified allowlist coverage for the language's mechanical-check commands (see `general/first-run.md` § Mechanical Check Permissions), Haiku is acceptable.

**Execution context**: Mechanical checks are always delegated to a Haiku/Sonnet subagent. The lead does not run them in its own context. This applies whether the dispatch is the first run, a retry after permission setup, or a post-edit re-run. Subagent dispatch depends on `.claude/settings.json` (or `.claude/settings.local.json`) allowlist coverage — see `general/agents.md` "Bash Permission Allowlist Inheritance." A subagent inherits allowlist patterns but cannot service a fresh permission decision; an unmatched Bash call is denied non-interactively and the dispatch aborts that check.

**Permission allowlist matching is leading-word-only.** The allowlist pattern `Bash(perl:*)` covers a direct `perl ...` invocation but does NOT cover `echo "label"; perl ...`, `file=path && perl ...`, `for f in files; do perl ...; done`, `bash -c 'perl ...'`, or any other shell construct that bundles or wraps the underlying tool. The leading token of the Bash command is what the allowlist matches; wrapping the prescribed check command with shell scaffolding (variable assignments, `echo` section labels, `;`/`&&`/`||` chaining, pipelines, `bash -c` wrappers) changes the leading word to whatever the wrapper starts with, and the wrapper's leading word is almost never on the allowlist. The resulting denial reports the prescribed tool (perl, grep, awk) as denied, but the actual cause is the wrapper. Subagents whose default reflex is to script-ify a list of commands for convenience produce this failure mode silently — the framework's prescribed checks are written as standalone commands precisely so they invoke with the underlying tool as the leading word. The instruction template below names this rule explicitly so the subagent does not wrap the commands.

If the subagent reports an aborted dispatch (`tooling_log.status == "aborted_at_check"`), the lead does NOT recover by running the mechanical checks in its own context. The check commands are prescribed by the language instantiation (§ 2.x.1); they are styleguide-owned text, not lead-discretionary. The allowlist is project-setup territory; updating it is the user's action, not the lead's. The lead's only recovery action on an aborted Task 1.1 is to halt the workflow and notify the user — see § 4 Error Handling for the protocol.

Sections 1.2 through 1.5 use Read/Grep/Glob, not Bash, and are unaffected by Bash allowlist coverage.

**Decomposition**: Run all pre-edit checks as one task per file set at the start of review. Run post-edit checks as a second invocation after the lead applies fixes. Do not split the checks further - they are independent commands that complete in seconds and splitting creates coordination overhead.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Run the mechanical checks for {LANGUAGE} on each file in {SCOPE}. Report raw results only - do not interpret them. Each result line must include the file path, line number, and the name of the check that matched.

Phase: {PHASE}  (pre-edit or post-edit)

Checks to run: {CHECKS_FOR_PHASE}

Scope filtering: {SCOPE} contains a file list with changed line ranges. Run the checks against the entire file (many checks are file-scoped by nature), then filter results to include only matches on lines within the changed ranges. If {SCOPE} is "all", report all matches without filtering.

Output format - one JSON object with `tooling_log` and `matches` fields:
{
  "tooling_log": {"status": "ran"} | {"status": "aborted_at_check", "check": "check_name", "command": "verbatim command that failed", "error": "verbatim error message"},
  "matches": [
    {"file": "path", "line": N, "check": "check_name", "match": "matched text"}
  ]
}

If a check produces no matches (or no matches within scope), omit the file from `matches`. `matches: []` with `tooling_log.status == "ran"` is the positive assertion that every check executed and found nothing; `matches: []` with `tooling_log.status == "aborted_at_check"` is the assertion that execution stopped before all checks ran and findings coverage is unknown. The two are not equivalent and the lead reads them differently.

Invocation shape: each check runs as its own standalone Bash call. The leading word of the Bash command must be the underlying tool (`perl`, `grep`, `awk`, or whichever tool the prescribed check uses) — invoked directly, with the file path inlined. Do NOT bundle multiple checks into one Bash call with `;`, `&&`, or `||` separators. Do NOT precede the check with a `file=...` variable assignment, an `echo "=== Check N ==="` label, or any other setup statement. Do NOT wrap the check in `bash -c '...'`, `for f in ...; do ...; done`, a pipeline, or a command substitution. The permission allowlist matches the leading word of the Bash command; a wrapped or chained invocation has the wrapper's leading word (`echo`, `for`, `bash`, or a variable assignment), which is almost never allowlisted, and the resulting denial misreports the prescribed tool as denied. Issuing each check as a standalone direct invocation is what keeps the allowlist matching correct.

Failure handling: If any Bash command returns a permission denial, an unrecognized-command error, or any error indicating the tool is unavailable, STOP. Set `tooling_log` to `{"status": "aborted_at_check", "check": <check_name>, "command": <verbatim>, "error": <verbatim>}` and return whatever matches you had successfully recorded before the failure (or `matches: []` if you had not produced any). Do not invoke a permissions-fix or recovery skill. Do not retry the call in a different shell-level form (no `bash -c` wrappers, no piping through another tool, no absolute-path substitution). Do not skip the failed check and continue. Do not infer the result by reading the input file directly or by pattern-matching against earlier successful checks. Wait for the lead's direction.
```

**Common false positives**: see the language instantiation's check definitions. Each check lists its known false positive patterns.

---

### 1.2 Structural Pass

**Purpose**: Verify file-level declaration ordering and section organization. Does the file follow the prescribed section sequence for its type?

**Model**: Pattern matching against a known ordering template. Sonnet or Haiku (single file template at a time).

**Decomposition**: One file per task unit. Cannot be further decomposed.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Read each file in {SCOPE} and verify its declaration ordering against the correct template for its file type. Templates are defined in the {LANGUAGE} instantiation of this framework.

Ordering rules: {ORDERING_RULES}

Scope filtering: {SCOPE} contains a file list with changed line ranges. Declaration ordering is a file-level property - structural findings fire only when a changed line INTRODUCES a structural violation. A new declaration added in the wrong section is a finding. A modification to the body of an existing function is NOT a structural finding even if the function's position relative to other declarations is unchanged. In `--all` scope, report all ordering violations without filtering.

For each file, report:
- Whether ordering is correct or which sections are out of order (only for changes introduced by the diff, unless scope is "all")
- Whether grouped sections (e.g. includes/imports) are properly grouped and separated
- Whether any declarations were added in the wrong section

Output format:
[
  {
    "file": "path",
    "status": "ok" | "violation",
    "findings": [
      {"line": N, "issue": "description", "rule": "rule name"}
    ]
  }
]
```

**Common false positives**: dependencies that require out-of-order declaration (the language guide's "When to deviate" clauses), framework-required first-header conventions, flagging pre-existing ordering violations in a file whose diff only modified function bodies.

---

### 1.3 Identifier Scan

**Purpose**: Apply the detokenize technique from `general/CLAUDE.md`'s Precision Over Length rule to every non-trivial identifier in changed code. Split identifiers into words and read as English phrases to catch abbreviations and grammar problems invisible when reading identifiers as code tokens.

**Model**: Systematic, rule-based decomposition. Single-concern. Haiku works well when given the detokenize procedure and the language's prohibited abbreviation list.

**Decomposition**: Can be decomposed per-file for large reviews.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

For each file in {SCOPE}, examine all non-trivial identifiers. Read the full source file for context (understand what surrounding types and scopes provide), but only report findings on identifiers defined or modified within the changed line ranges. In `--all` scope, examine all identifiers in the file.

Scope is DEFINITIONS, not references. Review names the project authors: variable declarations, function definitions, type definitions, constant definitions. Do NOT flag identifiers that are merely referenced from external libraries, frameworks, or the standard library - those names are authored outside the project and are not subject to style review. A call to an external function keeps its original name; only flag the project-owned identifier that wraps or uses it.

Technique - detokenize each identifier:
1. If the language uses namespace prefixes, strip the prefix first
2. Split according to the language's convention (snake_case, camelCase, PascalCase, kebab-case)
3. Read the resulting phrase as English
4. Check for:
   a. Abbreviations from the prohibited list: {PROHIBITED_ABBREVIATIONS}
   b. Grammar problems: bare noun phrases where a verb is expected, imperatives where propositions are expected
   c. Redundant context: identifier repeats information already visible from its surrounding type or scope

Accepted short forms (never flag): {ACCEPTED_SHORT_FORMS}
Skip: loop counters, single-letter variables in narrow scopes, standard library names.

For each finding, provide:
- The identifier as written
- The detokenized phrase
- What is wrong (abbreviation, grammar, redundancy)
- Suggested replacement

**Report only violations.** Each entry describes one violation - a specific identifier that breaks a specific rule from the loaded guides. The output is not a place to record your reasoning, your inspections, or your decisions about what is correct. An entry whose content is your reasoning about whether a rule applies must not exist. An entry that says the identifier is acceptable, correct, fine, or does not need a change must not exist. Omission is how you report that an identifier is correct.

Output format:
[
  {
    "file": "path",
    "line": N,
    "identifier": "original_name",
    "detokenized": "phrase as English",
    "issue": "abbreviation | grammar | redundancy",
    "suggestion": "better_name"
  }
]

**Before submitting, re-read each entry.** Delete any entry whose `issue` describes a correct identifier, whose `suggestion` says no change is needed, or whose content is your reasoning rather than a fix. The output you submit contains only violations.
```

**Test name grammar is part of this pass.** Evaluating test name grammar is a multi-concern task (recognizing propositions, distinguishing verb-leading from noun-leading names, applying implicit subject from file name). When reviewing test files specifically, run the Identifier Scan for test names with **Opus** instead of Haiku. Opus has the judgment to accept valid constructions that Haiku over-flags. This reassignment is an exception to the default Haiku assignment for this pass and applies only to test files.

**Common false positives**: flagging external function calls or type references (scope is project-authored definitions only - external references are never in scope), names that incorporate external-API vocabulary where the external API itself uses that term (see the Domain Term rule in the language guide), short field names that are precise within their struct context, local variables in narrow scopes, test names with implicit subjects from the file name.

---

### 1.4 Comment Quality Pass

**Purpose**: Review comments for redundancy, misplaced information, over-specification, and violations of the Write Self-Documenting Code principle from `general/CLAUDE.md`.

**Model**: **Opus is required.** Comment quality is not decomposable into single-concern subtasks. Per-comment decisions depend on cross-comment context: whether a `///<` is redundant depends on what the set-level `@brief` already carries; whether a docstring sentence is over-specified depends on what the `@param`/`@return` blocks already carry; whether a bare member is missing a comment depends on whether other members in the group independently warrant one and what the unique-information test produces. The reviewer must hold the file's comment landscape, set-level prose, function-level prose, and the surrounding identifier context simultaneously to judge any single comment. This rules out single-concern Haiku decomposition and exceeds Sonnet's comfortable concern count given the rule interactions (redundancy ↔ set-level coverage ↔ mixed-presence-is-correct ↔ over-specification ↔ mechanism-vs-contract). Sonnet under this load drops categories silently; Haiku narrows away most of the rule set.

**Decomposition**: Can be decomposed per-file for large reviews. Cannot be decomposed per-category — the categories interact and a per-comment decision requires evaluating the comment against multiple categories at once.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Read each source file in {SCOPE}. Read the full file for context, including all comments and the file `@brief`, type `@brief` blocks, and function `@param`/`@return` blocks the targeted comments depend on. Review comments on lines within the changed line ranges - do not flag comments in unchanged code. In `--all` scope, review every comment. Flag comments that match any of these categories:

1. Redundant comments that restate what the code expresses, or that paraphrase content already carried by the set-level `@brief`, the function-level `@param`/`@return`, or the identifier itself.
2. Comment-as-constant: comments explaining a literal value that should be a named constant. When flagging these, the fix is to change the representation first, THEN remove the comment. Do not suggest removing the comment without fixing the representation.
3. What-not-why comments: describing what the code does rather than why.
4. Section divider comments: decorative comments marking code regions (always a violation).
5. Missing required documentation on public APIs per the language guide.
6. Documentation format issues per the language guide.
7. Misplaced documentation (e.g. on the wrong definition site per language convention).
8. Misaligned trailing documentation where alignment is required.
9. Over-specification: docstring body sentences that describe library mechanism (internal procedure, internal state-field names, library-side actions the caller cannot observe), restate `@param`/`@return`, describe cross-caller behavior in a single-caller's docstring, or narrate architectural flow. The fix is REMOVAL of the over-specified prose, not expansion. Caller-obligation statements (the *caller's* required actions) are contract, not mechanism, and are NOT over-specification - the mechanism-vs-contract distinction is decided by whose action is being described. See the language guide's docstring-shape rule for the surfaces that apply (e.g. C: § Type `@brief` Body Shape, § Function Docstring Body Shape).

Language-specific documentation rules: {DOC_RULES}

**Report only violations.** Each entry describes one violation - a specific comment that breaks a specific rule from the loaded guides. The output is not a place to record your reasoning, your inspections, or your decisions about what is correct. An entry whose content is your reasoning about whether a rule applies must not exist. An entry that says the comment is acceptable, correct, fine, or does not need a change must not exist. Omission is how you report that a comment is correct.

Output format:
[
  {
    "file": "path",
    "line": N,
    "category": "redundant | comment_as_constant | what_not_why | section_divider | missing_doc | doc_format | misplaced_doc | misaligned_doc | over_specification",
    "comment_text": "the comment",
    "suggestion": "what to do"
  }
]

**Before submitting, re-read each entry.** Delete any entry whose content does not describe a comment violation, whose `suggestion` says no change is needed, or whose content is your reasoning rather than a fix. The output you submit contains only violations.
```

**Common false positives**: required fallthrough markers in switch statements; comments explaining "why" that look like "what" at first glance; caller-obligation statements that describe what the caller must do or not do (contract, not mechanism); body content that carries a contract-level invariant the structured `@param`/`@return` blocks cannot express (cross-argument preconditions, thread-safety contracts, lifecycle protocols).

---

### 1.5 Code Style Pass

**Purpose**: Identify style violations by reading the code holistically. This covers formatting, whitespace, idioms, brace/bracket placement, line breaks, and all line-level rules not caught by the other passes.

**Model**: **Opus is required.** This is the highest-judgment task in the framework. Rules interact (brace placement may depend on line length; whitespace may depend on whether something is a declaration or expression). The reviewer must hold the full rule set in context simultaneously. Sonnet consistently confuses cases that require judgment - this is a measured limitation, not a conservative default.

**Decomposition**: Cannot be decomposed into single-rule subtasks. For very large reviews (>20 files), split into groups of 5-10 files per Opus agent. Each agent gets the full rule set.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Do not rely on prior knowledge of {LANGUAGE} conventions. Apply the rules as they are written in the loaded files. Do not substitute common patterns from other style guides.

You are reviewing {LANGUAGE} code for style violations. After the required reading, review each source file in {SCOPE}.

Read the full source file for context (rules may depend on surrounding code). Report findings on lines within the changed line ranges. Do not flag pre-existing style violations in unchanged code - that code is the responsibility of whoever originally wrote it, and reformatting it creates diff noise. In `--all` scope, review the entire file.

**Codebase precedence (check before flagging).** Before flagging any finding, verify that the codebase's established convention is consistent with the guide. Where the codebase consistently deviates from a guide rule (observed across multiple files or functions, not a one-off), treat the deviation as codebase precedence and do not flag it. This is the "Precedence in the codebase takes priority" meta-rule from `general/CLAUDE.md` applied at review time. This check runs BEFORE rule application, not as a trailing filter on findings.

**Exception - `--rewrite` / `--styleguide-precedence` modifier:** when the review was invoked with `--rewrite` (or its alias `--styleguide-precedence`), skip the codebase-precedence check and apply the guide as written. Typical use: a freshly scaffolded project whose existing patterns should be rewritten to match the guide, not learned from.

**Group cohesion exception:** when a changed line is part of a group of related code (multiple clauses of the same function, branches of the same case/switch, fields of the same struct, steps of the same pipeline, a sequence of similarly-structured setup calls), evaluate the group as a whole. If the change creates an inconsistency within the group, either reformat the change to match the group's existing style or reformat the group to match the change - whichever produces more natural code. This may require touching unchanged lines within the group. Apply this exception conservatively: only for lines that are clearly part of the same group as the change, and only when the inconsistency meaningfully degrades readability. See the Review Scope section for details and examples.

Apply all rules from the language guide and the general guide. For each finding, provide:
- File path and line number
- The rule being violated (by name from the guide)
- What the code does wrong
- What it should look like

Respect codebase-precedence conventions: {CODEBASE_OVERRIDES}

**Coverage requirement.** Report every file in `{SCOPE}` with either a list of findings or an empty findings array. Empty findings is a positive assertion that the file was reviewed and no violations were found, distinct from omitting the file entirely. A file that is omitted from the output has not been reviewed; the lead's coverage check will reject the task as incomplete.

**Rule-coverage requirement.** For each file in `{SCOPE}`, in addition to the findings array, enumerate the rules from the loaded style guides that you evaluated the file against. A rule is "applied" when you scanned the file for violations of that rule, whether or not it produced a finding. The enumeration is a positive assertion that the rule was scanned for; rules omitted from the enumeration were not scanned, and the file's coverage of those rules is unknown. Rules-applied operates on the rule axis the same way file-coverage operates on the file axis: enumeration is how absent coverage becomes visible.

**Construct the rule catalog before reading any source file.** After completing Required Reading and before opening the first file in `{SCOPE}`, build an explicit list of every rule entry defined by a section heading in the loaded language guides (each `###` or `####` rule heading in the language guide and `general/CLAUDE.md`). This list is the catalog. The catalog is what you scan each file against - not a summary you assemble afterward from rules you happened to remember. Holding the catalog in attention before reading code is what makes rule coverage broad enough for the per-file enumeration to be honest; without it, lower-frequency rules silently drop out of the active scan because they were never explicitly held. This is the mechanism that produces recovery on busy files where finding density would otherwise narrow the scan to a few high-volume rules.

Cite rules by their heading text exactly as written in the guide. A rule that is structurally inapplicable to the file (a header-only rule when reviewing a non-header file, a docstring-shape rule when the file has no documented declarations) is omitted from the enumeration; the lead's coverage check will accept structurally-inapplicable omissions when they are consistent across files of that kind.

The per-file enumeration is a self-report against the catalog after scanning. Its honesty matters: if you cannot honestly say a rule from the catalog was scanned for in a given file, omit it from that file's `rules_applied`. Padding the list with rules you did not actually scan for defeats the purpose - the lead's gap check compares the union of `rules_applied` across files against the catalog and acts on apparent gaps, so a falsely-asserted rule hides a real gap from the check. Omission of rules you did not scan for is what makes the signal usable; the lead can request a follow-up pass on the gaps the union reveals.

**Report only violations.** Each entry in a file's `findings` array describes one violation - a specific line of code that breaks a specific rule from the loaded guides. The `findings` array is not a place to record your reasoning, your inspections, or your decisions about what is correct. An entry whose content is your reasoning about whether a rule applies must not exist. An entry that mixes a non-violation note with a real violation must not exist - the real violation is a separate entry on its own line, and the non-violation note is omitted. An entry that says the code is acceptable, correct, fine, or does not need a fix must not exist. Omission is how you report that a line is correct: the absence of an entry for a line is the positive non-violation assertion at the line level; the empty findings array is the positive non-violation assertion at the file level. Both are coverage signals; neither is satisfied by padding the output with entries that describe correct code.

Output format - per-file structure, one entry per file in scope:
[
  {
    "file": "path",
    "rules_applied": ["Rule Name 1", "Rule Name 2", ...],
    "findings": [
      {
        "line": N,
        "rule": "Rule Name",
        "issue": "description of violation",
        "fix": "what correct code looks like"
      }
    ]
  }
]

A file with no violations appears as `{"file": "path", "rules_applied": [...], "findings": []}`. Every file in `{SCOPE}` must appear in the output. The `rules_applied` array is required for every file regardless of whether findings is empty - empty findings with a populated rules_applied is the positive assertion that the file was scanned for those rules and no violations were found.

**Before submitting, re-read each entry.** For every entry in every file's `findings` array: confirm the `issue` field describes a violation of a specific rule, and the `fix` field shows what the corrected code looks like. Delete any entry whose `issue` describes correct code, whose `fix` says no change is needed, or whose content is your reasoning rather than a fix. The output you submit contains only violations; entries that describe inspections, considerations, or non-violations are removed in this pre-submit pass.
```

**Common false positives**: cases covered by the codebase's established conventions (precedence in the codebase rule - check BEFORE flagging, not after), rules that do not apply to the specific context. Flagging a pattern the codebase consistently uses (e.g. `if (cond) { single_statement; }` when the codebase always braces single-statement bodies) is a failure to apply codebase precedence - not a true finding.

---

### 1.6 Mechanical Check Review

**Purpose**: Take raw mechanical check results from task 1.1 and evaluate each match against the style rules. Determine which matches are true violations and which are false positives.

**Model**: The decision rules for each check are documented per-language. Pattern-matching against known criteria. Sonnet or Haiku.

**Decomposition**: Single task - takes all mechanical check results as input.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

You have raw mechanical check results from the style review. Evaluate each match against the style rules and classify it as a true violation or a false positive.

Raw results:
{MECHANICAL_CHECK_RESULTS}

Classification rules for each check are defined in the {LANGUAGE} instantiation: {CLASSIFICATION_RULES}

For each classified result, output:
[
  {
    "file": "path",
    "line": N,
    "check": "check_name",
    "classification": "violation" | "false_positive",
    "reason": "why this classification",
    "rule": "name of violated rule (if violation)"
  }
]
```

---

## Engagement Is Unconditional; Effort Is Not a Valid Filter

When the lead receives an enumerated output from a dispatched reviewer — Task 1.1 mechanical-check results, Task 1.2 structural-pass findings, Task 1.3 identifier-scan findings, Task 1.4 comment-quality findings, Task 1.5 code-style findings, Task 1.6 mechanical-check review, or any list — every item gets engaged. Items may be grouped when genuinely related (same root cause, same rule, same fix shape) and engaged as a group. The banned move is bucketing-as-skipping: pre-classifying a category, file region, or item type as not needing engagement.

Every item, individually or as a named group, must receive one of these dispositions:

- **apply** — the finding is a real violation under the rule; perform the fix.
- **reject-with-rule-grounded-reason** — the finding does not represent a violation under the cited rule, or codebase precedence overrides the rule; state the reason in rule terms.
- **escalate-to-user** — applying the finding requires a decision only the user can make (project-level naming choice, intentional deviation, scope outside the lead's authority).
- **defer-with-rule-grounded-reason** — applying the finding now is blocked on something specific; state what unblocks it.

Effort considerations — cosmetic, tedious, lengthy, repetitive, many sites — are not valid grounds for dropping an item. "Too cosmetic," "too many sites," "low value" are not valid reasons in any disposition. The lead's authority is over rule-application questions (does this item represent a real violation, is the rule the right rule, does codebase precedence change the disposition); it is not over whether a real violation is "worth fixing."

---

## Shared Reviewer Direction

Direction that applies to every reviewer role — the per-task reviewers at Tasks 1.1 through 1.6 defined in this framework, and the same shape of cold reviewer in any other review type a project may run (logic review, security review, test validation, documentation review). The lead inherits these in dispatch prompts; the reviewer applies them before finalizing its report.

### Find Siblings on Pattern-Class Findings

A cold reviewer's default frame is per-finding: "does this one thing match the spec?" The frame catches the immediate violation and misses the *class* — the four sibling sites where the same invariant is violated by code of the same shape. The lead applies the one fix, re-dispatches, the next pass flags another single instance. A class of defect drips across many re-review cycles when a single pass could have caught it whole.

The rule is a mandatory post-finding step, not a phrasing gate. For every finding, before finalizing, the reviewer:

1. **Decides whether the finding is codebase-wide or local.** A codebase-wide finding turns on a property the codebase expresses in more than one place (or could plausibly express elsewhere): API conventions, structural rules, identifier rules, data-flow rules. A local finding describes one specific site and does not generalize: an off-by-one for this loop's `N=0`, a typo in this docstring, a magic number that appears once. Local-property findings are out of scope for sibling search; the reviewer records the classification and proceeds without naming an invariant (a fabricated invariant name on a local property is the failure mode this rule guards against — see the Anti-Boilerplate Clause).
2. **For codebase-wide findings, names the design invariant or property the finding turns on.** Examples: "the design forbids consumer-side checks for conditions a correct build cannot produce"; "all init functions return `void` after the API contraction"; "no abbreviation from the prohibited list appears in identifiers"; "every untrusted input crossing this trust boundary is validated before use." The named invariant is recorded in the finding.
3. **Scans the surface where the invariant lives for other code that violates the same invariant.** Each sibling found is recorded with the same invariant name.

The phrasing of the original finding ("X happens when Y" vs "this header check is dead defense for X") does not gate the rule. The cognitive failure being prevented is the reviewer never *reformulating* — staying in the surface phrasing of one site instead of asking what property the site violates. Forcing the invariant name as a step makes reformulation explicit.

#### What "Same Shape" Means Per Review Type

The shared definition is "the property the finding turns on, scanned across whichever surface the property lives on." Per-review-type forcing examples (so the reviewer does not default to lexical/structural similarity, which is the cheapest interpretation and exactly where logic-review siblings get missed):

- **Style review Task 1.3 (identifier scan)** — identifier-morphology match. Same abbreviation, same casing pattern, same prohibited token.
- **Style review Task 1.5 (code style)** — same rule applied to the same construct elsewhere. One site flagged for missing whitespace before return implies all sites with the same pattern.
- **Logic review** — invariant violation across call sites or branches. Same defensive pattern, same control-flow shape, same contract violation. Often expressed as the negation of a design invariant ("the design forbids Y, so any consumer-side check for Y is dead"); siblings are other code that contradicts the same invariant.
- **Security review** — data-flow path with the same trust-boundary crossing. Same untrusted input, same validation gap, same sanitization missing.
- **Test validation** — same assertion shape, same fixture setup, same mock contract.
- **Documentation review** — same prose pattern, same outdated reference, same drift between text and code.

Per-task dispatch prompts inherit this section; they do not redefine it.

#### Recording Siblings

The default is to keep findings as separate entries so the lead can triage each independently. The collapse-into-one exception is narrow:

- **Separate findings** — each sibling is its own entry in the report. Use this when any sibling could plausibly receive a different disposition: different fix shape, scope-sensitive carve-out, one site has a load-bearing exception, downstream effects differ. Logic-review siblings almost always need separate findings (each branch's removal has different downstream effects). Security-review siblings almost always need separate findings (each trust-boundary crossing has its own validation context).
- **One finding with N sites listed** — collapse only when accept/reject/defer would be the same across all siblings *by construction*: same rule, same fix shape, no per-site judgment. Identifier-morphology siblings almost always collapse (one rule, one fix shape applied 14 times).

The criterion is whether the lead needs to triage each one independently. If the answer is yes, separate findings; if no, one finding with sites.

#### Anti-Boilerplate Clause

The mandatory step has one specific failure mode: ritualized output. A reviewer that writes "siblings searched: none" on every finding has converted the search into boilerplate. Worse: a reviewer that pads weak siblings into the report (the abbreviation rule fires once on a real violation, four times on borderline cases the reviewer would normally have skipped) buries the load-bearing finding under noise.

Mitigations:

- **Record the invariant name, not the search.** Empty result with a named invariant is signal: the reviewer reformulated, scanned, found nothing. "Siblings searched: none" without an invariant name is the failure mode this rule rules out — it indicates the search was performed but the reformulation was not.
- **Local-property findings are explicitly out of scope.** The rule applies only when the invariant is codebase-wide. The reviewer does not run sibling-search on findings whose invariant does not generalize, and does not record an invariant name as scaffolding for findings that are inherently local.

When the reviewer's output shows invariant names that do not generalize (a "named invariant" that describes one line of code), that is the same failure under a different shape — the reviewer learned to satisfy the form without doing the work. The lead's quality signal is whether the named invariants in a report describe properties of the codebase, not properties of single lines.

---

## Lead-Side Companion: Sibling Scan on Reviewer Findings

The reviewer-side rule does most of the work on most findings. When it fails — reviewer pattern-matches on syntactic shape, scope-restricts the scan to the diff, names a bogus invariant that satisfies the form without doing the work — the class slips through and the lead receives one finding for what should have been five. The lead applies one fix, re-dispatches, the next pass flags another single instance. Defense in depth: the reviewer-side rule catches the class at source; the lead-side rule catches what slipped through.

The rule is a per-finding step the lead runs on every reviewer finding before accepting it and moving on. Trust in the reviewer is conditional on evidence in the reviewer's output, not on the reviewer having returned a finding at all.

For every finding the reviewer returns:

1. **Classify the finding as codebase-wide or local.** Local properties are out of scope: off-by-one for one loop's `N=0`, typo in one docstring, magic number that appears once. The lead accepts the finding and proceeds; the lead's classification overrides the reviewer's, including treating a reviewer-named invariant that describes one line of code as a local finding (the anti-boilerplate failure mode above). Codebase-wide findings continue to step 2.
2. **Name the invariant the finding turns on, or restate the reviewer's named invariant if one is present.** The lead's name takes precedence over the reviewer's. The named invariant is what the scan-or-trust decision in step 3 acts on.
3. **Decide whether to scan or trust the reviewer.** The lead skips the lead-side scan only when the reviewer's output shows **scope-of-scan evidence**: multiple sites reported with same-shape variation (the reviewer found logic-shape variants, identifier-morphology variants, control-flow variants of the same invariant), or an explicit statement of the surface scanned ("scanned all init functions across `src/`," not just "siblings searched: none"). When scope-of-scan evidence is absent or weak — single site reported with a codebase-wide invariant, or "siblings searched: none" without a stated surface — the lead scans the surface where the invariant lives for siblings the reviewer missed.
4. **If the lead surfaces a class, escalate the pattern to the user, not just the single finding.** The fix is likely a restructuring of the affected surface (an enum member deleted, several branches converted to assert, a function signature changed) rather than a point edit on the original finding. State the invariant, the sites the reviewer reported, the additional sites the lead found, and the proposed structural change.

### Why a Per-Finding Step, Not a Type-Gated Step

The original incident that motivated the rule was a "design-gap finding" (defensive code for a condition the spec rules out). The natural specification is "run this step on design-gap findings." That specification fails on non-design-gap classes that share the same failure mode: a prohibited-abbreviation finding where the reviewer scanned only the diff and missed eleven sites in unchanged files; a missing-validation finding where the reviewer matched one syntactic call-site shape and missed four under different shapes. The failure mode is reviewer scope or shape blindness, which is type-independent. The trigger must be type-independent too.

The natural alternative — "run this step only when the reviewer's output looks suspicious" — fails on the cases where the reviewer's output looks fine but the scan was actually scope-restricted. A reviewer that reports "siblings searched: none" with a correctly-named codebase-wide invariant has produced output that looks correct; the failure is invisible to anyone reading the report alone. The lead's classification must be independent of the reviewer's output quality.

The cost is one classification step per finding. The step is bounded — a single sentence naming the invariant, a binary classification, a binary scan-or-trust decision — and produces an audit record (see anti-skip clause below).

### Anti-Skip Clause

The classification step's output is recorded with the finding when it goes to the user. For codebase-wide findings, the record contains the named invariant, the classification, and the scan-or-trust decision with scope-evidence rationale ("trusted: reviewer reported four shape-variant sites across `src/init/`"; "scanned: reviewer reported one site with no scope statement"). For local findings, the record contains the classification only — no fabricated invariant name to satisfy a uniform schema, since fabricating an invariant on a local finding is the failure mode this rule guards against. A finding that reaches the user without the appropriate record is a quality signal that the lead skipped the step.

The record is the rule's audit surface. An overloaded lead skipping the classification step under load — the dominant failure mode — leaves no record, which the user (or a reviewing post-mortem agent) can detect. A lead that performs the step but writes no record has done the work and lost the evidence; the rule treats that as the same failure as skipping. Either case is detectable; either case is correctable on the next pass.

The anti-boilerplate clause from the reviewer-side rule applies symmetrically to the lead: a "named invariant" recorded by the lead that describes one line of code is the same failure mode in lead form. The lead reformulated to satisfy the rule rather than to surface a class, and the resulting "scanned: nothing found" is performative rather than load-bearing. The check is whether the named invariant describes a property of the codebase, not a property of one site.

---

## 2. Dependency Graph

```
                    +-----------------------+
                    | 1.1 Mechanical Checks |
                    |      (pre-edit)       |
                    +-----------+-----------+
                                |
                                v
                  +-----------------------------+
                  | 1.6 Mechanical Check Review |
                  +-----------------------------+
                                |
                                |    (all feed into final report)
                                v
+-------------------+  +------------------+  +---------------------+  +------------------+
| 1.2 Structural    |  | 1.3 Identifier   |  | 1.4 Comment Quality |  | 1.5 Code Style   |
|     Pass          |  |     Scan         |  |     Pass            |  |     Pass (Opus)  |
+-------------------+  +------------------+  +---------------------+  +------------------+
         |                     |                       |                        |
         +---------------------+-----------------------+------------------------+
                                          |
                                          v
                                  +---------------+
                                  | Final Report  |
                                  | (Lead Agent)  |
                                  +---------------+

Fix mode additionally:
   Lead applies fixes → 1.1 (post-edit) → 1.6 → Lead applies verification fixes
```

**Parallel execution**:
- Tasks 1.1 (pre-edit), 1.2, 1.3, 1.4, and 1.5 can all start simultaneously
- Task 1.6 depends on 1.1 completing
- Final report depends on all tasks completing
- In fix mode, after the lead applies fixes, 1.1 (post-edit) and 1.6 run a second time

**Sequencing constraint**: 1.1 must complete before 1.6 can start. All other tasks are independent and run in parallel.

---

## 3. Instantiation Instructions

A lead agent follows these steps to produce a concrete plan from this framework.

These steps are a checklist - sequenced items, binary done-or-not-done, no executor authority over whether each item runs. The lead enacts each step exactly as written and produces the artifact each step specifies. Skipping a step or merging steps based on a judgment that "this isn't necessary here" is forbidden. The framework structure is calibrated against measured failure modes - it is the protection, not boilerplate around the rules.

### Step 1: Determine Scope

Read the review trigger to determine scope:
- `style review <lang>` - **changed lines only** (default). Run `git diff` and `git diff --staged` to collect both the affected files AND the changed line ranges per file. Filter to the language's file extensions. Build a scope object:
  ```
  {
    "mode": "diff",
    "files": [
      {"path": "src/foo.c", "changed_lines": [[10, 15], [42, 42]]},
      {"path": "src/bar.h", "changed_lines": [[3, 20]]}
    ]
  }
  ```
- `style review <lang> --all` - all files for that language in the project. Scope object:
  ```
  {
    "mode": "all",
    "files": [{"path": "src/foo.c"}, {"path": "src/bar.h"}, ...]
  }
  ```
- Explicit file list from user or post-generation context: use `--all` scope for the provided files unless the user specifies line ranges.

Save the scope object as `{SCOPE}`. All task templates receive this object and use it to filter their findings.

### Step 2: Determine Review Size

Count files in `{SCOPE}`:
- **Small** (1-5 files): Full orchestration per the framework. Separate agents per task type regardless of size - the task breakdown is load-bearing (see Section 1).
- **Medium** (6-20 files): Full orchestration. One agent per task type.
- **Large** (>20 files): Full orchestration. Code Style Pass split into groups of 5-10 files each. Other tasks may also be split per-file if the file count justifies it.

### Step 3: Check for Project Context

Verify these are available (from memory or first-run checks):
- Indentation convention
- Whether the codebase has established conventions that override default rules
- Test framework
- Any other language-specific project context the guide requires

If not available, add a first-run detection task before the main review tasks.

### Step 4: Produce Task Manifest

Create a task manifest as a JSON document listing all tasks with their dependencies, assigned model, and instruction content.

```json
{
  "review_scope": "changed | all",
  "language": "c | elixir | ...",
  "file_list": ["path/to/file1", "path/to/file2"],
  "project_context": {
    "indentation": "...",
    "codebase_precedence": ["none | list of codebase conventions that take precedence over default rules"]
  },
  "tasks": [
    {
      "id": "mechanical_checks_pre_edit",
      "type": "1.1",
      "phase": "pre-edit",
      "model": "sonnet | haiku",
      "depends_on": [],
      "files": ["all files from file_list"],
      "instructions": "... (filled from template)"
    },
    {
      "id": "structural_pass",
      "type": "1.2",
      "model": "sonnet | haiku",
      "depends_on": [],
      "files": ["all files from file_list"],
      "instructions": "..."
    },
    {
      "id": "identifier_scan",
      "type": "1.3",
      "model": "haiku (opus for test files)",
      "depends_on": [],
      "files": ["all files from file_list"],
      "instructions": "..."
    },
    {
      "id": "comment_quality",
      "type": "1.4",
      "model": "sonnet | haiku",
      "depends_on": [],
      "files": ["all files from file_list"],
      "instructions": "..."
    },
    {
      "id": "code_style",
      "type": "1.5",
      "model": "opus",
      "depends_on": [],
      "files": ["all files from file_list"],
      "instructions": "..."
    },
    {
      "id": "mechanical_review",
      "type": "1.6",
      "model": "sonnet | haiku",
      "depends_on": ["mechanical_checks_pre_edit"],
      "files": [],
      "instructions": "... (receives output from mechanical_checks)"
    }
  ]
}
```

### Step 5: Fill Instruction Templates

For each task in the manifest:
1. Copy the instructions template from the corresponding task type section in Part 1
2. Replace `{SCOPE}` with the scope object from Step 1 (including per-file changed line ranges)
3. Replace `{LANGUAGE}` with the target language name
4. Replace `{REQUIRED_READING}` with the list of files the task agent must read in full before starting, determined by scope:
   - Always: `general/CLAUDE.md`, this framework document
   - The language guide: `<lang>/CLAUDE.md`
   - If any file in scope is a test file: `general/testing.md` AND `<lang>/testing.md`
   - If any file in scope uses a framework with a mechanics reference (e.g. Unity, ESpec, a DI library): the mechanics reference file
   List files with absolute or repo-relative paths so the task agent can Read them directly.

   **Excluded by default (do not include in `{REQUIRED_READING}`):**
   - Other language guides (`<other-lang>/CLAUDE.md`, `<other-lang>/testing.md`) - rules from unrelated languages pollute context and produce findings that cite the wrong guide.
   - `training.md` - training process documentation, not style rules.
   - `general/agents.md` - agent-model guidance, not style rules. Include only if the task involves model selection.
   - `general/first-run.md` - one-time setup checks, not relevant to review.
   - The styleguides repo root `CLAUDE.md` - repo meta-documentation, not style rules.

   The include list above is exhaustive for normal review tasks. Broadening it ("read the style guide in full") is a common failure mode - reviewers load irrelevant material and spend context on it.
5. Replace other placeholders (`{CHECKS_FOR_PHASE}`, `{PROHIBITED_ABBREVIATIONS}`, `{ORDERING_RULES}`, etc.) with the actual content from the language's instantiation section in Part 2
6. For the Mechanical Check Review task, leave `{MECHANICAL_CHECK_RESULTS}` as a placeholder - it will be filled with the output of the Mechanical Checks task at runtime
7. If project context includes codebase-precedence conventions, append a "Codebase precedence" section to each instruction that notes which default rules are superseded by the codebase's established style

### Step 6: Launch Tasks

1. Launch all tasks with no dependencies in parallel (1.1 pre-edit, 1.2, 1.3, 1.4, 1.5)
2. When 1.1 completes, fill `{MECHANICAL_CHECK_RESULTS}` in 1.6's instructions and launch 1.6
3. Collect all results

**Fix mode addition**: After the lead applies fixes from the initial results:
1. Re-run task 1.1 with post-edit checks on the modified files
2. Feed those results through task 1.6 again
3. Apply any verification fixes the lead deems necessary

### Step 7: Compile Final Report

After all tasks complete:
1. Merge all findings into a single list, sorted by file path then line number
2. Deduplicate: if two tasks flag the same line for the same rule, keep the one with more detail
3. Resolve conflicts: if two tasks disagree (one says violation, another's context suggests it is intentional), flag it as "needs review" rather than asserting either way
4. Spot-check the consolidated findings per § 5 Spot-Check Procedure before formatting the report. The procedure's fifth item (verify the reviewer's `fix` text is itself rule-compliant) fires here: a `fix` that violates a different rule propagates whether the lead applies it autonomously (fix mode) or surfaces it as a suggestion (review mode). Catch it at consolidation time, not after the fix has shipped.
5. Format according to mode: a numbered suggestion list for review mode, or a summary of applied fixes for fix mode

---

## 4. Error Handling

### Agent Returns Empty Results

**Symptom**: A task agent returns an empty array or no findings.

**Diagnosis**: Either the code is clean for that pass, or the agent failed to execute properly.

**Action**: Check whether the agent's output includes confirmation it read the files. If the agent reports reading 0 files or produces no output at all, retry the task. If it confirms it read the files and found nothing, accept the empty result.

### Agent Returns Malformed Output

**Symptom**: Output is not valid JSON, is missing required fields, or uses a different format than specified.

**Action**: Extract whatever findings are present from the text. If the output is completely unusable, retry the task with an explicit reminder to follow the output format.

### Agent Misapplies a Rule

**Symptom**: A finding cites a rule but the described violation does not match what the rule actually says.

**Action**: Discard the finding. This is a common failure mode for the Code Style Pass when run on a model below Opus - it is one reason that pass requires Opus.

### Mechanical Checks Fail to Run

**Symptom**: The Task 1.1 subagent returns `tooling_log.status == "aborted_at_check"` (per Task 1.1's Failure handling), reporting a permission denial, an unrecognized-command error, or a tool-unavailable error.

**Action**: Halt the workflow at the consolidation point. Do not dispatch Task 1.6. Do not produce a final report. Let any in-flight parallel tasks (1.2-1.5) finish — do not cancel them; their results are preserved for the resumed workflow. Notify the user with: the failed command verbatim, the verbatim error message, the check name the subagent was on, and the allowlist pattern that would resolve a permission denial (e.g., for a `perl` command that was denied, the pattern is `Bash(perl:*)`; for `awk`, `Bash(awk:*)`; for `grep`, `Bash(grep:*)`). The user updates `.claude/settings.json` or `.claude/settings.local.json` and re-invokes the review.

The lead does NOT recover by running the mechanical checks in its own context. The check commands are styleguide-owned text (defined in § 2.x.1 for each language); the allowlist is project-setup territory. Neither is lead-discretionary. The first-run check (see `general/first-run.md` § Mechanical Check Permissions) is what prevents this failure mode from being routine — it verifies the project's permissions cover every language's mechanical-check commands before any review dispatches. An aborted Task 1.1 mid-review indicates the first-run check was not run, or the project's permissions changed since first run; in either case, the recovery is the same: notify the user, hold the workflow, wait for the permission update and re-invocation.

**Platform incompatibilities** (e.g. `grep -P` not available on macOS) are a separate failure mode handled by the language instantiation; they do not produce an `aborted_at_check` state and are not covered by this rule.

### Task Agent Exceeds Context Window

**Symptom**: Agent truncates output or fails to process all files.

**Action**: Split the task. For Code Style Pass, reduce to 3-5 files per agent. For other passes, split per-file.

### Conflicting Findings Between Passes

**Symptom**: The Comment Quality Pass flags a comment as redundant, but the Code Style Pass treats the same code as needing a comment.

**Action**: Include both findings in the report with a note that they conflict. The human reviewer decides. Do not silently drop either finding.

---

## 5. Quality Signals

These patterns help the lead agent spot-check results without reading every finding.

### Positive Signals (Task Executed Correctly)

- **Mechanical Checks**: Output includes matches from multiple different check types, not just one. Output with only one check type's matches may indicate other checks failed to run.
- **Structural Pass**: Output includes both "ok" and "violation" statuses across files. All files reporting "ok" in a large codebase is suspicious.
- **Identifier Scan**: Findings include the detokenized phrase. If findings only list the identifier without the English phrase, the agent skipped the detokenize step.
- **Comment Quality**: Findings span multiple categories (not all "redundant" or all "what-not-why"). A single-category output suggests the agent only checked for one type.
- **Code Style Pass**: Findings reference specific rule names from the style guide. Vague descriptions like "formatting issue" or "style violation" without naming the rule indicate the agent is guessing rather than applying the guide. The `rules_applied` enumeration's union across files covers the loaded guides' rule catalog (modulo structurally-inapplicable rules); a `rules_applied` union substantially narrower than the catalog suggests the reviewer scanned with a narrowed rule set even when the file-level coverage was complete.

### Negative Signals (Task Degraded)

- **Incomplete file coverage**: The output is missing entries for files in the scope set. Multi-file reviewer tasks (1.3, 1.4, 1.5) must produce a per-file output where every file in scope appears as an entry, with empty findings as a positive assertion of coverage. A file that is absent from the output has not been reviewed; do not infer "the reviewer found nothing" from an absent file. Detect by enumerating reported file paths against the scope set and flagging any missing files. This signal protects against reviewer self-truncation under fatigue (the reviewer accumulates a long findings list and stops producing output before reaching all files in scope) and is defense in depth alongside § Engagement Is Unconditional (lead engages every returned item) and `general/review-pipeline.md` § Find Siblings on Pattern-Class Findings (per-finding evidence-of-scan).
- **Incomplete rule coverage**: The Code Style Pass output's `rules_applied` enumeration silently narrows the rule set scanned for, even when every file in scope appears in the output. The reviewer cannot introspect on which rules dropped out of its active scan as the finding count grew, but the up-front rule-catalog construction step in Task 1.5 (build the catalog before reading any source file) produces broader initial-pass coverage, and the per-file `rules_applied` enumeration surfaces the resulting coverage to the lead. Detect by taking the union of `rules_applied` across files and comparing against the catalog of rule headings in the loaded guides; flag rules absent from the union that are not structurally inapplicable (header-only rules in a non-header scope, docstring-shape rules when no documented declarations exist). When the union has unjustified gaps, dispatch a follow-up Task 1.5 pass scoped to the gap rules - the reviewer's job is honest enumeration of what was scanned, not coverage-driven rescan, so coverage recovery is a lead-side responsibility. This is rule-axis coverage and is independent of file-axis coverage above. The two signals fail independently: a reviewer that produces an entry for every file with no findings but a narrow `rules_applied` is file-complete and rule-incomplete; a reviewer that omits files entirely is file-incomplete regardless of rule coverage.
- **Task 1.1 aborted, workflow not held**: A Task 1.1 subagent returned `tooling_log.status == "aborted_at_check"` (per Task 1.1's Failure handling) and the lead did not halt the workflow. The aborted state means the subagent stopped before all checks ran; `matches: []` in this case is NOT a positive assertion of "no violations" — it is the absence of coverage for the checks that did not run. The lead's only correct action on an aborted Task 1.1 is to halt the workflow at the consolidation point, let any in-flight parallel tasks (1.2-1.5) finish (do not cancel them; their results are preserved for the resumed workflow), and notify the user with the failed command, the verbatim error, and the allowlist pattern needed to resolve it. The user updates the project's `.claude/settings.json` or `.claude/settings.local.json` and re-invokes the review; the workflow resumes from the held state. The lead must NOT (i) treat the aborted output as Task 1.1 complete, (ii) dispatch Task 1.6 with the aborted output as input, (iii) run the failed mechanical checks itself inline (the mechanical-check commands are styleguide-owned text per § 2.x.1; the allowlist is user-setup territory; neither is lead-discretionary), or (iv) produce a final report consolidating only the 1.2-1.5 findings (the user gets one signal at this stage — "permissions issue, fix and re-run" — not partial findings that they might mistake for a complete review). Detect by checking every Task 1.1 output for `tooling_log.status`; an aborted state must be paired with a workflow halt and a user notification, not with continued task dispatch or final-report production.
- **Self-canceling findings**: Entries that describe a non-violation. A finding is a verified or suspected violation; an entry shaped like `{issue: "OK, no issue", fix: "No change"}`, `{suggestion: "no change, comment is fine"}`, or any variant where the entry's content is the reviewer reporting that nothing is wrong indicates the reviewer is padding output with inspection records rather than reporting violations. Detect by scanning the consolidated output for entries whose action field (`fix`, `suggestion`) says "no change" or whose `issue`/`category` describes a non-violation; a high fraction of such entries (or a cluster within a single reviewer's output) is the signal. Discard self-canceling entries during consolidation. If they dominate the output, retry the task with explicit instruction that only violations are reported and omission is the positive non-violation assertion.
- **Hallucinated line numbers**: Line numbers in findings that do not exist in the file (higher than the file's line count).
- **Rule name not in the style guide**: The agent cites a rule that does not exist in `general/CLAUDE.md` or the language's `CLAUDE.md`. This is the strongest signal that the agent skipped the Required Reading and is relying on training-data patterns instead. Flag the entire task's results as unreliable and retry after verifying the agent actually performs the reads.
- **No Read calls for the required files**: If the agent's transcript shows no Read calls for the files listed in Required Reading, the agent did not perform the required reading regardless of what it claims in its output. Retry with an explicit verification step.
- **Contradictory findings**: Two findings from the same agent that contradict each other.
- **Identical findings across files**: Copy-paste findings with different file names but identical line numbers and descriptions. Indicates the agent generated findings without reading the files.
- **Flagging standard library names**: Suggesting renaming language built-ins or standard library identifiers.
- **Applying wrong language rules**: Findings that reference conventions from a language different from the one being reviewed.
- **Lead executes reviewer tasks inline**: The lead runs a Task 1.1 mechanical check, a Task 1.3 identifier scan, or any other reviewer task in its own context instead of dispatching a fresh subagent. The framework's cold-context property is what those dispatches preserve; running them inline collapses the lead's context onto the reviewer's and destroys the property the framework is built on. Symptoms: the lead reports running grep/awk commands via Bash without launching a subagent for Task 1.1; the lead's task manifest lists fewer dispatches than the framework's task count; the lead applies a fix from a "finding" it produced inline rather than from a dispatched reviewer's output. **Model strength does not suppress this failure.** Per `general/agents.md` § Framework Pattern, framework adherence is a function of the procedure being expressed as a manifest the lead executes mechanically (Step 4 of § 3), not of the lead's reasoning capacity — an Opus lead skips dispatches via the same action-mode pattern-match as a Sonnet or Haiku lead. The structural enforcement (the Step 4 dispatch manifest as a written artifact the lead produces before launching) is what holds the procedure together; the lead's capability is not the load-bearing layer. Detect by counting dispatched subagents against the manifest's task count; restart the affected step as a proper dispatch when the count is short.

### Spot-Check Procedure

For each task type, randomly sample 2-3 findings and verify:
1. The line number exists in the file
2. The cited rule exists in the style guide
3. The described violation matches what the rule actually prohibits
4. The code at that line actually exhibits the described pattern
5. The reviewer's proposed `fix` text is itself rule-compliant — would Task 1.5 flag the `fix` as a violation if it appeared in the codebase? Read the `fix` field as if it were original code: does it satisfy the cited rule, and does it satisfy every other rule in the loaded guide? A `fix` that corrects the cited violation but introduces a different violation is incomplete. This check applies whether the reviewer's `fix` will be applied autonomously (fix mode) or surfaced to the user as a suggestion (review mode); in either mode the lead is passing the reviewer's text to a downstream consumer that takes it as authoritative, and a rule-violating `fix` propagates regardless of which consumer receives it.

If any sampled finding fails verification, flag the entire task's results as unreliable and consider retrying with a more explicit prompt or a different model. If item 5 specifically fails — the `fix` text violates a rule — the issue may be local to that single finding rather than the whole task; the lead can either apply a corrected version, re-dispatch the reviewer for that finding alone with a hint, or escalate to the user. A pattern of fix-text rule violations across multiple sampled findings indicates the reviewer is not applying the loaded guide consistently and the whole task should be retried.

---

# Part 2: Language Instantiations

## 2.1 C

### 2.1.1 Mechanical Checks (Task 1.1)

Each check is marked with its phase. Pre-edit checks run at the start of review. Post-edit checks run after the lead applies fixes (fix mode only).

```bash
# [pre-edit] Brace style: `) \n {` on multi-line signatures, if-statements, or
# similar (should be `) {` together). Pairs the closing `)` on its own line with
# a `{` alone on the next line. Catches column-zero and indented forms; the
# optional `\\` accommodates the same shape inside `#define` macro bodies where
# each line ends with `\` continuation.
perl -n0e 'while (/^\s*\)\s*\\?\s*\n\s*\{/gm) { print "$&\n---\n" }' <file>

# [post-edit] Line length: lines exceeding 80 characters
awk 'length > 80 {print FILENAME ":" NR ": " length " chars"}' <file>

# [pre-edit] Section divider comments (at any indent level)
grep -Pn '^\s*// --.*---' <file>

# [pre-edit] UPPER_CASE on static const variables (should be snake_case)
grep -Pn 'static const.*[A-Z]{2,}.*=' <file>

# [pre-edit] Cast missing space after closing paren (all cast types, not just stdint)
grep -Pn '\([a-z_]+\*?\)[a-zA-Z_(]' <file>

# [pre-edit] @return not separated from @param by blank line
awk '/@param/ {param=NR} /@return/ {if (param == NR-1) print FILENAME ":" NR}' <file>

# [pre-edit] Pointer style: star on variable side instead of type side
grep -Pn '\w \*\w' <file>

# [pre-edit] Empty parens instead of (void) on zero-parameter functions
grep -Pn '\w\(\)\s*[{;]' <file>

# [pre-edit] else on same line as closing brace
grep -Pn '}\s*else' <file>

# [pre-edit] Prohibited abbreviations in variable/constant names
grep -Pn '\bbuf\b|\blen\b|\bmsg\b|\bsrc_\b|\bdst_\b|\bcksum\b' <file>

# [pre-edit] memset at declaration (should use = { 0 } instead)
grep -Pn 'memset\(.*0.*sizeof' <file>

# [pre-edit] Operator at end of line (should be at start of continuation)
grep -Pn '[+\-*/|&] *$' <file>

# [pre-edit] Lone closing paren on its own indented line (candidate "split parens"
# violation in multi-line `if` calls - the call's `)` should not drop alone to
# a new line when the `if`'s `)` is also on its own line; both should be together)
grep -Pn '^\s+\)\s*$' <file>

# [pre-edit] Single-statement control-flow body wrapped in braces
# Matches `if`, `for`, and `while` whose body block contains exactly one statement.
# The condition pattern allows one level of nested parens (function calls in the
# condition are common). Multi-line bodies, multi-statement bodies, and
# do-while are not matched.
perl -n0e 'while (/\b(if|for|while)\s*\(((?:[^()]|\([^()]*\))*)\)\s*\{\n\s*[^;{}\n]+;\n\s*\}/g) { print "$&\n---\n" }' <file>

# [pre-edit] Multi-line call/declaration with `);` glued to the last continuation
# line (closing `)` should be on its own line at the construct's indent per
# c/CLAUDE.md § Line Breaks in Long Expressions). Matches lines ending in `);`
# (non-whitespace preceding) where the line has more closing parens than opening
# parens after stripping C++ line comments and string literals - i.e., the line
# closes a paren opened on an earlier line. Catches multi-line call sites,
# function declarations, and single-arg macro wraps uniformly.
perl -ne '
  my $line = $_;
  $line =~ s{//.*$}{};
  $line =~ s{"(?:[^"\\]|\\.)*"}{}g;
  if ($line =~ /\S.*\);\s*$/) {
    my @opens = $line =~ /\(/g;
    my @closes = $line =~ /\)/g;
    print "$ARGV:$.: $_" if @closes > @opens;
  }
' <file>
```

**Classification rules for Task 1.6 (Mechanical Check Review):**

- **Brace `) \n {`**: True violation by default. The pattern matches `)` alone followed by `{` alone, in plain code or inside a `#define` macro body where each line ends with `\` continuation. False positive only when the codebase consistently uses this style.
- **Line length > 80**: False positive if the long content is a string literal, include path, or URL. True violation otherwise.
- **Section divider**: Always a true violation. No exceptions.
- **UPPER_CASE static const**: True violation if it is an array or single variable. False positive if inside a `#define` or enum.
- **Cast missing space**: True violation if it matches a real cast expression. False positive if it matches a function pointer typedef or sizeof expression.
- **@return not separated from @param**: Always a true violation.
- **Pointer style (star on variable side)**: True violation unless followed by `const` (the `*const` exception). False positive if the match is inside a string literal or comment.
- **Empty parens**: True violation on function declarations and definitions. False positive on macro invocations.
- **else on same line**: True violation unless the codebase consistently uses `} else {` style.
- **Prohibited abbreviations**: True violation in identifier names. False positive if the match is inside a string literal, comment, or part of a longer word (e.g. "buford" matching "buf").
- **memset at declaration**: True violation if the variable could use `= { 0 }` instead. False positive if zeroing through a pointer.
- **Operator at end of line**: True violation for arithmetic/logical operators. False positive for pointer dereference (`*`), address-of (`&`), or operators inside string literals.
- **Lone closing paren on its own indented line**: True violation when inside a multi-line `if` (or similar control-flow) condition - the rule is that both closing parens go together (`))` on one line). True violation when the next non-blank line is a lone `;` — this is the split `);` shape (`)` and `;` on separate lines) which violates § Brace Style's rule that `);` go together on the closing line; reclassify the finding as a brace-style violation rather than a lone-closing-paren false positive. False positive for multi-line function signatures, multi-line function calls NOT inside a control-flow condition where the next line continues the expression (the `)` on its own line is valid there - see the Line Breaks in Long Expressions rule), and multi-line function definitions where `)` precedes `{` on the next line. Inspect the enclosing construct AND the next non-blank line before classifying.
- **Single-statement control-flow body in braces**: True violation by default - the rule (`c/CLAUDE.md` § Single-Statement Bodies) says omit braces for single-statement bodies. False positive when the match is part of an `if`/`else if`/`else` chain in which any other branch has multiple statements: the all-or-nothing exception requires every branch to keep its braces in that case. Inspect the surrounding chain before classifying. The check is `if`/`for`/`while`-only; `for`/`while` have no chain analog, so the all-or-nothing exception does not apply to them. Known false negatives the regex does not catch: a body whose single statement is itself a multi-line construct (e.g. a naked inner `if` with its body on the next line) - Task 1.5 catches these with lower efficiency.
- **Multi-line `);` glued**: True violation by default - the rule (`c/CLAUDE.md` § Line Breaks in Long Expressions) says the closing `)` of a split call or declaration goes on its own line at the construct's indent, with `;` glued to that `)`. The check fires on the last continuation line of a multi-line call or declaration where `);` is glued to the final argument or parameter. Applies uniformly to call sites, function declarations, and single-arg macro wraps (e.g. `RUN_TEST(\n test_name);`). False positive when the apparent imbalance is an artifact of constructs the line-level paren count cannot resolve - character literals containing `(` or `)`, statement-expression GCC extensions (`({ ... });`), or block comments mid-line that the stripping pass did not remove. Inspect the surrounding construct: if the line is a single-line statement that fits on its own (no preceding continuation line), it is a false positive regardless of paren count.

### 2.1.2 File Ordering Templates (Task 1.2)

**Header files (.h)** must follow this order:
1. `#pragma once` (or `#ifndef` guard)
2. Includes (grouped: system, then external libraries, then local project headers, separated by blank lines)
3. `#define` constants (ALL `#define` constants must appear above ALL `typedef enum`/`typedef struct` definitions)
4. Type definitions (`typedef enum`, `typedef struct`)
5. Function declarations

**Source files (.c)** must follow this order:
1. Includes (grouped as above)
2. `#define` constants
3. Static variables
4. Forward declarations of static functions
5. Public API functions
6. Static helper definitions

**Test files** must follow this order:
1. Includes
2. Static variables/helpers
3. `setUp`/`tearDown`
4. Test functions

**Include grouping rules:**
- Group 1: Standard library (`<stdint.h>`, `<string.h>`, etc.)
- Group 2: External libraries (`<zephyr/kernel.h>`, `"unity.h"`, etc.)
- Group 3: Local project headers (`"app_config.h"`, etc.)
- Groups separated by blank lines
- Do NOT put the module's own header first - standard library always comes first
- External libraries like Unity are group 2, not group 3

### 2.1.3 Identifier Rules (Task 1.3)

**Prohibited abbreviations** (always flag): `buf`, `len`, `msg`, `src`, `dst`, `cksum`

**Accepted short forms** (never flag): `ptr`, `fd`, `fn`, loop counters (`i`, `j`, `k`)

**Namespace prefixes** are expected to be short and must be stripped before applying the detokenize technique. Example: `app_src_port` → strip `app_` → "src port" → abbreviated.

**Standard acronyms from formal specifications** (RFCs, IEEE standards) are acceptable when used as constant names: `IHL`, `DSCP`, `ECN`, `TTL`. Require a comment referencing the relevant spec.

### 2.1.4 Comment Rules (Task 1.4)

**Required documentation:**
- All public function declarations in `.h` files require a Doxygen `/** */` docstring
- Public structs, enums, and types require a `/** @brief */` or fuller Doxygen block
- `@file` block required at the top of every `.h` file (and `.c` files that need implementation-level documentation - RFCs, protocol specs, complex algorithms)

**Doxygen format:**
- Use `/** */` not `///` (silent breakage risk)
- Use `@` tags (`@param`, `@return`, `@brief`) not `\` tags
- `@return` separated from `@param` block by a blank line
- `@param` descriptions aligned within their group
- `///<` trailing docs on struct fields and enum values - all `///<` in a group must start at the same column

**Always a violation:**
- Section divider comments (`// -- Public API ---`, etc.)
- `///` instead of `/** */` for function docs
- `\param` instead of `@param`
- `/* */` for inline comments in code (use `//`)
- Doxygen on `.c` implementation when it should be on `.h` declaration

### 2.1.5 Code Style Rules (Task 1.5)

The full rule catalog is in `c/CLAUDE.md`. The Opus agent reviewing for Task 1.5 must read that guide in full. Key categories it covers:

- Namespace prefixes and naming conventions
- Include ordering and header file ordering
- Indentation and line length
- String literals (grepability rule)
- Brace style (single-line vs multi-line signatures, control flow, structs)
- Single-statement bodies
- Pointer declaration style (`int*` on type side, not variable side; `*const` exception)
- Spacing (operators, keywords, parens)
- Comment style (`/** */` Doxygen)
- Line breaks in long expressions (operator at start of continuation)
- Blank line after declarations
- Empty loop bodies
- Trailing commas (valid in collections, not in function args)
- Whitespace in structs
- Column alignment (`#define` groups left-aligned at the soonest tab stop with a 2-space minimum gap past the longest name; signed numeric groups pad positive values with a leading space so digits align; solo defines follow the same tab-stop rule against their own name)
- Enums (start at 1, opaque identifiers)
- Struct packing, anonymous unions
- Function ordering in source files
- Interface and implementation separation
- Minimize global state
- Variable declaration placement
- Header self-containment
- Internal linkage (`static`)
- Conditional compilation (prefer stubs over `#ifdef`)
- Function prototypes
- `inline` usage
- Cleanup with `goto`
- Pointer parameters over array notation
- Fixed-width integer types
- `bool` type
- Designated initializers, `= { 0 }` over `memset`
- Initialize at declaration
- `const` correctness
- Typedef structs
- Floating-point (`double` over `float`)
- No VLAs
- `sizeof` on variables
- Do not cast `void*` (malloc, calloc)
- Error return conventions (0 success, non-zero failure; `error` variable name)
- Diagnostics to `stderr`
- Check return values
- `static inline` over function-like macros
- Macro line continuation (unaligned)
- Named boolean expressions
- No assignment in conditions
- Bounded string functions
- Ternary operator
- Unused parameter suppression
- Switch completeness (default case, comment intentional fallthrough)
- Literal-first comparisons in `if`
- Implicit boolean conversion
- Sentinel-terminated arrays
- Unit suffixes (`_IN_<unit>` pattern)

**Common false positive patterns specific to C:**
- Brace on same line as single-line function signature (violation) vs. brace on same line for control flow (correct) - agents confuse which case applies
- Flagging `} else {` when the codebase consistently uses that style
- Flagging `int *p` pointer style when the codebase consistently uses that convention
- Marking `0` as wrong enum start when the enum interfaces with an external protocol
- Flagging `memset` that zeroes through a pointer (correct use) vs. at declaration (should be `= { 0 }`)
- Flagging `result` variable name when the return value represents more than error/success
