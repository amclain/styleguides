@general/collaboration.md

# General Style Guide

This is Alex's AI-native code style system, designed to be used with Claude Code. This file defines style principles that apply across all languages. Language-specific rules are in `<lang>/CLAUDE.md`.

## Philosophy

This system replaces mechanical formatters and linters. Mechanical tools apply rigid rules blindly — they often degrade readability by following prescribed patterns without understanding intent. This system reviews code the way a skilled human reviewer would: applying rules contextually, offering soft suggestions, and deferring to the author's judgment.

**Precedence in the codebase takes priority over this guide.** When in doubt, follow the style of the existing code. A project that presents itself as a consistent piece of work is easier to read than one that follows global rules but clashes with itself.

- Rules serve readability. If following a rule makes code harder to understand in a given context, don't apply it.
- Local coherence takes priority. Code that fits its surrounding context is preferable to code that follows a global rule but clashes with what's around it.
- Suggestions, not mandates. The reviewer suggests; the author decides.
- Explain on demand. Default output is terse (a numbered list of suggestions). Reasoning is available if asked.
- Whitespace is a tool. Use it to move the reader's eye through the code and accentuate areas of importance — not excessively, but purposefully.

The system has two operating modes (review and fix) — see **Operating Modes** below for behavior details.

## Loading Style Guides

When reviewing or generating code in any language, load the relevant guides before proceeding:

1. Read `general/CLAUDE.md` (this file) — general style principles that apply to all languages.
2. Read `<lang>/CLAUDE.md` — rules specific to the language being reviewed or written.
3. When test code is in scope, also read `general/testing.md` (cross-language testing principles) and `<lang>/testing.md` (language-specific testing rules).
4. When orchestrating multi-agent style review, also read `general/review-orchestration.md`.
5. When building a custom project-side review pipeline that composes style review with other project-owned review types (logic, security, tests, docs, etc.), `general/review-pipeline.md` offers optional reference patterns for the project's outer orchestration. Not required for the styleguide itself.
6. When working with agent orchestration, capabilities, or fatigue, also read `general/agents.md`.

Detect the language from context: file extension, syntax, or what the user states. Do not wait to be asked — load the guides proactively whenever a style task is underway. None of the files above are propagated to subagents via `@` import (only `general/CLAUDE.md` and the project's CLAUDE.md are `@`-imported and reach subagents through the parent's `claudeMd` snapshot — see `general/agents.md` § Context Distribution Mechanisms). Files loaded on demand are read directly by whichever agent needs them; if a subagent needs a load-on-demand file, list its path in the dispatch prompt so the subagent can Read it.

## Reading This Guide

Any agent applying this guide must read it in full. Do not skim, do not rely on training-data patterns for the language, and do not substitute common conventions from other style guides for the text below. When loading a guide file, use a single Read call per file with no offset or limit.

If the Read tool errors that the file exceeds its size limit, read the file in sequential chunks via `offset`+`limit` parameters and treat the union of those reads as a single full read. Do not skip the file. Do not read only part of it. Chunked reads must cover the file end to end.

Training data is wrong about this project's conventions in specific ways that this guide documents explicitly. Relying on training data is the most common failure mode for style review and code generation agents. It produces output that cites rules this guide does not contain, misses rules this guide does contain, and applies conventions from unrelated languages.

This rule applies to every agent role that interacts with the guide:

- **Code generation agents** load the guide before writing code, not after. Generating first and then checking against the guide is not equivalent - the guide shapes the output, it does not filter it.
- **Review agents** (including post-generation review and style review) load the guide before evaluating code. Every finding must reference a rule name from the loaded files; if an agent cannot cite a rule from the guide, it is not applying the guide.

**Which files to read** depends on the task context - the entry point (project CLAUDE.md `@` import, `skills/format-code/SKILL.md`, or `general/review-orchestration.md`) lists the specific files required for that task. This section defines *how* to load, not *which* files.

**Detection**: if an agent produces output that cites a rule not present in the loaded files, or uses terminology from a different language's guide, it did not read the guide and its output is unreliable. Retry the task after verifying the agent performs the required Read calls.

## Operating Modes

Running `mix format` (or the equivalent for the language) invokes the AI reviewer. Two modes are available:

- **Review mode** (`format-review` skill): a numbered list of suggestions for the user to accept or reject. Nothing is changed until the user asks.
- **Fix mode** (`format-code` skill): violations are corrected autonomously. This is also the default for post-generation review after an agent writes code — cleaning up an agent's own output does not require per-change user approval.

The user controls which mode applies. `format-review` is the interactive default when the user runs a style review themselves; `format-code` is what post-generation review invokes automatically.

The agent determines the active mode from context (the user's request, the trigger phrase, or the task at hand). Check memory for the user's model preferences for each mode - see `general/first-run.md`. For guidance on which models to use for which tasks, agent roles, and multi-agent orchestration, see `general/agents.md`.

### Code Generation

Sonnet is the default for code generation. Code logic and correctness are equivalent across models - Sonnet writes the same algorithms and data structures as Opus. Opus produces fewer style violations during generation because it holds more rules active simultaneously, but the post-generation review pass catches these regardless of which model generated the code. Sonnet is faster and lower cost for generation, with the known style blind spots handled by the review step.

The generating agent cannot accurately review its own code due to context bias from the generation phase. This is the primary reason generation and review are separate agents, not a quality difference between models.

**If the current session is running Opus and code generation is requested:** inform the user once that Sonnet produces equivalent code logic at lower cost, and that style compliance is handled by the review pass. Ask the user to confirm before proceeding with Opus generation. Save their decision to memory so this prompt is not repeated.

When generating new code, apply the rules in this guide and the loaded language guide proactively. Do not wait to be asked.

**Subagent context inheritance.** Subagents launched via the Agent tool inherit a snapshot of the parent's `claudeMd` system-reminder block, captured at parent session start. The snapshot includes the global `~/.claude/CLAUDE.md`, the project's `CLAUDE.md`, every `@`-imported file resolved at session start, and the project `MEMORY.md`. Subagents do NOT inherit the parent's conversation history or files the parent has Read but not `@`-imported.

The snapshot is taken once and reused for every subagent dispatch in the parent session. Edits to `@`-imported files (or MEMORY.md) mid-session do NOT propagate to subagents launched later in the same session - those subagents still see the original snapshot. To pick up edits, restart the parent session.

Practical implication: the general style guide IS visible to a subagent because `general/CLAUDE.md` is `@`-imported by the project's CLAUDE.md and reaches the subagent through the parent's `claudeMd` snapshot. The language guide and other on-demand files (`<lang>/CLAUDE.md`, `<lang>/testing.md`, `general/testing.md`, `general/review-orchestration.md`, `general/review-pipeline.md`, `general/agents.md`) are NOT in the snapshot — they are loaded by Read calls when needed. If a subagent must apply rules from one of those files, list its path in the dispatch prompt so the subagent can Read it. If a guide file was edited mid-session and a subagent must see the new content, either restart the parent session (for `@`-imported files) or pass the changed content explicitly in the dispatch prompt.

**Delegated generation.** When delegating code generation to a subagent, list in the dispatch prompt only the files NOT covered by `@` imports - typically mechanics references for frameworks the generated code will use (e.g. Unity, ESpec, a DI library), design docs, and the code under review or being modified. Use absolute or repo-relative paths so the subagent can Read them directly. State the target language so the language guide load is unambiguous. Failing to pass non-`@` references the subagent needs produces training-data-default code that the review step has to rewrite - this is waste, not a caught-safely failure mode.

**Multiple options:** when code complexity is high and more than one approach is appropriate, present the options with trade-offs rather than prescribing one answer. Limit to 2-3 choices - 1 or 2 is best.

### Post-Generation Review

After completing a code generation task (not after every function - after the full task is done), run style review on the generated code. This catches patterns the generation step consistently misses due to training-data bias (e.g. zero-arity type parentheses, pipe operator parentheses) and enforces the guide contextually.

**Who runs the review.** The project lead - the agent that owns the session - runs the review directly by invoking `skills/format-code`. It does not spawn a separate subagent to act as review lead. Claude Code's agent model forbids nested orchestration (subagents cannot launch subagents - see `general/agents.md`), and the reviewer subagents at Tasks 1.1 through 1.6 must be launched by the lead. See the "Integrating this framework from a larger orchestration" section at the top of `general/review-orchestration.md` for the full architecture and rationale.

**Bias check.** The generator-bias principle (`general/agents.md` - Warm vs Cold Agents - Bias Risk) targets agents that wrote the code being reviewed. If the project lead delegated code generation to a subagent, the project lead has no generator bias - it did not author the code - and is the correct agent to run review. The cold-review property lives at the reviewer-subagent layer (Tasks 1.1 through 1.6), which the framework runs cold by design: each reviewer starts fresh, loads only its required reading, and has no project context.

If the project lead itself wrote the code (no generation subagent was used), the generator-bias concern applies to the *generation* step, not to the review step: running fresh reviewer subagents for Tasks 1.1 through 1.6 still provides the cold-review property for each finding. The project lead's role is to orchestrate the review and apply fixes, not to generate findings.

**What the review does.** The project lead applies fixes directly - this is fix mode, not suggestion mode. Post-generation review is a cleanup pass on code the agent just produced, not a review of the user's code. After applying fixes, the project lead runs the project's test suite to verify the fixes did not break anything. Style corrections are formatting-only and must not change behavior. If tests fail after fixes, diagnose and correct.

**Scope of "lead applies fixes directly."** This rule fires at one specific step in the framework's procedure: between the reviewer dispatch round (Tasks 1.1-1.5, dispatched as subagents) and the post-edit verification round (Tasks 1.1 post-edit + 1.6, also dispatched). See `general/review-orchestration.md` § 2 Dependency Graph — the arrow "Lead applies fixes → 1.1 (post-edit) → 1.6 → Lead applies verification fixes" is the structural location where the lead's fix-application step sits, bracketed by dispatches on both sides. The rule does not generalize to "the lead does the whole workflow hands-on." Reviewer tasks are always dispatched as subagents (Tasks 1.1-1.6 per the framework); the cold-context property of fresh dispatches is what those tasks preserve, and inlining them in the lead's context destroys the property the framework is built on. Per `general/agents.md` § Framework Pattern, the lead's role is mechanical execution against a manifest (Step 4 of `general/review-orchestration.md` § 3) — launching reviewer subagents from the manifest IS the lead's mode, not a deviation from doing the work. Within the fix-application step itself, mechanical execution may include batch tools the lead invokes against its own consolidated finding set (a script that applies a textual transformation across many findings, with semantics preserved and verified by the test suite) — those tools are the lead's mechanical execution at that step, not a delegation of judgment. The mechanical/judgment distinction applies per-finding: a script the lead runs against a class of findings the lead has already classified is fix-application; a Sonnet subagent asked to decide which findings are real violations is delegation, which is what the rule bans. When a project wraps style review in its own custom multi-review-type pipeline, the project's outer orchestration may run cross-stage fix-application as a dispatched Sonnet group instead of lead-inline work (see `general/review-pipeline.md` § Fix-application is its own group). That is a project-side workflow choice for cross-stage fix-application across multiple review types' findings; it does not modify how this framework's own fix-application step runs when style review executes.

Report a summary of what was changed (file, rule, what was fixed).

**Model preference.** The user's preferred review model is saved in memory from the first-run check. If it differs from the generation model (e.g. generate with Sonnet, apply review with Opus), the difference matters for the reviewer subagents that do require judgment (Task 1.5 is Opus-only regardless of user preference; other tasks use Haiku or Sonnet per the framework). Skip post-generation review entirely if the user has opted out.

### Style Review

Style review is triggered by the language formatter plugin (e.g. `mix format`) which launches an interactive Claude Code session with this style guide pre-loaded. The trigger phrase in the initial prompt controls review behavior:

| Trigger phrase | Behavior |
|---|---|
| `style review <lang>` | Review changed code only (default) |
| `style review <lang> --all` | Review entire codebase |
| `style review <lang> --rewrite` | Apply the style guide as written; do not defer to codebase precedence. Typical use: a freshly scaffolded project whose existing patterns should be rewritten, not learned from. `--styleguide-precedence` is an accepted alias. |

When reviewing code, default to scoping suggestions to changed lines only. Run `git diff` and `git diff --staged` to identify what changed; read the full file for context; flag issues only in the changed lines. This mirrors how a human reviewer works on a pull request. The entire codebase can also be reviewed if the user asks - this is not the default. The user's preferred review model is saved in memory from the first-run check.

Style review is a multi-agent workflow with specific task decomposition, model assignments, and ordering constraints. The full orchestration framework is in `general/review-orchestration.md`. The lead agent (the agent acting on the user's request) must load that document before launching review work - it defines task types, required reading per task, scope handling, group cohesion exceptions, and quality signals. Do not improvise the orchestration based on prior knowledge; the framework captures specific failure modes that generic review approaches miss.

This system is intended to replace mechanical formatters (e.g. `mix format`, `rubocop`, `clang-format`). Unlike mechanical tools, it applies rules contextually and understands intent.

If the user asks what capabilities are available, describe all options:
- Review changed lines only (default)
- Review the entire codebase
- Apply any suggestion directly
- Explain the reasoning behind any suggestion

**Output format:** a terse numbered list of suggestions. Reasoning is available if asked ("explain #N").

**Applying suggestions:** if the user asks you to apply a suggestion or act as a formatter, make the change directly. The default is to suggest; applying is opt-in.

**Git operations are read-only.** Formatter skills (style review, post-generation review, `/format-code`, `/format-review`, `/format-rewrite`) may read git state (`git status`, `git diff`, `git log`, `git check-ignore`) to determine review scope, but never write git state. Do not `git add`, `git commit`, `git stash`, `git restore`, `git checkout <file>`, or any other operation that mutates the repo or working tree. After applying fixes to files, report what changed and stop - the user reviews with `git diff` and commits on their own. This constraint applies to every formatter skill.

---

## Rule Format

Each language's `CLAUDE.md` defines rules in this structure:

```
### Rule Name

**Intent**: what this achieves for the reader

**Convention**: the preferred pattern

**Example**:
  # good
  ...

  # avoid
  ...

**When to deviate**: conditions where the rule should not be applied
```

---

## File Roles

Each language directory maintains two files:

- **`CLAUDE.md`** — source of truth. AI-friendly. May contain CAUTION callouts and implementation guidance not intended for human readers.
- **`README.md`** — human-readable rendering of the same rules. CAUTION callouts and internal guidance are excluded. Rendered automatically by GitHub when browsing the directory.

`CLAUDE.md` is authoritative. `README.md` is derived and regenerated whenever `CLAUDE.md` changes.

---

## Repository Structure

Use this to navigate to the file you need. General principles live at the top; language-specific rules live in the language directory; cross-cutting concerns (testing, agent orchestration, collaboration) have their own files loaded on demand.

```
general/
  CLAUDE.md          # General style principles applying to all languages (this file)
  collaboration.md   # Working with users under uncertainty (loaded via @ import)
  agents.md          # Agent capabilities, roles, scoping, and fatigue (loaded on demand)
  first-run.md       # First-run project checks (loaded once, skipped thereafter)
  testing.md         # General testing principles (loaded when tests are in scope)
  review-orchestration.md  # Multi-agent style review framework (loaded by formatter skills)
  review-pipeline.md       # Optional reference for projects building a custom multi-review-type pipeline
c/
  CLAUDE.md          # C style rules
  testing.md         # C testing rules (loaded on demand when test code is in scope)
  README.md          # Human-readable rendering
elixir/
  CLAUDE.md          # Elixir style rules
  testing.md         # Elixir testing rules (loaded on demand when test code is in scope)
  README.md          # Human-readable rendering
ruby/
  CLAUDE.md          # Ruby style rules
  style.rb           # Existing human-written style guide (referenced by CLAUDE.md)
skills/
  format-code/       # Autonomous formatter (fix mode)
  format-review/     # Interactive reviewer (suggestion mode)
  format-rewrite/    # Rewrite codebase to guide; skips codebase precedence (user-invoked only)
  style-report/      # Difficulty-report generator (project-agent-facing)
  update-styleguide/ # Pull latest style guide from remote
```

---

## First-Run Project Checks

Check memory for existing first-run results (style guide import, language detection, style guide permissions, license headers, model preferences). If all are present, skip this section. If any are missing, read `general/first-run.md` (in the same directory as this file) and execute the missing checks.

---

## Naming

### Precision Over Length

Names should be precise, not long. Adding more words to a name does not make it more descriptive — it dilutes the meaning until nothing remains. Choose the most accurate name in the fewest words. A name that requires a comment to explain it is a signal to find a better name.

A name is read in context. Information already visible in the surrounding code — adjacent expressions, patterns, type annotations — does not need to be repeated in the name. Encoding what the reader can already see is noise, not precision.

CAUTION (detokenize): Abbreviations and grammar problems are invisible when reading identifiers as code tokens. To evaluate naming quality, split the identifier into words and read them as an English phrase. The split method depends on the convention: replace underscores with spaces for `snake_case`, insert spaces at case boundaries for `PascalCase` and `camelCase`, replace hyphens with spaces for `kebab-case`. Examples: `src_port` → "src port" → abbreviated. `source_port` → "source port" → full words. `SrcPort` → "Src Port" → abbreviated. `SourcePort` → "Source Port" → full words. `sensor_reading_range` → "sensor reading range" → bare noun phrase, no verb. `allows_exact_match` → "allows exact match" → complete proposition.

**Reader test for documentation about a name.** When deciding whether a comment about a name is needed (or whether an existing comment is redundant), apply the same lens — read the name as English — and apply this gate:

If the detokenized name reads as a complete noun phrase that a domain-aware reader of this code would recognize, **do not add a comment**. The reader has the name, the type, and the enclosing context; that combination is the documentation. A comment that translates the identifier into a synonym, restates the type, or speculates about how a reader "might still" need explanation fails the gate. The default is bare; a comment is the exception, justified only when the detokenized name leaves a question a domain-aware reader cannot answer from name + type + enclosing context.

Common failure mode to guard against: **plausibility-matching**. After detokenizing the name, the reviewer asks "could a comment plausibly add useful information here?" and answers yes by inventing a question the name does not actually leave open ("a reader might want to know the units"; "a reader might want to know the relationship to the sibling field"; "a reader might want to know which audience uses this"). If the question only emerges after speculating about what a reader might want, the question is the reviewer's, not the reader's. Drop the comment.

**The same gate applies to prose review.** When evaluating prose — comments, docstrings, design docs — for defects, detokenize every identifier in the phrase, read the result as English, and apply the grammar-and-meaning check. Flag a phrase only when its English reading fails: a sentence whose grammar breaks, an argument that depended on a distinction the surrounding code no longer expresses, a comment whose explanation now implies the wrong thing. **Lexical echo of an identifier in surrounding prose is not by itself a defect.** When an identifier shares a root with a word in the comment or docstring around it, the gate is still whether the detokenized phrase makes sense — not whether the morphology overlaps. "Managed" the workflow name and "caller-managed" the past participle detokenize to distinct English phrases that both parse correctly; a renamed enum member sharing a stem with a noun in its comment, or a renamed function sharing a stem with a verb in its docstring, are the same shape. This applies whether the prose is being reviewed in isolation or after a bulk rename — the gate is the same.

**Sibling disambiguation.** Before flagging a compound noun as redundant, check whether the qualifier distinguishes this identifier from a sibling identifier in the same module or scope. A library exposing both `producer_init` and `consumer_init` makes `producer` load-bearing in `test_ring_is_empty_after_producer_init` - dropping it leaves the reader unable to tell which init path is the subject. A qualifier that distinguishes from a sibling is disambiguation, not noise.

**API-identifier composition.** When an identifier contains a reference to another API (a test name that mentions the macro it exercises, a wrapper that names the function it wraps), read those tokens as the API reference they are, not as separate English words. `test_assert_called_passes_when_mock_was_called` detokenizes to "TEST_ASSERT_CALLED passes when mock was called", not "assert called passes when mock was called" - the `assert_called` tokens compose a reference to the `TEST_ASSERT_CALLED` macro under test. The detokenize check applies to the proposition's grammar (is it complete? are non-API tokens abbreviated?), not to the API reference within it. When the referenced API is conventionally ALL_CAPS (a macro, a `#define`), preserving the original casing in the identifier (`test_TEST_ASSERT_CALLED_passes_when_mock_was_called`) makes the API reference visually unambiguous - the all-caps token cannot be mistaken for English. Mixed case inside a single C identifier is uncommon, but the visual distinction between a `test_` prefix, an all-caps API name, and a lowercase scenario description is the disambiguator. Apply this only to test-framework libraries and similar cases where tests are written about APIs whose idiomatic spelling is ALL_CAPS.

### Domain Terms vs. Arbitrary Abbreviations

Language guides list accepted short forms and prohibited abbreviations, but the lists are not exhaustive. When a project-owned identifier uses a short form not on the accepted list, classify it using the external-API test:

> Does the framework, OS, library, or protocol the code integrates with use this short form in its own public API (function signatures, type names, specification text)?

If yes, the short form is a **domain term** - using the full word in project code would diverge from the external API's vocabulary and create a naming mismatch at every integration boundary. Keep the short form. If no - the external API spells out the full word and the short form exists only in consuming project code - it is an **arbitrary abbreviation** and the full word should be used.

```
# good - the external API uses the short form in its own types and functions
# (e.g. an external_handle_t type, external_handle_reserve function), so
# project code matches the API's vocabulary
external_handle_t queue_request_handle

# avoid - the external API spells out the term
# (e.g. external_notification_alloc, external_notification_t), so project
# code should too - the short form "notif" appears nowhere in the external API
external_handle_t queue_notif_handle
```

The test applies only to identifiers the project authors. It does not apply to references to external symbols themselves - an external function keeps whatever name its author gave it, full word or abbreviated, and is not subject to style review (see `general/review-orchestration.md` Task 1.3 scope rule).

This rule is the principle behind every language guide's accepted-short-form list. The language guide pre-classifies the common cases (e.g. `ptr`, `fd`, `fn` in C; others per language); this rule handles everything the language guide did not pre-classify.

### Opposing Pairs

When naming related pairs - functions, events, states, labels, or any paired actions - use opposing names that mirror each other. Seeing one half of the pair should immediately tell the reader what the other half is called.

```
# good - opposing names mirror each other
connect / disconnect
register / unregister
enable / disable
open / close
start / stop
acquire / release
subscribe / unsubscribe

# avoid - unrelated words obscure the pairing
register / release
open / destroy
acquire / free
```

**When to deviate**: When a domain or protocol defines an established pair that doesn't follow the mirror pattern (e.g. `malloc`/`free`, `listen`/`accept`), use the established terms. Precedence in the domain takes priority.

---

## Functions

### Function Size and Responsibility

A function should be small enough to hold in your head. When a function grows beyond what a reader can mentally contain, they slow down, introduce more defects, and hesitate to make changes — that hesitancy is how legacy code is born.

A function should be complete, clear, and concise — in that order of priority. Do not sacrifice completeness or clarity for brevity. When a function grows long because it is mixing responsibilities, decompose it into smaller functions that each own a single responsibility. The names of those functions document the steps.

There is no hard line count, but a function approaching 50 lines is a signal to examine whether it is doing too much. Under 20 lines is not necessarily a reason to split — only split when it improves clarity by separating distinct responsibilities.

Extracting helpers gives a meaningful name to a non-obvious step. Do not extract when the helper is so trivial that the indirection adds noise without adding meaning.

### Assertions vs. Return Values

When designing an API's error-return surface, the distinguishing question is: can the library assert against this condition at generation time? If yes, use an assertion (language-appropriate: `assert`, `panic!`, `raise`, `BUG_ON`, `log.Fatal`). If no, use a return value.

"Cannot assert" has two forms:

1. **Structural** — the API's contract hands control to the caller in a way that prevents enforcement. A direct pointer into caller-writable memory, a callback the library invokes, shared memory a counterparty can write. The library has no syntactic point where it can verify the invariant.
2. **Trust-boundary** — the data enters from a counterparty in a different trust domain, where "counterparty may be compromised" is part of the design. The library must validate untrusted input and surface failures for caller recovery.

Both forms produce legitimate runtime failures the caller must be able to act on. A single failure mode can sit under both forms at once; either alone justifies a runtime status. For everything else — conditions the library could assert against at generation time on a correct build (config parsing, geometry, wiring, manifest consistency) — use an assertion.

A public API that returns a status for an unrecoverable condition creates three problems: (1) every caller writes an `if (status != OK)` branch that is unreachable by construction, (2) reviewers and future maintainers cannot tell by inspection whether a branch is live or dead, and (3) the spec is quietly pressured to describe error behavior to match the code, rather than the code matching the spec. Assertions crash quickly so a build-time mismatch is spotted at the first run.

```c
// avoid - returns a status for a calibration-parsing error that a correct build cannot trigger
sensor_status_t sensor_init(sensor_t *s, const char *manifest) {
  if (!parse_calibration(manifest, &s->calibration)) {
    return SENSOR_MALFORMED;
  }
  // ...
}

// good - assert; the manifest is generated at build time, malformed input is a build error
void sensor_init(sensor_t *s, const char *manifest) {
  assert(parse_calibration(manifest, &s->calibration));
  // ...
}
```

```rust
// avoid - Result for an unrecoverable calibration error
fn sensor_init(manifest: &Manifest) -> Result<Sensor, SensorError> {
  let calibration = parse_calibration(manifest).ok_or(SensorError::Malformed)?;
  // ...
}

// good - panic on the unrecoverable case
fn sensor_init(manifest: &Manifest) -> Sensor {
  let calibration = parse_calibration(manifest).expect("malformed manifest");
  // ...
}
```

```elixir
# avoid - {:error, _} for an unrecoverable calibration error
def sensor_init(manifest) do
  case parse_calibration(manifest) do
    {:ok, calibration} -> {:ok, %Sensor{calibration: calibration}}
    :error -> {:error, :malformed}
  end
end

# good - raise on the unrecoverable case
def sensor_init(manifest) do
  calibration = parse_calibration!(manifest)
  %Sensor{calibration: calibration}
end
```

**When to deviate.** During the design phase where an API's recoverability is still being negotiated, return a status until the contract is settled. When a caller genuinely needs to distinguish "unrecoverable but orderly shutdown" from "immediate crash" and the platform provides a way, a status enum can carry that distinction.

---

## Naming Values

### Magic Numbers and Literals

Replace magic numbers and literals with a named constant or local variable when the name adds context that the raw value lacks, or when the value is used in multiple places. Use a named local variable when the value is used locally — this keeps the name physically close to its usage and avoids unnecessary scrolling. Use a module-level constant when the value is shared across functions or represents a configuration value.

Do not extract when the value is idiomatic to the language — where any familiar programmer understands it in context — or when extracting creates separation that makes the code harder to follow than leaving the value inline.

The purpose of naming a value is improved understanding. If the name adds no information beyond what the value already communicates, the extraction is noise.

```elixir
# good — local variable names the threshold close to its use
airflow_threshold_cfm = 20
if airflow_in_cfm > airflow_threshold_cfm ...

# good — module constant for a shared configuration value
MAX_RETRY_ATTEMPTS = 3

# acceptable — idiomatic, any programmer knows sleep takes milliseconds
Process.sleep(5000)

# avoid — constant name adds no information, creates unnecessary separation
@delay_in_ms 5000
...
def pause do
  Process.sleep(@delay_in_ms)
end
```

```c
// good - local variable names the threshold close to its use
int airflow_threshold_cfm = 20;
if (airflow_cfm > airflow_threshold_cfm)
  set_mode(MODE_NORMAL);

// good - #define for a shared configuration value
#define MAX_RETRY_ATTEMPTS 3

// acceptable - idiomatic, any C programmer knows what 0 and -1 mean
return 0;
return -1;

// avoid - constant adds no information
#define ZERO 0
return ZERO;
```

A comment explaining what a literal value means is a signal that the value should be a named constant. The comment is doing the constant's job. Define the constants and let the names speak for themselves.

```c
// avoid - comment is doing the constant's job
build_frame(buffer, sizeof(buffer), 0x02, // SYN
  payload, payload_length);
TEST_ASSERT_EQUAL_UINT8(0x14, flags); // RST | ACK

// good - named constants are self-documenting
#define TCP_SYN  0x02
#define TCP_RST  0x04
#define TCP_ACK  0x10

build_frame(buffer, sizeof(buffer), TCP_SYN, payload, payload_length);

TEST_ASSERT_EQUAL_UINT8(TCP_RST | TCP_ACK, flags);
```

CAUTION: Magic hex values in test code are easily missed during review, especially protocol constants. Inline comments like `// SYN` or `// PSH|ACK` next to hex literals are the strongest signal - if the value needs a comment to explain it, it needs a name instead.

---

### Named Boolean Expressions

When a boolean condition is complex (multiple comparisons, logical operators), extract it to a named boolean variable. The name documents the intent of the condition. The `if` statement then reads as a simple question.

```c
// good - named booleans make the if statement a simple question
bool is_bad_request =
  header_decode(buffer, index, &call) < 0
  || call.action == ACTION_UNKNOWN
  || call.object_type == TYPE_UNKNOWN;

if (is_bad_request)
  return -1;

// avoid - complex condition inline in if
if (
  header_decode(buffer, index, &call) < 0
  || call.action == ACTION_UNKNOWN
  || call.object_type == TYPE_UNKNOWN
) {
  return -1;
}
```

```elixir
# good - named boolean makes the conditional clear
is_above_threshold = lux >= @darkness_threshold_lux
has_valid_reading = reading.status == :ok

if is_above_threshold and has_valid_reading do
  publish_reading(reading)
end

# avoid - complex condition inline
if lux >= @darkness_threshold_lux and reading.status == :ok do
  publish_reading(reading)
end
```

---

### Documentation Notation

When a value originates from external documentation — a datasheet, protocol specification, or RFC — write it in the notation the documentation uses. Do not translate between representations (hex to decimal, binary to hex, etc.) unless the translation adds meaning that the original notation lacks.

The documentation's notation is the canonical form. Translating it makes values harder to cross-reference with the source and adds noise without improving understanding.

```
# good — datasheet specifies register address in hex; keep hex in code
address = 0x0013

# avoid — decimal conversion adds noise; the hex is already the canonical form
# coil address is 0x0013 (19)
address = 0x0013
```

When byte data represents readable ASCII text, use character literals instead of hex. Character literals are self-documenting; hex requires a comment to explain what the bytes are. Non-text byte patterns (`0x7E, 0xC4`) stay as hex since they have no readable form.

A comment explaining what a literal value represents is a signal that the representation is wrong. Do not remove the comment without fixing the representation - removing the comment leaves the code in a worse state than before, because the value is now both unreadable and unexplained. Fix the representation first, then the comment becomes unnecessary.

```c
// good - character literals are self-documenting
uint8_t payload[] = {'H', 'e', 'l', 'l', 'o'};

// avoid - hex requires a comment to decode
uint8_t payload[] = {0x48, 0x65, 0x6C, 0x6C, 0x6F}; // "Hello"
```

**When to deviate**: When the reference documentation itself uses multiple notations, or when a different notation is significantly more readable in the language context (e.g. a well-known port number like `80` rather than `0x50`).

---

### Hardware Abstraction at API Boundaries

Translate hardware and implementation primitives into domain concepts at the API boundary. The public API speaks in domain language; the translation to hardware values happens internally. This makes the API self-documenting and decouples callers from implementation details.

```elixir
# good — Elixir: API uses semantic atoms; translation happens inside the module
@spec write_output(non_neg_integer, :on | :off) :: :ok
def write_output(channel, :on), do: write_coil(channel, 1)
def write_output(channel, :off), do: write_coil(channel, 0)

# avoid — Elixir: hardware primitives leak through the API
@spec write_output(non_neg_integer, 0 | 1) :: :ok
def write_output(channel, value) do
  write_coil(channel, value)
end
```

```c
// good - C: API uses enum; translation happens inside the module
typedef enum {
  OUTPUT_OFF = 1,
  OUTPUT_ON = 2,
} output_state_t;

int write_output(uint8_t channel, output_state_t state)
{
  uint8_t raw_value = (state == OUTPUT_ON) ? 1 : 0;
  return write_coil(channel, raw_value);
}

// avoid - C: hardware primitives leak through the API
int write_output(uint8_t channel, uint8_t value)
{
  return write_coil(channel, value);
}
```

Virtual and host implementations represent the domain, not the hardware. They have no hardware to interface with and should not carry over hardware-level encodings. Use domain concepts throughout - the real implementation is responsible for translating between domain and hardware at its boundary.

Apply the same principle in any language: prefer named domain concepts (enums, symbols, constants) over raw hardware values at API boundaries. When generating a virtual or host implementation of a hardware module, do not mirror the hardware module's raw values - use the domain-level API.

---

## Duplication

### DRY (Don't Repeat Yourself)

When the same logic appears in multiple places, a change to that logic requires finding and updating every copy — a process that is error-prone and easy to miss. Duplication of non-trivial logic is a signal to extract an abstraction.

Every abstraction has a cost: it introduces an API, a level of indirection, and something new for the reader to understand. Only consolidate when the abstraction provides more clarity and better usability than repeating the code. Short, simple expressions duplicated a few times are often easier to understand and maintain than an abstraction created solely to avoid repetition.

Two pieces of code that look similar but represent different concepts should stay separate — accidental similarity is not duplication.

```elixir
# acceptable — simple, short, and clear; abstraction would add noise
total_a = price_a + tax_a
total_b = price_b + tax_b

# good — non-trivial logic extracted; abstraction adds clarity and a single update point
def apply_discount(price, user), do: ...
```

---

## Conditionals

### Encapsulate Conditionals

When a conditional expression is complex enough that its intent isn't immediately clear, extract it into a named function or variable. The name should state what is being checked, not how.

```elixir
# good
if should_retry?(response) ...
if connection_timed_out?(state) ...

# avoid — reader must parse the condition to understand intent
if response.status == 503 and attempt < max_attempts ...
if state.last_ping + state.timeout < now() ...
```

```c
// good
if (should_retry(response))
  retry();

// avoid - reader must parse the condition to understand intent
if (response.status == 503 && attempt < max_attempts)
  retry();
```

---

### Avoid Double Negatives

Each negation costs the reader a decoding step: parse the negation, then apply it to the underlying claim, then combine that with the surrounding control flow. Stacking two negations forces the reader to walk both decoding steps in their head and recognize that the result is positive. The fix is to keep at most one negation per condition, and to keep it where the reader expects it — the `!` at the call site, not buried in the predicate name.

A double negative can appear in two places:

**1. At the call site, by negating an already-negative predicate name.** `connection_invalid?` is itself a negation; `!connection_invalid?(conn)` reads as "not connection invalid," two negations the reader must collapse to "connection valid."

```elixir
# good
if connection_valid?(conn) ...

# avoid
if !connection_invalid?(conn) ...
```

```ruby
# good
if buffer.should_compact? ...

# avoid
if !buffer.should_not_compact? ...
```

```c
// good
if (is_valid(connection))
  process(connection);

// avoid
if (!is_invalid(connection))
  process(connection);
```

**2. Inside the predicate name, when its content is itself a negation.** Even without an explicit `!` at the call site, a predicate whose content is a negation forces the reader to invert it before they can interpret the test. The negation is often signaled by a noun pressed into service as a verb. `mismatch` is a noun; an identifier like `reading_mismatches_calibration` is ungrammatical when read as prose ("reading mismatches calibration"), and the reader must mentally rewrite it as "reading does not match calibration" before evaluating the test. `if (reading_mismatches_calibration)` is one explicit `if` plus one buried negation — a double negative in disguise. The fix is to rewrite the predicate to its grammatical positive counterpart and negate at the call site if the negative case is what the code wants.

```c
// avoid - the predicate name is itself a negation; "mismatches" is not a verb
if (reading_mismatches_calibration) {
  abort();
}

// good - positive predicate, negate at the call site if needed
if (!reading_matches_calibration) {
  abort();
}
```

Common negative-predicate shapes and their positive counterparts:

| Negative form | Positive counterpart |
|---|---|
| `foo_mismatches_bar` | `foo_matches_bar` |
| `foo_differs_from_bar` | `foo_equals_bar` |
| `foo_conflicts_with_bar` | `foo_is_compatible_with_bar` |
| `foo_lacks_bar` | `foo_has_bar` |
| `foo_is_invalid` | `foo_is_valid` |
| `foo_is_missing` | `foo_is_present` |

This pattern is invisible to token-level checks (the names are snake_case, descriptive, no abbreviations). It is only visible when the name is read as prose. Detokenize boolean predicate names during review and flag any whose detokenized form (a) uses a noun as a verb (`mismatch`, `conflict`, `lack`), (b) describes the negative case directly (`is_invalid`, `is_missing`), or (c) requires the reader to mentally invert the test to understand the truthy condition.

**Exception: third-party APIs.** This rule applies to predicate names the project owns. A third-party library or framework that exposes a negative-form predicate (e.g. `connection_invalid?(conn)`) is the API's vocabulary, and calling it directly — `!connection_invalid?(conn)` — is the right move even though it produces a double negative at the call site. Do not wrap an external negative predicate in a project-owned positive wrapper just to satisfy this rule; the wrapper adds an indirection that hides the actual API call without changing the underlying logic, and it diverges from the third-party documentation a reader will consult. Accept the local double negative as the cost of using the external API as it is. Domain-term reasoning applies here too — see `### Domain Terms vs. Arbitrary Abbreviations`: project-owned identifiers follow project conventions, but identifiers borrowed from an external API match the API's own spelling.

---

## Boy Scout Rule

Always leave code cleaner than you found it. Small, continuous improvements compound over time. If you touch a file to fix a bug or add a feature, leave the surrounding code in better shape than you found it — a better name, a removed dead function, a clearer comment. This is not a mandate to refactor everything you touch; it is an encouragement to make small improvements as you go.

**For AI-generated code:** Apply this rule when refactoring or modifying existing code. Do not make style improvements outside the scope of what the user has asked for unless explicitly instructed to do so. Unsolicited changes add noise to diffs and can introduce unintended side effects.

---

## Structure

### Newspaper Metaphor

A source file should read like a newspaper article — high-level concepts and intent at the top, detail increasing as you read downward. A reader should be able to get the gist from the top without reading everything. Public interface before private implementation; broad strokes before specifics.

Language guides implement this principle in their own way — see the directive ordering and function ordering rules for each language.

---

## Formatting

### Line Length

Line length limits exist as a human visual constraint, not a screen size constraint. The human eye reads comfortably at around 50-60 characters; 80 characters is generous. A line that requires turning your head to read its end is too long. Set line length limits in your language guide — the specific number matters less than having one and applying it consistently.

Line length is a proxy for the real concern: cognitive load. Count the number of distinct components a reader must parse simultaneously — modules, functions, arguments, operators, values. When that count is high, split the line even if it is under the character limit. The split point should divide the line into two independently understandable units, each with a manageable number of components.

The inverse also applies: do not split a line that expresses a single coherent thought. A function call with a few short arguments is one idea - breaking it across lines forces the reader to mentally reassemble what was already clear. If a statement reads naturally on one line and fits within the limit, keep it on one line.

```
# 9 components on one line: module, function, arg, arg, arg | pipe, assertion, comparator, value
Device.add(:sensor, "temp_1", opts()) |> should(eq {:ok, device()})

# split at the natural boundary: 5 components + 4 components
Device.add(:sensor, "temp_1", opts())
|> should(eq {:ok, device()})
```

When a function call has a complex argument (a tuple with multiple fields, a nested data structure), break the argument onto its own line even if the call would technically fit within the limit:

```elixir
# complex argument — break for readability
:ok = resolve(MyApp.Serial).request(
  {:write, @slave_id, @base_address + channel, 1}
)

# simple arguments — keep on one line
PropertyTable.put(Sensors, ["lux"], 60)
```

Treat the line length limit defined in the language guide as a hard limit. Count characters when writing or modifying code. A line that exceeds the limit must be broken - do not rely on visual estimation. Also apply the cognitive load heuristic: a line with many components (function call with multiple arguments chained into a complex expression) warrants splitting even under the character limit.

---

### Files End With a Newline

Every file ends with a newline. This prevents diff noise when code is appended to the end of a file.

---

### Trailing Commas

Use trailing commas in multi-line collections — lists, maps, and structs. Trailing commas make copy/paste and reordering easier, simplify adding or removing items without touching adjacent lines, and produce cleaner diffs: only the line with the actual change appears modified, not the line above it where a comma would otherwise need to be added or removed.

Collections that change frequently — configuration lists, registered children, feature sets — benefit most, since additions and removals happen routinely.

Do not use trailing commas in function argument lists, where a trailing comma is not valid syntax.

---

### Consistent Formatting Within Groups

A group is a set of related members that appear together and share a structure or purpose: consecutive mock setups for one module, the fields of one struct, the elements of one enum, the clauses of one `case`/`cond`, the entries of one configuration map, the sequence of related statements in a setup block.

When a group's members can be formatted multiple ways, use the same format for all of them. If one member in the group requires a particular format — due to length, complexity, or structure — apply that format to the whole group.

```elixir
# good — consistent format across related members
allow(MyApp.Device.Controller) |> to(accept :poll, fn
  _, _ -> {:ok, default_poll}
end)

allow(MyApp.Device.Controller) |> to(accept :apply_profile, fn
  _, _, _, _ -> :ok
end)

# avoid — inconsistent format within the same group
allow(MyApp.Device.Controller) |> to(accept :poll, fn _, _ ->
  {:ok, default_poll}
end)

allow(MyApp.Device.Controller) |> to(accept :apply_profile, fn
  _, _, _, _ -> :ok
end)
```

The same rule applies to comments. If one inline comment in a group would run long, move all comments in that group above their respective lines (see § Placement for the line-length condition). Whether comments sit above or trail is a group-level shape choice.

**Scope**: this rule governs the *shape* of formatting choices — alignment, indentation, line-break points, whether a comment sits above its line or trails it. It does not govern *whether* members of a group carry a comment at all. If only some members of a group independently warrant a comment — some struct fields, some enum elements, some map entries, some function clauses — only those members get one; the bare members remain bare. Mixed presence within a group is the expected shape, not an inconsistency to fix. The C guide applies this distinction to struct fields (`c/CLAUDE.md` § Struct Field `///<` Comments) and enum elements (`c/CLAUDE.md` § Constants and Enum-Element Documentation).

```c
// good — consistent shape (all trailing, column-aligned), mixed presence
typedef struct {
  uint32_t id;
  uint8_t  mode;       ///< SENSOR_MODE_*
  uint16_t timeout_ms;
  uint8_t  flags;      ///< SENSOR_FLAG_*
} sensor_config_t;
```

`id` and `timeout_ms` stay bare because their names carry the meaning; `mode` and `flags` carry `///<` because the option set is not derivable from `uint8_t`. The comment uses the prefix glob (`SENSOR_MODE_*`), not an enumeration of every member. The shape is consistent (all `///<` are trailing, column-aligned); the presence is mixed. Both are correct.

---

### Vertical Separation Between Concepts

A blank line marks a transition between roles in a function's flow. Statements that share a role stay together; transitions between roles get a blank line. Role is the determinant, not statement kind - a sequence of mixed assignments, function calls, and notifications can be one role (the function's main work), and three assignments to closely related fields can be one role (setup), even though kind varies in the first case and is uniform in the second.

The roles a function moves through, in the order they typically appear:

- Setup / initialization - preparing state the rest of the function depends on.
- Main work - the function's principal computation, side effects, or transformation. Multiple statements of any kind can share this role when they cooperate toward the same outcome.
- Decisions - guard checks, branch points, control flow that diverts the work. Each guard (each `if return;` or similar) is its own decision and gets its own blank line above it; sequential guards are sequential roles, separated.
- Teardown / cleanup - releasing or finalizing state before the function exits.
- Outcome - the `return`, or the final statement that produces the function's effect.

What counts as the same role:

- Tightly-coupled statements where each step feeds the next (`int x = compute(input); int y = x + 1;`) form one cluster, even when they look like separate computations.
- Statements that share a purpose (`sensor->mode = cfg->mode; sensor->threshold = cfg->threshold;`) are one role even when they touch unrelated fields, as long as their function in the flow is the same.
- A control statement and its single-statement body (`if (condition) return;`) are one decision, not two. No blank line goes between them.

What does not satisfy a role transition:

- A comment between two statements is not a separator. Comments participate in the role of the statement they describe; placing one between two statements does not mark a role change. Comments belong above the statement they describe.
- A blank line earlier in the function does not satisfy the requirement at a later boundary. The rule fires on each role transition, not on whether the function carries blank lines somewhere.
- A control structure's closing `}` does not act as visual separation by itself. The statement after `}` still needs a blank line above it if it begins a new role.

Where the rule does not fire:

- A single statement that is the body of a control structure is part of that control statement's role.

This principle applies in any language with statements and blocks. Language-specific guides demonstrate the surfaces that matter for that language's syntax. See `c/CLAUDE.md` § Vertical Separation for the C surfaces.

---

## Testing

General testing principles are in `general/testing.md`. Load that file when writing or reviewing test code in any language. Language-specific testing rules (framework syntax, assertion styles, mock libraries) are in `<lang>/testing.md`.

---

## Dead Code

Remove dead code. Do not comment it out and leave it in place. Code that is unreachable or unused will accumulate, mislead readers, and can cause unexpected failures if accidentally reactivated. Source control preserves history — deletion is safe.

---

## Comments

### Write Self-Documenting Code

Do not use comments to describe what the code is doing. Write self-documenting code instead — function names, variable names, and return values should make the intent clear without narration. A comment that restates the code is a signal to improve the naming, not to add more words.

Use comments to explain *why* something is done when the reason is not apparent from the code itself.

When judging whether a comment is restating, apply the detokenize step from § Precision Over Length to every identifier in scope. A snake_case or camelCase identifier is a proposition in compressed form: `test_lock_release_fires_callback` carries the proposition "the test verifies that lock release fires the callback"; `mock_sensor_received().timeout_ms` carries "the timeout_ms field of the args the mock received." A comment that re-narrates a proposition the detokenized identifiers already carry is restating-what, even when the prose feels new because it is in a different cadence than the identifier. Read identifiers and prose comments as the same information channel, not as parallel ones.

This failure mode produces two characteristic shapes:

1. **Over-assertion comments** — a comment above one or more `TEST_ASSERT_*` (or equivalent assertion) calls that re-narrates what the assertion checks. The assertion targets and the test name already carry the proposition. Examples: `// Observable 1: _received() returns args matching what was passed.` above `TEST_ASSERT_EQUAL_UINT32(channel_id, mock_sensor_received().channel_id);` (the test name already says what is observed; the assertion code already shows what is checked); `// Step 3: verify call count is 1.` above `TEST_ASSERT_EQUAL_INT(1, mock_sensor_call_count());`.

2. **Over-test-body comments** — a comment in a test body that re-narrates the contract the test name has already named. A test named `test_X_defers_until_Y` already states "X defers until Y"; a comment that says "Y must complete before X fires" is restating, not adding why. The why-comment shape is justified only when the comment carries information the identifiers cannot — a non-obvious mock implementation detail, an external constraint, a workaround for a known bug.

Do not use section divider comments (`// --- Private ---`, `// === Helpers ===`, `// ---------------------------------------------------------------------------`, etc.). Code structure is already defined by function ordering, visibility modifiers, and file organization. Narrating the structure with dividers is redundant and adds noise.

Do not embed editor-specific markers in source files (`vim: set ...`, `-*- mode: c -*-`, etc.). Editor configuration belongs in project-level config files (`.editorconfig`), not in source code.

Do not write style rules or style guide instructions in code comments. Comments like `# colon-suffix signals a label, not a prose chain` or `# describe + specify: one primary test whose description lives on describe` are teaching the style guide, not explaining the code. The style guide is a separate document - its rules should not be embedded in generated code.

```elixir
# good — self-documenting code needs no comments
fan_speed_in_rpm = get_fan_speed(fan)
airflow_in_cfm = convert_rpm_to_cfm(fan_speed_in_rpm)

if airflow_in_cfm > 20 do
  :normal_mode
else
  :quiet_mode
end

# avoid — comments narrate what the code does; poor naming forces the explanation
# Gets the fan speed in RPMs and converts to CFM. Returns normal_mode if above
# 20 CFM, otherwise quiet_mode.
s = get_fan(f)
af = convert(s)

if af > 20 do
  :normal_mode
else
  :quiet_mode
end

# good — comment explains why, not what
# Proprietary algorithm required by the hardware vendor spec.
value = proprietary_algorithm(coerced_value)
```

```c
// good - self-documenting code needs no comments
int32_t fan_speed_rpm = get_fan_speed(fan);
double airflow_cfm = convert_rpm_to_cfm(fan_speed_rpm);

if (airflow_cfm > 20.0)
  set_mode(MODE_NORMAL);
else
  set_mode(MODE_QUIET);

// avoid - poor naming forces the explanation
// Gets the fan speed in RPMs and converts to CFM
int s = get_fan(f);
double af = convert(s);
```

### Comments Are Prose, Not Source Code

Do not write comments that express concepts using source code syntax. A comment like `# high=1, low=0 → lux = (1 <<< 16) ||| 0 = 65536` is neither readable prose nor executable code - it falls in between and serves neither purpose well. Either write the logic as actual source code that demonstrates the calculation, or describe the protocol in prose.

```elixir
# good - prose describes the protocol
# The sensor returns lux as two 16-bit words: high word first, low word second.
# The full value is (high << 16) | low.

# good - source code demonstrates the calculation
let :expected_lux, do: Bitwise.bsl(high_word(), 16) ||| low_word()

# avoid - code syntax in a comment; not prose, not executable
# high=1, low=0 → lux = (1 <<< 16) ||| 0 = 65536
```

```c
// good - prose describes the protocol
// The sensor returns lux as two 16-bit words: high word first, low word second.
// The full value is (high << 16) | low.

// good - source code demonstrates the calculation
uint32_t expected_lux = (high_word << 16) | low_word;

// avoid - code syntax in a comment
// high=1, low=0 -> lux = (1 << 16) | 0 = 65536
```

### Placement

Place comments above the code they describe when the code is lengthy or when an inline comment would push past the line length soft limit. Group-wide consistency rules for comment placement (above vs. trailing across a related set) live in § Consistent Formatting Within Groups.

Inline comments work well for densely packed elements — lists, maps, struct fields — where the comments are short and add meaning without cluttering the line.

### Deferred-Work Markers

**Intent**: Deferred-work markers in source code are not a tool for tracking unfinished work — they are evidence that work was committed in an unfinished state. An agent reaching for one of these markers has not finished its job. The remedy is to do the work, or, if blocked, to escalate via a handoff report to the lead so the lead can decide what happens next. The marker itself never lands in the codebase.

**Convention**: The following markers must not appear in committed code:

- `TODO`
- `FIXME`
- `XXX`
- `HACK`
- `OPTIMIZE`
- `REVIEW`

This applies whether the marker is a bare word, a `// TODO:` prefix, a Doxygen `@todo` / `@bug` tag, or any equivalent form. The ban covers all of them. An agent that finds one of these markers in code under review must surface it as a finding; an agent generating code must not produce one.

The rule applies at commit time. Working-tree markers during active editing are transient and do not violate the rule, but they must be resolved before the change is committed.

The ban covers every surface form the markers appear in. Examples below show the shapes most likely to slip through review:

```c
// avoid - bare word in a line comment
// TODO: validate the calibration table before applying

// avoid - line comment with prefix punctuation
// FIXME: this branch is unreachable but kept for now

// avoid - block comment containing the marker
/* HACK: short-circuit until the upstream API stabilizes */

// avoid - Doxygen tag form; the @todo/@bug tags are banned alongside the bare words
/**
 * @brief Apply the calibration table to a sensor reading.
 *
 * @todo handle the multi-channel case
 * @bug returns wrong result when calibration.gain is zero
 */
sensor_status_t sensor_calibrate(sensor_t *sensor, const calibration_t *calibration);
```

```elixir
# avoid - bare word in a line comment
# TODO: handle the timeout case

# avoid - line comment with prefix punctuation
# FIXME: the retry count is off by one

# avoid - @doc string containing the marker
@doc """
Apply the calibration table to a sensor reading.

TODO: document the multi-channel case
"""
def calibrate(sensor, calibration), do: ...
```

**Removing the marker means doing the work, not deleting the comment.** A `TODO` stands in for missing work; a `FIXME` stands in for broken code; a `HACK` stands in for a known-bad approach. Stripping the marker without addressing the underlying condition leaves the codebase in the same broken state with one less signal that something is wrong. The agent's job is to finish the work the marker would have stood in for. If the agent cannot finish the work — because it is blocked, out of scope, requires a decision the agent cannot make, or depends on something outside the current task — the resolution is a handoff report to the lead per `general/agents.md` § Stop-and-Report Protocol, not a marker in the source.

**`NOTE` is not a deferred-work marker** and is not banned. A `NOTE`-prefixed comment marks contextual information rather than unfinished work. However, the literal word `NOTE` is usually unnecessary: a comment is already obviously a note, so the prefix adds no information beyond what the comment's existence already signals. Drop the `NOTE` prefix unless it is load-bearing — for example, when a comment sits adjacent to several other comments and the prefix genuinely distinguishes its role from theirs.

```c
// avoid - the NOTE prefix adds nothing the comment itself does not already carry
// NOTE: The sensor returns lux as two 16-bit words: high word first, low word second.

// good - the comment is obviously a note; no prefix needed
// The sensor returns lux as two 16-bit words: high word first, low word second.
```

---

## License Information

### License Headers

Whether source files carry license information is the project owner's decision. Do not impose a preference. License information includes copyright statements, full license text blocks, and SPDX identifiers — treat all of these as the same concept.

**Rules:**

- **Don't add** license headers to files in a project that doesn't already use them.
- **Don't modify** existing license headers — leave the entire block untouched, even if it contains style issues. License information is only changed on explicit user request.
- **Do add** license headers to newly created files when the project already uses them. Use the current year in the copyright field — do not copy the year from existing files. Follow the exact format used by existing files in the project.

**SPDX format:**

SPDX is a standard for expressing license information in a machine-readable way. The identifier tag uses the comment style of the file's language:

```c
// SPDX-License-Identifier: MIT
```
```python
# SPDX-License-Identifier: MIT
```
```c
/* SPDX-License-Identifier: MIT OR Apache-2.0 */
```

Place as close to the top of the file as possible. The tag requires whitespace after the colon.

Licensing is legal information that must be accurate. If you encounter a license identifier you are not confident about, look up the correct SPDX identifier at https://spdx.org/licenses/ before writing it. Individual licenses can be found at `https://spdx.org/licenses/<identifier>.html` (e.g. https://spdx.org/licenses/MIT.html). Save the verified identifier to memory so it does not need to be looked up again. Do not guess license identifiers.

**License expression operators:**
- `OR` — licensee may choose either license: `Apache-2.0 OR MIT`
- `AND` — file is subject to both licenses: `Apache-2.0 AND MIT`
- `WITH` — license with an exception: `GPL-3.0-only WITH Classpath-exception-2.0`
- `+` suffix — version or any later version: `AFL-2.0+`
- Expressions can be combined: `Apache-2.0 AND (MIT OR GPL-2.0-only)`

**GNU license suffixes** — always use the explicit form, never bare version:
- `-only` — exactly that version: `GPL-2.0-only`
- `-or-later` — that version or any later: `GPL-2.0-or-later`

**Copyright notices are separate from SPDX identifiers.** SPDX IDs express license information only. Copyright notices — statements about who owns the copyright — are outside the scope of SPDX short-form IDs. Do not remove or modify existing copyright notices when adding an SPDX ID.

Copyright notice forms — all are valid, follow what the project uses:
- `SPDX-FileCopyrightText: 2024 Author Name`
- `Copyright (c) 2024 Author Name`
- `© 2024 Author Name`

Binary or non-commentable files use an adjacent `.license` file with the same filename plus `.license` extension (e.g. `image.png.license`).

If it is unclear how a project is licensed, check for a license file in the project's root directory (e.g. `LICENSE`, `LICENSE.txt`, `license.txt`, `COPYING`). If licensing intent is still unclear after checking, ask the user to clarify and add explicit instructions to their project's `CLAUDE.md`. For example:

```markdown
## Licensing
All source files use the following license header:
// SPDX-License-Identifier: MIT
// Copyright (c) 2024 Author Name
```

---

## Language

### American English

Use American English spelling in all identifiers, comments, and documentation unless:

1. The codebase is already written in another dialect or language — follow the established convention for consistency.
2. The user explicitly specifies another dialect or language.

When in doubt, prefer the American spelling (e.g. `initialize` not `initialise`, `color` not `colour`, `behavior` not `behaviour`).

Language keywords and standard library names are exempt — always use their canonical spelling regardless of locale. Some languages originate from regions that use British spellings; their keywords must be written as defined by the language (see language-specific guides for examples).

---

## Deprecated Rules

These rules were previously followed but are no longer recommended for new code. They are documented here for reference when working on legacy codebases — if existing code follows these conventions, match them for consistency.

Under `--rewrite` mode, these rules do not apply: codebase precedence is suspended, so deprecated patterns are removed alongside any other non-current patterns. Categorical replacements (e.g. § Annotation Keywords) apply in all modes; their text says so explicitly.

### Vertical Alignment (Deprecated)

Significant symbols (`=`, `->`, `=>`, map/keyword values) were previously aligned vertically on the same column across consecutive lines.

This is no longer recommended for new code. However, if a file already uses vertical alignment, maintain it for consistency.

This rule applies to code symbols only. Aligning inline comments across a group of related lines is acceptable when it improves readability.

See language-specific guides for examples.

### Annotation Keywords (Replaced)

A previous version of this guide endorsed `TODO`, `FIXME`, `OPTIMIZE`, `HACK`, and `REVIEW` as annotation keywords for tracking deferred work in source. That endorsement has been replaced by § Deferred-Work Markers, which bans those keywords (along with `XXX` and the Doxygen `@todo` / `@bug` equivalents) outright in committed code. Unlike the Vertical Alignment deprecation, this is a categorical replacement — the ban applies to legacy code as well. If existing code carries one of these markers, the marker must be resolved (do the work, or escalate via a handoff report) the next time the surrounding code is touched.

