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
2. **Pattern file** — write code examples to a `.c` (or language-appropriate) file in `patterns/` for user review. The user will edit formatting or add comments to clarify the rule.
3. **Document and record** — once the user approves, write the rule into the language's `CLAUDE.md` (e.g. `c/CLAUDE.md`) following the standard rule format: intent, convention, examples (`// good` / `// avoid`), when to deviate. Update memory with which rules are complete.
4. **Validate examples compile** — verify that all `// good` examples in the section actually compile and run correctly. Build a test file with scaffolding (type stubs, dummy functions) that includes the examples as real code. If an example doesn't compile, fix it. Examples that don't compile teach agents broken patterns.
5. **Next rule or section validation:**
   - If more rules remain in the section, repeat from step 1 with the next rule.
   - If the section is complete, run a cold Sonnet agent to generate code following the documented rules. Refine rules until the agent writes correct code.
6. **Cold Opus review** — run an Opus cold reviewer that audits all examples against all rules (not just the rule they demonstrate). The main agent validates each finding, implementing only confirmed improvements. If any changes affect agent behavior, return to step 5 and retest with a cold generation agent.
7. **Checkpoint** — review session context, ensure all knowledge is documented. Mark the section complete and update memory.

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

1. Define 10 scenarios covering a mix of source modules and test files: GenServer variants (singleton, multi-instance, deferred init, non-blocking init), supervisors, functional modules (typespecs, pattern matching, pipes), ESpec tests (unit, feature, describe/context structure), and Erlang behaviour wrappers (`:gen_statem`).
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

All examples in this repository must be generic and domain-neutral. No project-specific code, module names, or identifiable details from private codebases. Source codebases used for training are read-only input — their content is not reproduced here.

Pre-existing committed content (human-written, in git history before AI sessions) is exempt from this requirement.

---

## File Roles

- `general/CLAUDE.md` — general principles for all languages; loaded first in every session
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
