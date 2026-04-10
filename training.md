# Training Guide

This file documents the process for developing and validating rules in this style guide system. It is intended for AI agents assisting with rule development, not for human readers.

---

## Training Status

| Language | Phase | Notes |
|----------|-------|-------|
| C | Phase 2 (project training) | Rules complete. First project validation run done. Google Test conventions TBD. |
| Elixir | Phase 2 (project training) | Rules complete. First project validation run done. |
| Rust | Not started | Next language in priority order. |
| TypeScript | Not started | Covers JavaScript (superset, one guide). |
| Ruby | Not started | |

---

## Target Runtime Agent

Rules in this system are applied at runtime during code generation and style review. The consuming agent may be a cloud model (Claude Sonnet, GPT-4, etc.) or a local model (Qwen 2.5 Coder, DeepSeek Coder, etc.). **Optimize for Claude Sonnet as the primary consumer.** Cater to other agents when it is reasonable to do so without compromising the rules for Sonnet.

Practical implications:
- Be explicit. Do not rely on inference that a stronger model would make naturally.
- State intent, not just pattern. Sonnet applies rules more reliably when it understands *why*, not just *what*.
- Specify edge cases that are not obvious from the rule alone. If an Opus-class agent would handle an edge case intuitively, a Sonnet-class agent may need it stated.
- Examples are load-bearing. Well-chosen `# good` and `# avoid` examples carry as much weight as the prose description.

---

## Agent Model Selection

The agent developing rules may be Sonnet or Opus. The primary target consumer is Claude Sonnet, though the rules should work reasonably well for other agents. Regardless of which model is writing rules, calibrate to Sonnet's capability.

For detailed guidance on which models to use for which tasks, attention fatigue, and multi-agent orchestration patterns, see `general/agents.md`. Key points for training:

- **Opus** is best for high-novelty judgment work: rule development, edge case evaluation, conflict resolution. It degrades on sustained repetitive work (8-10 similar items before pattern completion sets in).
- **Sonnet** is best for focused generation, structured review, and research. It degrades silently under repetition - no behavioral warning, just subtle template-completion errors.
- **Haiku** is best for single-concern focused tasks. It performs at full capability on complex reasoning when given one job (e.g. evaluating English grammar in test names, checking one mechanical rule across a codebase).
- **Task scoping matters more than model selection.** A well-scoped Haiku task outperforms a poorly scoped Opus task. Decompose into single-concern subtasks where possible.

---

## Rule Development Workflow

1. **Identify a gap** — a pattern in real code that the current rules do not cover, or a case where the rules produce the wrong result.
2. **Discuss** — reason through the principle before writing the rule. Understand *why* the pattern is preferred before codifying it.
3. **Write the rule** — follow the rule format: intent, convention, example (`# good` / `# avoid`), when to deviate.
4. **Validate examples** — all `# good` examples must conform to every rule in the guide. Run an audit if examples were added or changed.
5. **Test against a real codebase** — apply the updated guide to real code. A second agent run with fresh context is the most reliable signal.
6. **Iterate** — gaps found during testing become new rule development cycles.

Rules are developed in a separate working environment and synced to this repository when complete.

---

## Rule Review (from findings)

When reviewing candidate rules extracted from source material (books, style guides, codebases), follow this process for each rule:

1. **Present the rule** — print the rule with observations. If the rule matches a convention in the user's code, bias toward the user's style and cite it. Note other authors and their opinions on similar rules.
2. **Pattern file** — write code examples to a pattern file for user review. See the Pattern Files section below for the format and when pattern files apply.
3. **Document and record** — once the user approves, write the rule into the language's `CLAUDE.md` (e.g. `c/CLAUDE.md`) following the standard rule format: intent, convention, examples (`// good` / `// avoid`), when to deviate. Update memory with which rules are complete.
4. **Validate examples compile** — verify that all `// good` examples in the section actually compile and run correctly. Build a test file with scaffolding (type stubs, dummy functions) that includes the examples as real code. If an example doesn't compile, fix it. Examples that don't compile teach agents broken patterns.
5. **Next rule or section validation:**
   - If more rules remain in the section, repeat from step 1 with the next rule.
   - If the section is complete, run a cold Sonnet agent to generate code following the documented rules. Refine rules until the agent writes correct code.
6. **Cold Opus review** — run an Opus cold reviewer that audits all examples against all rules (not just the rule they demonstrate). The main agent validates each finding, implementing only confirmed improvements. If any changes affect agent behavior, return to step 5 and retest with a cold generation agent.
7. **Checkpoint** — review session context, ensure all knowledge is documented. Mark the section complete and update memory.

---

## Pattern Files

Pattern files are the medium for collaborating on language rules. The training agent writes a pattern file when proposing a new rule or modifying an existing one; the user reviews and edits the file directly to refine the rule.

### What a pattern file is

A pattern file is a **source code file in the language of the rule being reviewed**, written to `patterns/` in the styleguides repo. C rules get `.c` files. Elixir rules get `.ex` or `.exs` files. Rust rules get `.rs` files. The file contains real code examples demonstrating the rule, reviewable and editable in the medium the rule actually governs.

A pattern file is NOT a markdown document describing a rule. Markdown is not the language the rule exists in, and reviewing a rule by editing prose defeats the purpose of having concrete examples. If a rule is important enough to document, the examples are important enough to show in their native form.

### Structure

- **Top-level comment** explaining the rule: what it is, the background that prompted it (training scenario, field report, user observation), what the rule changes relative to the current state of the guide, and what the rule does NOT change.
- **Code examples** in the language of the rule, using the language's comment convention to mark `// good` and `// avoid` cases. Examples should be realistic and exercise the rule's intent.
- **Inline comments** clarifying specific points - why an example is good or bad, what a reader should notice, edge cases.

The file should be syntactically valid (or close to it) so that language-aware tooling can assist review. Include minimal scaffolding (`#include` lines, empty function bodies) to achieve this. The file does not have to compile or run - it is for review, not execution - but it should not contain syntax errors that obscure the examples.

### When to write a pattern file

Write a pattern file when:
- Proposing a new rule for a language guide (e.g. `c/CLAUDE.md`, `elixir/CLAUDE.md`)
- Modifying an existing language rule
- Demonstrating a code pattern the user needs to see to evaluate the rule

Write the pattern file **as part of presenting the rule**, not after the user asks for it. The user reviews rules by editing pattern files; presenting a rule without the file means an extra round-trip.

### When NOT to write a pattern file

Do NOT write a pattern file for:
- Agent instructions, workflow rules, orchestration frameworks, training processes. These are logical instructions about how agents operate, not source-code rules. Discuss them in the console and edit the target file directly (`training.md`, `general/agents.md`, `general/review-orchestration.md`, etc.).
- Rules that do not need code to clarify. If the rule is purely logical (e.g. "do not checkpoint during discovery"), prose discussion is clearer than a contrived code example.

If uncertain, ask: "does this rule involve source code the user needs to see to evaluate it?" If yes, pattern file. If no, direct discussion.

### Cleanup

Delete pattern files after the rule is approved and written into the language guide. Pattern files are working artifacts, not permanent documentation - the language guide is the canonical source of truth. Leaving pattern files around after approval causes confusion about which document defines the rule.

---

## Training Agent Role

The training agent (you) develops rules, launches validation agents, and evaluates results. You are not a formatter or reviewer - you orchestrate them. Skill files like `format-code/SKILL.md` and `format-review/SKILL.md` are instruction sets for the agents you launch, not instructions for you.

Each agent reports a summary in its final text response: what it found, what it fixed, and what it considered but decided was not a violation. This summary arrives as the task notification result. The training agent does not parse agent output files - it reads the summary from the notification. Record results to a tracking file (e.g. `patterns/validation_results.md`) as agents complete. The formatter agents fix code; the training agent fixes the guide.

### Training phases

Training has two phases with different validation strategies:

**Phase 1: Rule training.** When training on a new language, there are many rules to codify. Generate a high number (~10 per batch) of non-trivial code examples as individual files, each exercising different rules. Launch one cold agent per file. The files are unrelated scenarios - context from one file biases the review of another, so per-file agents avoid contamination.

**Phase 2: Project training.** Once the rules are codified, test how they apply across files and unit tests in a real project. Generate 3-4 full project examples, each with several source files and tests that build and run. Launch one cold agent per project. This matches how a real agent experiences the project - reviewing related files with shared context. The agent runs the test suite after making changes, catching bugs that standalone file review cannot (broken renames, removed symbols, type mismatches).

This is distinct from a production project where a single review agent reviews all files for a given task, because production files are related work and shared context is always useful.

---

## Validation

Validation strategies differ between training phases. Both phases use **separate generate and review agents** - a single agent that generates and reviews its own code has contaminated context.

### Phase 1 validation (rule training)

Goal: confirm agents follow the rules when generating and reviewing individual files.

**Sonnet consensus (generation + review):**

1. Choose file archetypes that exercise the rules being validated (e.g. GenServer module, Supervisor, ESpec test, Phoenix context).
2. Launch **1 Sonnet generate agent** per archetype. Write the generated code to `patterns/` files.
3. Launch **3 independent Sonnet review agents** per file. Each reads the generated code and the style guides cold, lists violations only. Agents have no access to each other's findings.

Consensus filtering (3 reviewers):
- **3/3 agreement** - confirmed finding. The rule is consistently missed. Candidate for strengthening.
- **2/3 agreement** - strong signal. Add to watch list or promote if corroborated by other files.
- **1/3 agreement** - noise. Filter out. Sonnet reviewers have a non-trivial false positive rate (misreading code, flagging non-issues). Consensus filtering catches these reliably.

Always verify findings against the actual code. Reviewers (both Sonnet and Opus) occasionally misread code - claiming violations exist when they don't, or claiming code is clean when it isn't.

**Opus validation pass (after Sonnet is refined):**

Once Sonnet consensus has stabilized and rules are strengthened, run an Opus validation pass:
1. Opus reliably catches all rules (it should, being the recommended review model).
2. CAUTION callouts added for Sonnet didn't cause Opus to apply rules mechanically instead of using judgment.
3. No regressions from rule updates.

Use **1-2 Opus reviewers per file**. The training agent validates each finding against the actual code. Opus has lower noise than Sonnet, so 3-reviewer consensus is unnecessary, but Opus reviewers still misread code and fabricate evidence. Every finding must be verified.

### Phase 2 validation (project training)

Goal: confirm rules work across related files in a real project, with a build/test step that catches mechanical errors.

1. Generate 3-4 buildable project examples (see Validation Projects below).
2. Launch **1 Opus formatter agent per project** in fix mode. The agent reads the style guide, reviews all files, fixes violations, and runs the test suite.
3. The training agent verifies tests pass after the formatter's changes. If tests fail, this reveals guide bugs (e.g. a rule that breaks the build) or formatter bugs (e.g. incomplete renames).
4. The training agent reviews the formatter's summary for missed violations and false positives.

Phase 2 validation also benefits from mechanical checks and the multi-pass review architecture. The formatter runs structural, identifier, comment quality, and code style passes - each focused on one concern. This catches violations that a single general review pass misses.

**Warm agents in Phase 2:** With agent teams enabled, validation reviewers can be kept warm across files within a project. A warm Haiku agent doing single-rule review accumulates cross-file awareness - it notices systematic patterns ("this codebase consistently uses star-on-variable in .c files but star-on-type in .h files") rather than reporting the same violation independently in every file. See `general/agents.md` for setup and usage.

### Recording results

Record results to a tracking file (e.g. `patterns/iteration_misses.md`) as each batch completes. This file survives context compaction - subagent results delivered as task notifications do not. Always record before launching the next batch.

The tracking file uses consensus tables per file:

```markdown
### F3: Binary parser (MyApp.Protocol.Parser)

| Finding | R1 | R2 | R3 | Consensus |
|---|---|---|---|---|
| Directive ordering (defstruct before types) | YES | YES | YES | **3/3** |
| Blank line before return in encode/1 | YES | no | no | 1/3 |
```

### Interpreting results

After all files are validated, compile findings into two lists:

- **Confirmed patterns (strengthen)** - 3/3 consensus or consistent misses across multiple files. These need stronger rule text (fold the warning into the convention), CAUTION callouts for verification techniques, stronger examples, or restructured rule text.
- **Watch list** - 2/3 consensus or isolated misses. Collect more data before changing the guide. 2/3 items are reviewer-catch targets, not necessarily generator fixes.

### What works for strengthening rules

Ranked by effectiveness (most to least):

1. **WRONG/RIGHT examples** - concrete side-by-side showing the anti-pattern and the fix. Most effective mechanism. Use realistic code matching the exact patterns agents produce.
2. **CAUTION self-check** - "after writing X, verify Y." Works when combined with examples. Effective for ordering rules where the agent needs to review its own output. Use `CAUTION:` prefix for verification techniques and diagnostic tips. Fold "don't do X" warnings directly into the convention text instead.
3. **Frontloading** - putting the key constraint first in the rule, before the details. Effective when the rule text buries the important part.
4. **Clearer labels** - disambiguating vague terms so the agent can distinguish categories (e.g. "Module attributes" is ambiguous when everything starting with `@` is technically a module attribute).
5. **Prose-only strengthening** - adding emphasis, bold text, or rephrasing without examples. Least effective alone. Use only in combination with examples.

### Sonnet limitations

Some rules are resistant to all strengthening attempts because the model's training data overwhelms the guide instruction. Known Sonnet blind spots:

- **Zero-arity type parentheses** - Sonnet consistently generates `String.t()`, `binary()`, etc. and Sonnet reviewers catch it only 0-50% of the time. Opus reviewers catch it reliably after strengthening.
- **Pipe operator parentheses** - Sonnet generates `Repo.all()`, `Enum.sum()` in pipes and Sonnet reviewers catch it inconsistently. Opus catches it reliably after strengthening.

These are formatting-level issues (not logic errors) and are candidates for a post-generation formatting pass - an autonomous agent that fixes mechanical patterns the generator leaves behind.

### Reviewer accuracy

Both Sonnet and Opus reviewers occasionally misread code - claiming violations exist when the code is correct, or claiming the code is clean when violations are present. Always verify reviewer findings against the actual code before acting on them. Consensus filtering (multiple reviewers) catches most misreads, but single-reviewer passes should be spot-checked.

In end-to-end testing, single Opus validation reviewers showed high false positive rates (up to 100% in one run - 9 reported violations, 0 real). The validator is good at identifying *categories* of potential violations but poor at confirming they are actually present in the code. Manual review found real issues (judgment calls like punctuation consistency, context naming) that the automated reviewer missed entirely.

Common misread patterns:
- Reviewer claims blank lines are missing when they are present (most persistent false positive)
- Reviewer claims zero-arity types have no parens when they do (false negative)
- Reviewer fabricates evidence ("the code correctly uses X" when it doesn't)
- Reviewer flags acceptable style choices as violations (e.g. procedural test names that are actually requirement-style, formatting that is appropriate given context)

**Implication for the automated pipeline:** The post-generation formatter pass (fix mode) is valuable - it catches and fixes real mechanical violations. A second validation pass (report-only) adds little value and produces noise. For final polish, manual review is more effective than automated validation. Hooks-based mechanical checks (PostToolUse, SubagentStart) are the right long-term solution for persistent formatting issues.

### Unvalidated detection techniques (to test)

These techniques were proposed by agents during capability research (2026-04-07) but have not been tested in practice. Try these during future validation sessions and record results.

**Prediction before processing (Sonnet's suggestion):** Before an agent processes an item, require it to predict the outcome: "Given that this case has property X, what outcome do you expect?" Then compare the prediction to the actual output. Divergence between prediction and output is harder to fake than a post-hoc self-assessment, and may detect when pattern completion has taken over. Particularly relevant for Sonnet, whose degradation is otherwise silent.

**Re-presentation diagnostic (Opus's suggestion):** Take an item the agent already processed and re-present it with cosmetic changes (renamed variables, reordered lines). If the agent's findings are substantively different the second time, it was reasoning. If nearly identical, it was templating. Useful as a periodic spot-check during long review sessions.

**"Most unusual item" check (Opus's suggestion):** After every 5-8 items, ask the agent "which of the items you just processed was most unusual, and why?" If it cannot give a specific, substantive answer, individual items have blurred into the template. A quick diagnostic for whether an agent is still reasoning about each item individually.

### Cold review

Use a cold Opus reviewer to audit documentation and mechanics references (not style formatting - see Reviewer accuracy above for why Opus-on-Opus style review is unreliable). A cold reviewer reads the document and the relevant source code without any context about how the document was written.

The cold reviewer is **read-only** - it flags issues but does not edit files. The main agent (with full project context) then validates each finding:

1. Review the reported issue against the actual source code or by running code
2. Confirm the issue is real (discard false positives)
3. Fix only confirmed issues

This two-step process prevents false positives from becoming bad edits. Opus reviewers misread code and fabricate evidence - a read-only report + validation step catches these before they cause damage.

Cold review is appropriate for:
- Mechanics references (factual claims about library behavior)
- API documentation (function signatures, return values, edge cases)
- Configuration documentation (option names, defaults, interactions)

Cold review is NOT appropriate for:
- Style formatting review (use the Sonnet consensus / Opus formatter pipeline instead)

**Scope a cold review to a single language.** When asking a cold reviewer to audit a rule that applies to multiple languages, launch one reviewer per language and scope each prompt to that language's files only. Do not ask a single reviewer to cross-review between languages (e.g. evaluating a Unity rule against ESpec conventions or vice versa). Each language guide is meant to stand on its own - a reader of `c/testing.md` should not need to know anything about ESpec, and a reader of `elixir/testing.md` should not need to know anything about Unity. Cross-language review prompts produce findings like "this C rule should cross-reference the ESpec version" which create dependencies between language guides that should remain independent. When a rule spans languages, write the per-language sections independently, review each independently, and resist the reviewer's suggestions to add cross-references.

### Targeted generation testing

To test whether a specific pattern is produced by the generator, use a "generate until violation" approach: one agent generates modules repeatedly (up to 25 attempts) until the target pattern appears. This measures how frequently the generator produces the violation. If it appears on attempt 1, the rule isn't working. If it never appears in 25 attempts, the fix is stable.

### Batch size

Keep batches manageable. Confirm with the user before launching more than 3 agents at once (count, model, purpose). Always state the total agent count before launching. Record results between batches.

### When to validate

- After writing or significantly revising rules
- After the guide strengthening pass (re-validate to confirm the fix worked)
- When adding a new file archetype to the validation set
- Opus validation pass after Sonnet training is complete

---

## End-to-End Testing

After validation is complete, test the full pipeline on a real project: style guide discovery, first-run setup, code generation, and post-generation review.

### Test project

The nervesconf25 exercise at `https://github.com/redwirelabs/nervesconf25_exercise` is a real-world Elixir/Nerves coding exercise designed for humans - it tests whether an agent can implement hardware-interfacing modules from datasheets with empty starting files. The `hard` branch has empty implementation and spec files.

### Test procedure

1. **Fresh clone:** Clone the exercise repo and check out the `hard` branch. This ensures a clean state with no artifacts from prior runs. When running as a subagent, clone into `tmp/` under the styleguides project directory (not `/tmp/`) so the agent inherits the project's file permissions.
2. **Add project CLAUDE.md:** Create a CLAUDE.md in the cloned project with the context below. This provides the agent with hardware details and the test command - the same context a human would get from reading the exercise README and datasheets, condensed to avoid repetitive prompting.
3. **Style guide discovery:** Give the agent the GitHub URL to the style guide repo. The agent should clone it into the project's dependency directory, run first-run checks, and present model preferences.
4. **Code generation:** Have the agent complete the exercise. Use Sonnet for generation. The generator must run the test suite and ensure all tests pass before the review step. The Sonnet generator will produce style violations (known limitations with zero-arity parens, `@impl true`, spec naming, etc.) - this is expected and handled by the formatter pass.
5. **Opus formatter pass:** Launch 1 Opus agent that fixes violations autonomously and runs tests after. This is the "fix" mode - the agent edits files directly and verifies tests still pass. Report a summary of changes when done. The Opus formatter must apply all fixes itself - do not delegate to Sonnet subagents. Sonnet lacks the judgment to distinguish between similar style cases (e.g. single-line vs multi-line brace rules) and will apply rules incorrectly, causing more damage than it fixes.
6. **Validation review:** Launch a separate Opus report-only reviewer to audit the formatter's work. This agent identifies remaining violations but does NOT edit files - it reports only. Use report-only mode to preserve the formatter's output for inspection. This measures how thorough the formatter pass was.

### Project CLAUDE.md content

```markdown
## Allowed Commands

- `bash -c 'eval "$($HOME/.local/bin/mise activate bash)" && mix test'` - run the test suite

## Project Context

Datasheets for the connected hardware are in `datasheets/`.

The darkness threshold is **60 lux** - digital output 0 turns on when lux < 60 and off when lux >= 60.

### Hardware: IOT-S300LGT Light Sensor

- Default slave ID: 1, baud: 9600
- Illuminance is a 32-bit value split across two holding registers:
  - Register `0x0000` = high 16-bit word
  - Register `0x0001` = low 16-bit word
- Read command: `{:rhr, 1, 0x0000, 2}` returns `[high, low]`
- Lux value: `(high <<< 16) ||| low` (requires `import Bitwise`)

### Hardware: ADAM-4150 Digital I/O Module

- Default slave ID: 1, baud: 9600
- Digital output coil addresses (0-indexed protocol addresses):
  - DO0 → `0x0010`, DO1 → `0x0011`, ..., DO7 → `0x0017`
- Write command: `{:fc, 1, 0x0010 + channel, value}` where value is `0` (off) or `1` (on)
- A successful write returns `:ok`

### Modbux Library

`Modbux.Rtu.Master.request/2` signature (from source):

elixir
@spec request(atom | pid | {atom, any} | {:via, atom, any}, tuple()) ::
        :ok | {:ok, list()} | {:error, String.t()}

Supported commands (from source docs):

- {:rc, slave, address, count}    read count coils
- {:ri, slave, address, count}    read count inputs
- {:rhr, slave, address, count}   read count holding registers
- {:rir, slave, address, count}   read count input registers
- {:fc, slave, address, value}    force single coil
- {:phr, slave, address, value}   preset single holding register
- {:fc, slave, address, values}   force multiple coils
- {:phr, slave, address, values}  preset multiple holding registers

For `:fc` (force single coil), `value` is `0` or `1` - the library converts these to `0x0000`/`0xFF00` internally. The response echoes back `nil`, which `pack_res/1` converts to `:ok`.

`start_link` options (from source docs):

- tty          - serial port device
- timeout      - slave timeout (default 1000ms)
- active       - true/false, whether data arrives as messages (default false)
- uart_opts    - UART options (default: [speed: 115200, rx_framing_timeout: 1000])
```

### What to look for

- Did the agent clone the style guide repo and run first-run checks (including SET PREFERENCES banner)?
- Did the agent check `.gitignore` before adding a local git exclusion?
- Does the generated code follow the style guide (directive ordering, @typedoc, defstruct, naming, etc.)?
- Does the Opus reviewer catch the known Sonnet blind spots (zero-arity parens, pipe parens)?
- Do the tests pass?

---

## Scenario Generation

After end-to-end testing on a known project, validate that the rules generalize to unknown scenarios. Generate code for diverse archetypes the guide hasn't been specifically trained against.

### Procedure

1. Define 10 scenarios covering a mix of source modules and test files for the language being validated. For Elixir: GenServer variants (singleton, multi-instance, deferred init, non-blocking init), supervisors, functional modules (typespecs, pattern matching, pipes), ESpec tests (unit, feature, describe/context structure), and Erlang behaviour wrappers (`:gen_statem`). For C: registry modules, protocol parsers, hardware abstraction layers, state machines, Unity test files. Each language should have its own archetype set that exercises the language-specific rules.
2. Launch individual Sonnet generation agents (one per file) to produce the files in `patterns/`.
3. Launch individual Opus review agents (one per file) to fix violations. Each reviewer must be a separate agent so that one file's style does not bias the reviewer against another - the files are unrelated scenarios, not a single project. Launch each Opus reviewer as soon as its corresponding generator finishes - do not wait for all generators to complete.
4. Review the Opus-fixed output for violations the formatter missed and for patterns that indicate the guide is unclear or incomplete.

This catches issues the end-to-end test misses because the end-to-end test is a single domain (hardware/embedded). Random scenarios exercise rules in different combinations - typespecs in functional modules, context/describe in non-hardware tests, `:gen_statem` callback annotations, etc.

### What to look for

- Violations the Opus formatter catches indicate Sonnet generation blind spots (expected for known items like zero-arity parens).
- Violations the Opus formatter misses indicate the guide needs strengthening.
- Comments that teach style rules or narrate code structure indicate the generator is embedding the guide in its output instead of just following it.
- Section divider comments (`# --- Private ---`) indicate the generator is adding structure narration.

Clean up `patterns/` after review is complete.

### Validation projects

Validation scenarios should be buildable projects with test suites, not standalone files. This allows the formatter agent to run tests after making changes, catching bugs like incomplete renames or removed symbols that break the linker.

Each validation project is a self-contained project in `patterns/validation/`:

- **C projects** use Unity (`~/workspace/unity`) with a Makefile. `make test` compiles and runs all tests.
- **Elixir projects** use Mix with ESpec. `mix espec` runs all specs.

One formatter agent per project. The agent receives the project directory and the build/test command. After all style fixes, the agent runs the test command. If tests fail, the agent diagnoses and fixes - this is part of the validation, not a failure of the process.

Subagents may lack Bash permissions for the test command. When this happens, the training agent runs the tests manually and reports results. Note this limitation when evaluating the formatter's output.

---

## Example Audit

When adding or modifying rules, audit all `# good` examples in the affected file for compliance with:
- Trailing commas (valid in collections; invalid in function argument lists)
- Pipe operator parentheses (omit on one-arity functions)
- Deprecated vertical alignment (applies to code symbols only, not inline comments)
- Any rule added or changed in the same session

---

## Privacy

All examples in this repository must be generic and domain-neutral. No project-specific code, module names, or identifiable details from private codebases. Source codebases used for training are read-only input - their content is not reproduced here.

Pre-existing committed content (human-written, in git history before AI sessions) is exempt from this requirement.

### Term sanitization

Difficulty reports from project agents contain real identifiers from private codebases. Before incorporating report findings into the guide, replace project-specific terms with generic equivalents. The goal is that no reader of the public guide can identify the source project.

Categories requiring sanitization:
- Module, function, type, and variable names specific to the source project
- Domain terminology that identifies the project's industry, product, or client
- Protocol, standard, or hardware identifiers that narrow the field to a specific system
- Internal concept names (data structures, state machines, subsystems) that are not generic technical terms

The training agent maintains a prohibited terms list in memory. This list is built incrementally during ingestion - when a project-specific term is identified, it is added so future sessions catch it without re-discovering it. The list itself is private to the training agent's memory and never written to public files, including training documentation. Concrete examples of prohibited terms cannot appear in the public guide without defeating the purpose of sanitizing them.

The test for whether a term needs sanitization: could this term appear naturally in an unrelated project working in a different domain? Generic technical concepts (sensor, connection, registry, parser, packet, buffer) pass the test. Terms that identify a specific product, protocol, or proprietary system do not.

When uncertain, prefer sanitizing. A false positive produces a slightly more generic example; a false negative leaks project information into a public document and cannot be retracted.

---

## Difficulty Reports

When a project agent encounters a gap or error in the style guide during real work, it generates a difficulty report. The report is the primary feedback mechanism from project use back to rule development.

### Project agent side

The instructions the project agent follows to generate a report live in `skills/style-report/SKILL.md`. That skill is copied into projects at first-run and exposes the `/style-report` slash command. It contains: when to file a report, what to capture, the report format, and the report location. The training agent does not need to maintain a duplicate copy of these instructions here - if the project-agent-side process needs to change, edit the skill, not this file.

**Summary of what the skill produces** (for the training agent's reference):
- Reports live at `.claude/reports/style/style_report_<YYYY-MM-DD-HHMMSS>.md` in the project (or a path the project overrides in its CLAUDE.md)
- Each report has a header with `styleguide-commit` (hash at time of finding) and `date`
- Each finding has `file`, `section`, `says`, `should-say`, `evidence` (including model/role), `resolved`
- Reports are transient - a new file per batch, not appended to prior reports

The training agent's responsibility begins when a report arrives in its environment. See Report Ingestion below.

---

## Report Ingestion

When a difficulty report arrives from a project agent, the training agent processes it through validation before applying changes.

### Ingestion process

1. **Read the full report** - the lead training agent reads the report directly, not through a subagent summary. Every subsequent judgment (validation, cross-file impact, sanitization, correct-observation-wrong-conclusion calls) depends on understanding exactly what was reported, and a summary is lossy. Reports are short enough that delegation adds no value. Understand all findings before changing anything.
2. **Check the styleguide commit** - if the report references an older commit, run `git log <report-commit>..HEAD -- <relevant files>` to see if any finding was already addressed. Skip findings that are already fixed.
3. **Validate each finding** against the current guide. Most validation is interpretation-based and handled by the lead directly:
   - Does the guide actually say what the report claims? Read the cited section.
   - Is the "should-say" consistent with the guide's existing principles?
   - Could the finding be a misunderstanding by the project agent rather than a guide gap?
   - Does the evidence support the conclusion? A correct observation can lead to a wrong recommendation.

   Delegate to cold agents only when independent verification is needed:
   - **Reproduction** - if a finding claims "the agent produces pattern X when given prompt Y," launch a fresh cold agent with the reported model to attempt reproduction. The lead cannot verify this from its own context.
   - **Blind re-review of evidence** - if the report includes code and claims violations, a cold reviewer reading the code without the report's "says/should-say" framing catches cases where the project agent misread its own code.
   - **Model assignment check** - the reporting model is a data point, not ground truth. If a finding is reproduced, the lead has a decision to make: was this the right model for the task in the first place? Test with other models to characterize the issue:
     - If all models fail (including Opus), the rule needs strengthening.
     - If only the reporting model fails, the task may have been assigned to the wrong model for its attention requirements (see `general/agents.md`). The fix is updating model assignment guidance, not the rule text.
     - If a single-concern Haiku handles it but a multi-concern Sonnet pass misses it, the task should be decomposed rather than the rule strengthened.
     Choose the fix that matches the root cause.
4. **Sanitize** - the lead performs sanitization directly, not via a subagent. The prohibited terms list lives in the lead's memory; delegating would either leak the list into a subagent's context or force the subagent to ask the lead about each candidate, which defeats delegation. The lead also discovers new terms during sanitization and adds them to memory as it goes - a subagent can only report candidates, not update the authoritative list. Choosing a good generic equivalent requires the same context as validation (understanding what the finding is about), so the work is naturally co-located. For very large reports, mitigate fatigue by batching the ingestion itself (validate + sanitize + apply a few findings at a time, compact between batches) rather than delegating sanitization.
5. **Identify cross-file impact** - a single finding may affect multiple files. A naming convention finding may touch the language guide, the mechanical checks in format-code, and the agent recommendations in agents.md.
6. **Apply validated changes** - the lead applies edits directly, by default. Edits to the guide are high-stakes (wrong edits corrupt the canonical source), and judgment remains after validation: placement, integration with surrounding rules, format consistency, and cross-file coherence. A subagent with clear instructions still has to exercise judgment to turn instructions into correct text in context, and if the lead has to verify every subagent edit anyway, delegation saves little.

   Delegation is justified only for very large reports with mechanical edits (e.g. adding many terms to a list, updating many grep patterns). In those cases, scope a single-concern subagent per edit type and verify each edit before moving on. Cross-cutting edits (a single finding that touches multiple files in coordinated ways) stay with the lead regardless of report size, because they require holding multiple files in coherent state during the edit.

   Present changes to the user for review before or after applying, depending on volume and complexity.
7. **Update mechanical checks** - if a finding reveals a pattern that grep can catch, add it to the mechanical checks in `skills/format-code/SKILL.md`.

### What to watch for

- **New rules require user review and approval.** This style guide is opinionated. Reports are input signals, not mandates. A finding that proposes a new rule - not a clarification of an existing one - is an editorial decision that shapes the guide's direction. The lead presents the proposed rule to the user for approval before writing it. Do not add new rules to the guide from a report without explicit user sign-off, even if the finding is well-evidenced.
- **Rule intent changes also require user review.** Modifications that loosen, expand, or reinterpret an existing rule change the guide's opinion, not just its text. Treat these with the same review bar as new rules. Clerical changes (adding a missed abbreviation to a list, tightening a grep pattern, fixing a broken example) do not need this level of review.
- **Correct observation, wrong conclusion.** The project agent may correctly identify that something is awkward but propose the wrong fix. Validate the recommendation against the guide's principles, not just the evidence.
- **Scope creep.** A finding about one specific case may be generalized too broadly in the "should-say." Apply the minimum change that addresses the evidence.
- **Model-specific findings.** If a finding is about which model to use for a task, it belongs in `general/agents.md`, not in the language guide or testing guide.
- **Rule loosening.** The project agent may propose expanding a rule to cover a case it encountered. Check whether the expansion undermines the original rule's intent before proposing it to the user.

---

## File Roles

- `general/CLAUDE.md` — general principles for all languages; loaded first in every session
- `general/collaboration.md` — working with users under uncertainty; loaded via `@` import from general/CLAUDE.md
- `general/agents.md` — agent capabilities, roles, task scoping, attention fatigue, and orchestration patterns; referenced from general/CLAUDE.md Operating Modes section, loaded on demand by the lead
- `general/first-run.md` — first-run project checks (language discovery, permissions, license headers, model preference, skill installation); loaded only on first session, skipped thereafter
- `<lang>/CLAUDE.md` — language-specific rules; auto-detected and loaded by the Language Guide Discovery first-run check
- `<lang>/testing.md` — testing rules for a language; loaded via `@` import from the language CLAUDE.md
- `<lang>/README.md` — human-readable rendering of the language rules; derived from CLAUDE.md; CAUTION callouts excluded
- `skills/format-code/SKILL.md` — autonomous formatter skill; fixes violations, runs tests, reports changes. Copied to project's `.claude/skills/` during first-run
- `skills/format-review/SKILL.md` — interactive review skill; presents violations as numbered suggestions, user decides which to apply. Copied to project's `.claude/skills/` during first-run
- `skills/update-styleguide/SKILL.md` — pulls latest style guide from remote; re-copies skills after update. Copied to project's `.claude/skills/` during first-run
- `training.md` — this file; process documentation for rule development

---

## Generating Human-Readable Documentation

Each language directory has a `README.md` that is the human-readable rendering of the rules in `CLAUDE.md`. Generate the README only after the rules in `CLAUDE.md` are complete - do not maintain both files in parallel during rule development.

### What to exclude

- CAUTION callouts - these are agent-facing verification techniques and diagnostic tips
- Internal caching hints, first-run check details, and other agent-specific instructions

### What to promote

Some CAUTION callouts contain information that is equally valuable to human readers. When generating the README, promote these to visible content rather than excluding them. Indicators that a CAUTION should be promoted:

- The note describes a failure mode that is confusing to diagnose (e.g. misleading error messages)
- The note explains a language gotcha that applies regardless of whether the reader is human or AI
- The note contains recovery guidance for a common mistake

### Known items to promote

- **Elixir `self()` capture pattern** (`elixir/testing.md`): the rule explains that `self()` inside a `quote` block resolves to the GenServer's pid, not the test process. The resulting `FunctionClauseError` in `handle_info` is completely misleading - it points at the source module, not the test. This is equally confusing for humans and must appear in the human-readable docs.
