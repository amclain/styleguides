@general/collaboration.md

# General Style Guide

This file defines style principles that apply across all languages. Language-specific rules are in `<lang>/CLAUDE.md`.

**Precedence in the codebase takes priority over this guide.** When in doubt, follow the style of the existing code. A project that presents itself as a consistent piece of work is easier to read than one that follows global rules but clashes with itself.

- Rules serve readability. If following a rule makes code harder to understand in a given context, don't apply it.
- Local coherence takes priority. Code that fits its surrounding context is preferable to code that follows a global rule but clashes with what's around it.
- Suggestions, not mandates. The reviewer suggests; the author decides.
- Explain on demand. Default output is terse (a numbered list of suggestions). Reasoning is available if asked.
- Whitespace is a tool. Use it to move the reader's eye through the code and accentuate areas of importance — not excessively, but purposefully.

## Operating Modes

This style guide supports two modes. The agent determines the active mode from context (the user's request, the trigger phrase, or the task at hand). Check memory for the user's model preferences for each mode - see `general/first-run.md`. For guidance on which models to use for which tasks, agent roles, and multi-agent orchestration, see `general/agents.md`.

### Code Generation

Sonnet is the default for code generation. Code logic and correctness are equivalent across models - Sonnet writes the same algorithms and data structures as Opus. Opus produces fewer style violations during generation because it holds more rules active simultaneously, but the post-generation review pass catches these regardless of which model generated the code. Sonnet is faster and lower cost for generation, with the known style blind spots handled by the review step.

The generating agent cannot accurately review its own code due to context bias from the generation phase. This is the primary reason generation and review are separate agents, not a quality difference between models.

**If the current session is running Opus and code generation is requested:** inform the user once that Sonnet produces equivalent code logic at lower cost, and that style compliance is handled by the review pass. Ask the user to confirm before proceeding with Opus generation. Save their decision to memory so this prompt is not repeated.

When generating new code, apply the rules in this guide and the loaded language guide proactively. Do not wait to be asked.

**Multiple options:** when code complexity is high and more than one approach is appropriate, present the options with trade-offs rather than prescribing one answer. Limit to 2-3 choices - 1 or 2 is best.

### Post-Generation Review

After completing a code generation task (not after every function - after the full task is done), launch a review subagent using the user's preferred review model. The generating agent has context bias from the generation phase and is less likely to catch its own style violations. A fresh review agent reads the generated code cold and catches patterns the generator consistently misses due to training data bias (e.g. zero-arity type parentheses, pipe operator parentheses).

The post-generation review subagent fixes violations autonomously - it reads the generated code, identifies style violations, and applies corrections directly without prompting the user. This is different from Style Review mode, where suggestions are presented for the user to accept or reject. Post-generation review is a cleanup pass on code the agent just wrote, not a review of the user's code. After completing all fixes, report a summary of what was changed (file, rule, what was fixed).

After applying fixes, the review subagent must run the project's test suite to verify the fixes did not break anything. Style corrections are formatting-only and must not change behavior. If tests fail after fixes, diagnose and correct the issue.

If the user's preferred review model is different from the generation model (e.g. generate with Sonnet, review with Opus), this step is especially valuable - the review model may catch violations the generation model cannot self-correct on. Skip this step if the user has opted out of post-generation review.

### Style Review

When reviewing code, default to scoping suggestions to changed lines only. Run `git diff` and `git diff --staged` to identify what changed; read the full file for context; flag issues only in the changed lines. This mirrors how a human reviewer works on a pull request. The entire codebase can also be reviewed if the user asks - this is not the default. The user's preferred review model is saved in memory from the first-run check.

This system is intended to replace mechanical formatters (e.g. `mix format`, `rubocop`, `clang-format`). Unlike mechanical tools, it applies rules contextually and understands intent.

If the user asks what capabilities are available, describe all options:
- Review changed lines only (default)
- Review the entire codebase
- Apply any suggestion directly
- Explain the reasoning behind any suggestion

**Output format:** a terse numbered list of suggestions. Reasoning is available if asked ("explain #N").

**Applying suggestions:** if the user asks you to apply a suggestion or act as a formatter, make the change directly. The default is to suggest; applying is opt-in.

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

### Tests Are Specifications

A test suite is a specification of behavior. Reading the tests should teach you what the code does and why — the domain rules, the edge cases, the invariants. Write tests as if they are the authoritative description of the system's behavior.

Test names should be behavioral propositions in plain language. A name like `"returns an error when the network is unreachable"` tells a developer exactly what behavior is expected, why it matters, and whether a refactor has preserved the intended functionality. A name that mirrors the code structure — like `"connect/1"` — describes the shape of the code, not the behavior of the system.

Test names describe either what the subject can do (a capability: `"can turn on the output port"`, `"returns :ok on success"`) or what is true about the subject (a property: `"name can start with a single underscore"`, `"connection defaults to port 6379"`). Both are behavioral propositions - they say something meaningful about the system. Prefer requirement-style language (`can`, `returns`, `has`, `is`, `does not`) that frames the test as a specification rather than a narration of test steps.

Write descriptions at the caller's level of abstraction. The observable contract is what a caller experiences: the value returned, the side effect produced, the state that changes. Implementation details — internal data structures, storage mechanisms, algorithms, module names that callers don't interact with directly — do not belong in test descriptions, even when the description is grammatically a behavioral proposition.

```elixir
# good — describes the observable contract
test "reports the current lux reading"
test "can turn on the output when lux is below the threshold"

# avoid — names an internal storage mechanism the caller doesn't interact with
test "publishes the lux reading to the property table"

# avoid — describes the algorithm, not the observable result
test "combines the high and low register words into a 32-bit lux value"
```

```elixir
# good — describes a specific behavior
test "returns an error when the network is unreachable"
test "returns :ok when the response is successful"

# good — describes a property or constraint
test "name can start with a single underscore"
test "connection defaults to port 6379"

# avoid — mirrors code structure, describes nothing
test "connect/1"
test "test_connect"
```

In C test frameworks, the test name is a function identifier rather than a string. The same behavioral proposition principle applies - the function name should describe the expected behavior, not mirror the function under test.

```c
// good - behavioral propositions (module name is in the file name, not repeated)
// in test_sensor.c:
void test_returns_negative_on_hardware_failure(void) { ... }
void test_returns_calibrated_value(void) { ... }

// in test_config_store.c:
void test_overwrites_existing_key(void) { ... }

// avoid - mirrors the function under test, describes nothing
void test_read(void) { ... }
void test_set(void) { ... }

// In Google Test, the same principle applies:
// TEST(Sensor, ReturnsNegativeOnHardwareFailure) { ... }
// TEST(Sensor, ReturnsCalibratedValue) { ... }
```

---

### Test at the Right Level

Unit tests verify that individual modules behave correctly in isolation. Feature tests verify that modules work together to produce the correct end-to-end behavior. Both are necessary - a system where every unit test passes can still fail if the units are wired together incorrectly.

Unit tests mock or stub external dependencies to isolate the subject. Feature tests wire real modules together and only mock at the system boundary - the external interfaces that the feature cannot control (hardware, network, OS services).

Structure the test suite so that both levels are present:
- **Unit tests** cover module-level logic, edge cases, and error paths
- **Feature tests** cover scenarios that cross module boundaries - a request flowing through parsing, validation, and response, for example

Feature tests tend to require more setup. Extract shared setup into helper functions when the same scenario scaffolding is used across multiple tests. Name helpers after the scenario they create, not the implementation steps they perform.

**When to deviate**: Small programs with few modules may not need a separate feature test layer - the unit tests may already exercise the integration points. Add feature tests when the system has enough modules that the wiring between them is a meaningful source of bugs.

---

### One Logical Concept Per Test

Each test should verify one logical concept. This is not the same as one assertion — a single concept may require several assertions to fully verify. Tests that bundle multiple unrelated concepts together make failures harder to diagnose and make the test name impossible to write meaningfully.

```elixir
# good — one concept, multiple assertions that together verify it
test "a successfully parsed response contains the expected fields" do
  assert response.status == :ok
  assert response.body == expected_body
  assert response.headers["content-type"] == "application/json"
end

# avoid — two unrelated concepts in one test
test "connection" do
  assert {:ok, conn} = connect(opts)
  assert :ok = disconnect(conn)
end
```

---

### Test Grouping Structure

Group tests under a named block when multiple tests share an overarching theme, common setup or teardown, or shared example behavior. Three signals that a grouping block adds value:

- Multiple tests share an overarching theme or concept
- Multiple tests share setup or teardown — the block scopes it to exactly the tests that need it, rather than running it for every test in the file
- Multiple tests share behavior via shared examples

When test descriptions are nested inside grouping blocks, they typically concatenate in output. Write descriptions so they chain into readable sentences.

Name groups after behavior and scenarios, not function signatures. A name like `"connect/2"` describes code structure; `"when the host is unreachable"` describes behavior.

```elixir
# good — group scopes setup to the tests that need it; names describe scenarios
describe "when the session is active" do
  setup do
    {:ok, conn: connect(host: "localhost")}
  end

  test "can send a command", %{conn: conn} do
    assert :ok = send_command(conn, :ping)
  end

  test "can receive a response", %{conn: conn} do
    assert {:ok, _} = receive_response(conn)
  end
end

# avoid — group named after function signature
describe "connect/2" do
  test "returns :ok" do
    assert :ok = connect(host: "localhost")
  end
end

# good — same concept; name describes behavior
describe "when the host is reachable" do
  test "returns :ok" do
    assert :ok = connect(host: "localhost")
  end
end
```

A flat list of test cases with no grouping is acceptable when no meaningful structure exists.

Language-specific guides define the exact block names and syntax for each framework (e.g. `describe`/`context` in ESpec and RSpec, `describe` in ExUnit and Jest).

---

### Tests Are Independent and Deterministic

**Intent**: Tests that share state or depend on execution order are fragile — a failure in one hides or causes failures in others, and the suite becomes unreliable.

**Convention**: Each test sets up its own state and cleans up after itself. Tests must not rely on order of execution or side effects from previous tests. A test that produces different results on a second run, or in a different environment, is broken.

**Example**:
```elixir
# good — each test sets up its own state
test "returns an error when the connection is refused" do
  conn = connect(bad_opts)
  assert {:error, :refused} = send_request(conn)
end

# avoid — relies on state set by a previous test
test "returns an error after disconnect" do
  # assumes conn was established by a prior test
  assert {:error, :closed} = send_request(@conn)
end
```

**When to deviate**: Shared setup is acceptable when the fixture is read-only and identical for all tests — a static reference dataset, for example. Avoid shared mutable state.

---

### Tests Should Support a Tight Feedback Loop

**Intent**: Tests that engineers don't run provide no safety net. The goal is a suite that gets run continuously — while iterating on code, not just at the end.

**Convention**: A test suite should be fast enough that running it feels like a natural part of the development rhythm, not an interruption. When the full suite becomes too slow to run after every change, lean on tooling to narrow scope: run only the file or describe block relevant to the current work.

All tests must pass before merging. Run the full suite before submitting code for review.

Avoid coupling tests to slow external systems (real network calls, real databases, real timers) unless the test is explicitly an integration test. Slow dependencies in unit tests accumulate and eventually push the suite into "too slow to bother" territory.

**When to deviate**: Integration and end-to-end tests touch real systems by definition and belong in a separate suite with different run expectations.

---

### Coverage Metrics Are a Signal, Not a Target

**Intent**: Coverage numbers measure which lines were executed, not whether the tests are meaningful. Optimizing for coverage produces tests that execute code without verifying behavior.

**Convention**: Use coverage as a diagnostic tool — a low number signals undertested areas worth examining. Do not set coverage thresholds as pass/fail gates. Every test written should be meaningful and add understanding about the application's functionality. A test written to increase a coverage number rather than to specify behavior is noise — it bloats the suite without improving confidence.

**When to deviate**: Some organizations require coverage thresholds for compliance or audit purposes. In those cases, treat the threshold as a floor, not a goal.

---

### Tests Should Not Duplicate Implementation Logic

**Intent**: A test that reimplements the logic it is testing provides no independent verification — it can only confirm that two copies of the same code agree with each other.

**Convention**: Test outputs against known, fixed values. If deriving the expected value requires reproducing the algorithm, the test is not a specification — it is a mirror. Use concrete examples that illustrate the behavior, not generated inputs run through a parallel implementation.

**Example**:
```elixir
# good — expected value is a known, fixed result
test "calculates the discounted price" do
  assert apply_discount(100, 0.2) == 80
end

# avoid — expected value is derived by reimplementing the logic
test "calculates the discounted price" do
  expected = price - (price * discount)
  assert apply_discount(price, discount) == expected
end
```

**When to deviate**: Property-based tests deliberately generate inputs and assert properties that must hold — rather than specific output values. This is a valid complement to example-based tests, not a violation of this rule.

---

### Write Tests With the Code

When implementing a new module or function, write tests alongside the
implementation — not as a separate follow-up task. If test scaffolding already
exists (empty spec or test files for the module), fill it in as part of the
same implementation.

Unimplemented test files are not acceptable deliverables. An empty test file
provides no specification and no safety net. Every module with public functions must have tests. Before completing a code generation task, verify that every test file has at least one test.

---

### Test Code Is Production Code

**Intent**: Tests that are hard to read become tests that nobody trusts, updates, or learns from. Letting test code quality slip undermines the value of the suite.

**Convention**: Apply the same standards to test code as to production code — clear naming, small focused functions, no duplication of test setup logic, no magic numbers. A developer reading a failing test should be able to understand what it was asserting and why, without digging into the implementation.

**When to deviate**: Test helpers and fixtures can be more permissive about abstraction — a shared factory or builder that exists solely to reduce setup noise is acceptable even if it would be over-engineered in production code.

---

### Assertion Precision

Match the specificity of an assertion to the claim being made. If you mean exact equality, assert exact equality. If you mean structural membership (e.g. "this is a success tuple"), use a structural assertion. Use truthiness or falsiness assertions only when truthiness is what you are actually testing.

A loose assertion can mask regressions: an assertion that only checks truthiness passes even if the value changes, as long as it remains truthy.

```elixir
# good — exact equality when the exact value is what's claimed
assert result == :ok
assert response.status == 200

# avoid — truthiness check when exact equality is intended
# passes for any truthy value, not just :ok
assert result

# good — truthiness only when truthiness is the actual property being tested
assert auth_token  # testing that a token was generated, any non-nil value is fine

# good — structural assertion for structural claims
assert {:ok, _conn} = connect(opts)  # testing the shape, not the specific conn value

# avoid — exact equality for a structural claim
assert {:ok, conn} = connect(opts)  # fails if conn fields differ from expected
```

Language-specific guides describe the assertion style for each framework (e.g. `eq`/`be_truthy` in ESpec, `==`/`match?` in ExUnit).

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

