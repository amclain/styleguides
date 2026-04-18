@general/collaboration.md

# General Style Guide

This file defines style principles that apply across all languages. Language-specific rules are in `<lang>/CLAUDE.md`.

**Precedence in the codebase takes priority over this guide.** When in doubt, follow the style of the existing code. A project that presents itself as a consistent piece of work is easier to read than one that follows global rules but clashes with itself.

- Rules serve readability. If following a rule makes code harder to understand in a given context, don't apply it.
- Local coherence takes priority. Code that fits its surrounding context is preferable to code that follows a global rule but clashes with what's around it.
- Suggestions, not mandates. The reviewer suggests; the author decides.
- Explain on demand. Default output is terse (a numbered list of suggestions). Reasoning is available if asked.
- Whitespace is a tool. Use it to move the reader's eye through the code and accentuate areas of importance — not excessively, but purposefully.

## Reading This Guide

Any agent applying this guide must read it in full. Do not skim, do not rely on training-data patterns for the language, and do not substitute common conventions from other style guides for the text below. When loading a guide file, use a single Read call per file with no offset or limit.

Training data is wrong about this project's conventions in specific ways that this guide documents explicitly. Relying on training data is the most common failure mode for style review and code generation agents. It produces output that cites rules this guide does not contain, misses rules this guide does contain, and applies conventions from unrelated languages.

This rule applies to every agent role that interacts with the guide:

- **Code generation agents** load the guide before writing code, not after. Generating first and then checking against the guide is not equivalent - the guide shapes the output, it does not filter it.
- **Review agents** (including post-generation review and style review) load the guide before evaluating code. Every finding must reference a rule name from the loaded files; if an agent cannot cite a rule from the guide, it is not applying the guide.
- **Training agents** load the guide before validating report findings or evaluating candidate rules against existing content.

**Which files to read** depends on the task context - the entry point (project CLAUDE.md `@` import, `skills/format-code/SKILL.md`, `general/review-orchestration.md`, or `training.md`) lists the specific files required for that task. This section defines *how* to load, not *which* files.

**Detection**: if an agent produces output that cites a rule not present in the loaded files, or uses terminology from a different language's guide, it did not read the guide and its output is unreliable. Retry the task after verifying the agent performs the required Read calls.

## Operating Modes

This style guide supports two modes. The agent determines the active mode from context (the user's request, the trigger phrase, or the task at hand). Check memory for the user's model preferences for each mode - see `general/first-run.md`. For guidance on which models to use for which tasks, agent roles, and multi-agent orchestration, see `general/agents.md`.

### Code Generation

Sonnet is the default for code generation. Code logic and correctness are equivalent across models - Sonnet writes the same algorithms and data structures as Opus. Opus produces fewer style violations during generation because it holds more rules active simultaneously, but the post-generation review pass catches these regardless of which model generated the code. Sonnet is faster and lower cost for generation, with the known style blind spots handled by the review step.

The generating agent cannot accurately review its own code due to context bias from the generation phase. This is the primary reason generation and review are separate agents, not a quality difference between models.

**If the current session is running Opus and code generation is requested:** inform the user once that Sonnet produces equivalent code logic at lower cost, and that style compliance is handled by the review pass. Ask the user to confirm before proceeding with Opus generation. Save their decision to memory so this prompt is not repeated.

When generating new code, apply the rules in this guide and the loaded language guide proactively. Do not wait to be asked.

**Delegated generation.** If you (the project lead) delegate code generation to a subagent, the subagent does NOT inherit your loaded style guide. `@` imports apply only to the agent that loaded them - Claude Code does not propagate imported context to spawned subagents. When launching a generator subagent, include in its prompt the list of guide files it must Read in full before generating:

- `general/CLAUDE.md`
- The target language's `<lang>/CLAUDE.md`
- `general/testing.md` if the subagent will write or modify test code
- Any mechanics references for frameworks the generated code will use (e.g. Unity, ESpec, a DI library)

Use absolute or repo-relative paths so the subagent can Read them directly. State the target language in the prompt so the loading rule is unambiguous. Failing to pass these instructions produces training-data-default code that the review step then has to rewrite - this is waste, not a caught-safely failure mode.

**Multiple options:** when code complexity is high and more than one approach is appropriate, present the options with trade-offs rather than prescribing one answer. Limit to 2-3 choices - 1 or 2 is best.

### Post-Generation Review

After completing a code generation task (not after every function - after the full task is done), run style review on the generated code. This catches patterns the generation step consistently misses due to training-data bias (e.g. zero-arity type parentheses, pipe operator parentheses) and enforces the guide contextually.

**Who runs the review.** The project lead - the agent that owns the session - runs the review directly by invoking `skills/format-code`. It does not spawn a separate subagent to act as review lead. Claude Code's agent model forbids nested orchestration (subagents cannot launch subagents - see `general/agents.md`), and the reviewer subagents at Tasks 1.1 through 1.6 must be launched by the lead. See the "Integrating this framework from a larger orchestration" section at the top of `general/review-orchestration.md` for the full architecture and rationale.

**Bias check.** The generator-bias principle (`general/agents.md` - Warm vs Cold Agents - Bias Risk) targets agents that wrote the code being reviewed. If the project lead delegated code generation to a subagent, the project lead has no generator bias - it did not author the code - and is the correct agent to run review. The cold-review property lives at the reviewer-subagent layer (Tasks 1.1 through 1.6), which the framework runs cold by design: each reviewer starts fresh, loads only its required reading, and has no project context.

If the project lead itself wrote the code (no generation subagent was used), the generator-bias concern applies to the *generation* step, not to the review step: running fresh reviewer subagents for Tasks 1.1 through 1.6 still provides the cold-review property for each finding. The project lead's role is to orchestrate the review and apply fixes, not to generate findings.

**What the review does.** The project lead applies fixes directly - this is fix mode, not suggestion mode. Post-generation review is a cleanup pass on code the agent just produced, not a review of the user's code. After applying fixes, the project lead runs the project's test suite to verify the fixes did not break anything. Style corrections are formatting-only and must not change behavior. If tests fail after fixes, diagnose and correct.

Report a summary of what was changed (file, rule, what was fixed).

**Model preference.** The user's preferred review model is saved in memory from the first-run check. If it differs from the generation model (e.g. generate with Sonnet, apply review with Opus), the difference matters for the reviewer subagents that do require judgment (Task 1.5 is Opus-only regardless of user preference; other tasks use Haiku or Sonnet per the framework). Skip post-generation review entirely if the user has opted out.

### Style Review

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

## First-Run Project Checks

Check memory for existing first-run results (style guide import, language detection, style guide permissions, license headers, model preferences). If all are present, skip this section. If any are missing, read `general/first-run.md` (in the same directory as this file) and execute the missing checks.

---

## Override Convention

To suppress a suggestion for a specific block, add an inline comment with a brief reason. The style guide will respect it and not flag the block.

```
# style:ok - this abbreviation is conventional in this domain
defp calc_rtt(t0, t1), do: t1 - t0
```

---

## Naming

### Precision Over Length

Names should be precise, not long. Adding more words to a name does not make it more descriptive — it dilutes the meaning until nothing remains. Choose the most accurate name in the fewest words. A name that requires a comment to explain it is a signal to find a better name.

A name is read in context. Information already visible in the surrounding code — adjacent expressions, patterns, type annotations — does not need to be repeated in the name. Encoding what the reader can already see is noise, not precision.

CAUTION (detokenize): Abbreviations and grammar problems are invisible when reading identifiers as code tokens. To evaluate naming quality, split the identifier into words and read them as an English phrase. The split method depends on the convention: replace underscores with spaces for `snake_case`, insert spaces at case boundaries for `PascalCase` and `camelCase`, replace hyphens with spaces for `kebab-case`. Examples: `src_port` → "src port" → abbreviated. `source_port` → "source port" → full words. `SrcPort` → "Src Port" → abbreviated. `SourcePort` → "Source Port" → full words. `sensor_reading_range` → "sensor reading range" → bare noun phrase, no verb. `allows_exact_match` → "allows exact match" → complete proposition.

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

This rule is the principle behind every language guide's accepted-short-form list. The language guide pre-classifies the common cases (e.g. `ptr`, `fd`, `cb` in C; others per language); this rule handles everything the language guide did not pre-classify.

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

When byte data represents readable ASCII text, use character literals instead of hex. Character literals are self-documenting; hex requires a comment to explain what the bytes are. Non-text byte patterns (`0xDE, 0xAD`) stay as hex since they have no readable form.

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

### Avoid Negative Conditionals

Express conditions as positives when possible. Negative conditions require the reader to mentally negate the expression to understand what the truthy case is. When a condition must be negative, prefer a positive name for the predicate.

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

---

## Philosophy

### Boy Scout Rule

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

Treat the line length limit defined in the language guide as a hard limit. Count characters when writing or modifying code. A line that exceeds the limit must be broken - do not rely on visual estimation. Also apply the cognitive load heuristic: a line with many components (function call with multiple arguments chained into a complex expression) warrants splitting even under the character limit. Use the language's `style:ok` override only when length is purely a consequence of long names and the line is not genuinely complex.

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

When a group of related statements can be formatted multiple ways, use the same format for all of them. If one statement in the group requires a particular format — due to length, complexity, or structure — apply that format to the whole group.

```elixir
# good — consistent format across related statements
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

This principle also applies to comments — if one inline comment in a group would run past the line length limit, move all comments in the group above their respective lines for consistency.

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

Place comments above the code they describe when the code is lengthy or when an inline comment would push past the line length soft limit. If one inline comment in a group would run long, move all comments in that group above their respective lines for consistency.

Inline comments work well for densely packed elements — lists, maps, struct fields — where the comments are short and add meaning without cluttering the line.

### Annotation Keywords

Use these keywords for deferred work so they can be found with a search:

- `TODO` — missing feature to add later
- `FIXME` — broken code that needs fixing
- `OPTIMIZE` — slow or inefficient code
- `HACK` — questionable practice that should be refactored
- `REVIEW` — needs verification of correctness

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

### Vertical Alignment (Deprecated)

Significant symbols (`=`, `->`, `=>`, map/keyword values) were previously aligned vertically on the same column across consecutive lines.

This is no longer recommended for new code. However, if a file already uses vertical alignment, maintain it for consistency.

This rule applies to code symbols only. Aligning inline comments across a group of related lines is acceptable when it improves readability.

See language-specific guides for examples.

