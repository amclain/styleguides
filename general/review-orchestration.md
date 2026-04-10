# Style Review Orchestration Framework

This document defines the orchestration framework for multi-agent style reviews and the concrete instantiations for each supported language. It is the single source of truth for how reviews are decomposed, which models are assigned to which tasks, and what checks run in what order.

A lead agent reads this document, identifies the target language, and produces a concrete task plan from the framework section plus the target language's instantiation section. Task agents execute the plan. The lead collects results and produces a final report.

This framework applies to both review mode (suggestions presented to the user) and fix mode (autonomous corrections). See `skills/format-code/SKILL.md` and `skills/format-review/SKILL.md` for the user-facing entry points.

## Contents

1. Framework (language-agnostic) - task types, dependency graph, orchestration, error handling, quality signals
2. Language instantiations - concrete checks, templates, and rule catalogs for each supported language
   - 2.1 C

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
| Reviewing test files for `<lang>` | `<lang>/testing.md` (typically `@` imported from the language CLAUDE.md; load explicitly if not) |
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

**Model**: Single-concern task, no judgment required. Command execution and output collection. Haiku or Sonnet.

**Decomposition**: Run all pre-edit checks as one task per file set at the start of review. Run post-edit checks as a second invocation after the lead applies fixes. Do not split the checks further - they are independent commands that complete in seconds and splitting creates coordination overhead.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Run the mechanical checks for {LANGUAGE} on each file in {SCOPE}. Report raw results only - do not interpret them. Each result line must include the file path, line number, and the name of the check that matched.

Phase: {PHASE}  (pre-edit or post-edit)

Checks to run: {CHECKS_FOR_PHASE}

Scope filtering: {SCOPE} contains a file list with changed line ranges. Run the checks against the entire file (many checks are file-scoped by nature), then filter results to include only matches on lines within the changed ranges. If {SCOPE} is "all", report all matches without filtering.

Output format - one JSON array:
[
  {"file": "path", "line": N, "check": "check_name", "match": "matched text"}
]

If a check produces no matches (or no matches within scope), omit the file from the output.
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
```

**Test name grammar is part of this pass.** Evaluating test name grammar is a multi-concern task (recognizing propositions, distinguishing verb-leading from noun-leading names, applying implicit subject from file name). When reviewing test files specifically, run the Identifier Scan for test names with **Opus** instead of Haiku. Opus has the judgment to accept valid constructions that Haiku over-flags. This reassignment is an exception to the default Haiku assignment for this pass and applies only to test files.

**Common false positives**: names matching external API conventions the codebase integrates with, short field names that are precise within their struct context, local variables in narrow scopes, test names with implicit subjects from the file name.

---

### 1.4 Comment Quality Pass

**Purpose**: Review comments for redundancy, misplaced information, and violations of the Write Self-Documenting Code principle from `general/CLAUDE.md`.

**Model**: The categories of bad comments are well-defined. Sonnet or Haiku scoped per category.

**Decomposition**: Can be decomposed per-file for large reviews.

**Instructions (template)**:

```
Required reading (read in full before any other work, one Read call per file, no offset or limit):
{REQUIRED_READING}

Read each source file in {SCOPE}. Read the full file for context. Review comments on lines within the changed line ranges - do not flag comments in unchanged code. In `--all` scope, review every comment. Flag comments that match any of these categories:

1. Redundant comments that restate what the code expresses
2. Comment-as-constant: comments explaining a literal value that should be a named constant. When flagging these, the fix is to change the representation first, THEN remove the comment. Do not suggest removing the comment without fixing the representation.
3. What-not-why comments: describing what the code does rather than why
4. Section divider comments: decorative comments marking code regions (always a violation)
5. Missing required documentation on public APIs per the language guide
6. Documentation format issues per the language guide
7. Misplaced documentation (e.g. on the wrong definition site per language convention)
8. Misaligned trailing documentation where alignment is required

Language-specific documentation rules: {DOC_RULES}

Output format:
[
  {
    "file": "path",
    "line": N,
    "category": "redundant | comment_as_constant | what_not_why | section_divider | missing_doc | doc_format | misplaced_doc | misaligned_doc",
    "comment_text": "the comment",
    "suggestion": "what to do"
  }
]
```

**Common false positives**: `// style:ok` / `# style:ok` override comments (never flag them), required fallthrough markers in switch statements, comments explaining "why" that look like "what" at first glance.

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

**Group cohesion exception:** when a changed line is part of a group of related code (multiple clauses of the same function, branches of the same case/switch, fields of the same struct, steps of the same pipeline, a sequence of similarly-structured setup calls), evaluate the group as a whole. If the change creates an inconsistency within the group, either reformat the change to match the group's existing style or reformat the group to match the change - whichever produces more natural code. This may require touching unchanged lines within the group. Apply this exception conservatively: only for lines that are clearly part of the same group as the change, and only when the inconsistency meaningfully degrades readability. See the Review Scope section for details and examples.

Apply all rules from the language guide and the general guide. For each finding, provide:
- File path and line number
- The rule being violated (by name from the guide)
- What the code does wrong
- What it should look like

Respect style override markers - do not flag code they cover.

Respect project-level overrides: {CODEBASE_OVERRIDES}

Output format:
[
  {
    "file": "path",
    "line": N,
    "rule": "Rule Name",
    "issue": "description of violation",
    "fix": "what correct code looks like"
  }
]
```

**Common false positives**: cases covered by the codebase's established conventions (precedence in the codebase rule), rules that do not apply to the specific context, intentional deviations marked by style overrides.

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
    "overrides": ["none | list of codebase conventions that override defaults"]
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
   - If any file in scope is a test file: `<lang>/testing.md`
   - If any file in scope uses a framework with a mechanics reference (e.g. Unity, ESpec, a DI library): the mechanics reference file
   List files with absolute or repo-relative paths so the task agent can Read them directly.
5. Replace other placeholders (`{CHECKS_FOR_PHASE}`, `{PROHIBITED_ABBREVIATIONS}`, `{ORDERING_RULES}`, etc.) with the actual content from the language's instantiation section in Part 2
6. For the Mechanical Check Review task, leave `{MECHANICAL_CHECK_RESULTS}` as a placeholder - it will be filled with the output of the Mechanical Checks task at runtime
7. If project context includes overrides, append a "Project-specific overrides" section to each instruction that notes which default rules are suppressed

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
4. Format according to mode: a numbered suggestion list for review mode, or a summary of applied fixes for fix mode

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

**Symptom**: Commands error out (permission denied, file not found, incompatible tool flags on the platform).

**Action**: Verify file paths are correct. If commands fail on the platform (e.g. `grep -P` not available on macOS), substitute compatible alternatives as specified in the language instantiation.

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
- **Code Style Pass**: Findings reference specific rule names from the style guide. Vague descriptions like "formatting issue" or "style violation" without naming the rule indicate the agent is guessing rather than applying the guide.

### Negative Signals (Task Degraded)

- **Hallucinated line numbers**: Line numbers in findings that do not exist in the file (higher than the file's line count).
- **Rule name not in the style guide**: The agent cites a rule that does not exist in `general/CLAUDE.md` or the language's `CLAUDE.md`. This is the strongest signal that the agent skipped the Required Reading and is relying on training-data patterns instead. Flag the entire task's results as unreliable and retry after verifying the agent actually performs the reads.
- **No Read calls for the required files**: If the agent's transcript shows no Read calls for the files listed in Required Reading, the agent did not perform the required reading regardless of what it claims in its output. Retry with an explicit verification step.
- **Contradictory findings**: Two findings from the same agent that contradict each other.
- **Over-flagging style override lines**: Any finding on a line with a style override marker is an error.
- **Identical findings across files**: Copy-paste findings with different file names but identical line numbers and descriptions. Indicates the agent generated findings without reading the files.
- **Flagging standard library names**: Suggesting renaming language built-ins or standard library identifiers.
- **Applying wrong language rules**: Findings that reference conventions from a language different from the one being reviewed.

### Spot-Check Procedure

For each task type, randomly sample 2-3 findings and verify:
1. The line number exists in the file
2. The cited rule exists in the style guide
3. The described violation matches what the rule actually prohibits
4. The code at that line actually exhibits the described pattern

If any sampled finding fails verification, flag the entire task's results as unreliable and consider retrying with a more explicit prompt or a different model.

---

# Part 2: Language Instantiations

## 2.1 C

### 2.1.1 Mechanical Checks (Task 1.1)

Each check is marked with its phase. Pre-edit checks run at the start of review. Post-edit checks run after the lead applies fixes (fix mode only).

```bash
# [pre-edit] Brace style: `) \n{` on multi-line signatures (should be `) {`)
grep -Pn '^\)\s*$' <file>

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
```

**Classification rules for Task 1.6 (Mechanical Check Review):**

- **Brace `) \n{`**: True violation unless inside a macro or the codebase consistently uses this style.
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

**Accepted short forms** (never flag): `ptr`, `fd`, `cb`, `idx`, loop counters (`i`, `j`, `k`)

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
- Column alignment (`#define` groups right-justified; solo defines use 1-2 tab stops)
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
