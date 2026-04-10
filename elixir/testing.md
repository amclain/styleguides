# Elixir Testing Style Guide

Testing conventions for Elixir. Part of the Elixir style guide — loaded automatically via `@` import from `elixir/CLAUDE.md`.

---

## Testing

Phoenix projects commonly couple controller and context tests to a real database via Ecto's sandbox adapter. This is a framework convention, not a recommended pattern. In Phoenix codebases it is the established practice - treat it as consistent with local precedence rather than flagging it as a style issue.

Elixir's built-in coverage tool (`:cover`) does not always accurately track all lines or branches - macros, protocol implementations, and generated code are common blind spots. Coverage numbers in Elixir projects may underreport actual coverage. Do not treat low numbers as definitive evidence of undertesting without investigating what the tool is missing.

### Testing Framework

[ESpec](https://github.com/antonmi/espec) is the recommended testing framework. ESpec's RSpec-style syntax is preferred over ExUnit's `test` blocks. Rules in this section assume ESpec unless noted otherwise.

`capture_log` and `capture_io` are available in ESpec via direct import from ExUnit. Both return `String.t` - the inner function's return value is discarded. When the return value is needed alongside the captured output, use `with_log` or `with_io` - these return `{result, String.t}`.

```elixir
# return value discarded
log = capture_log(fn -> MyApp.do_something() end)

# return value preserved
{result, log} = with_log(fn -> MyApp.do_something() end)
```

---

### Spec Module Naming

The suffix is determined by the framework. Check the Test Framework memory entry from the first-run check to determine which applies.

Use the Test Framework memory entry (from the First-Run Project Checks in `elixir/CLAUDE.md`) to determine the correct suffix before generating any test module. Do not default to `.Test` without checking.

**ESpec** — use a `.Spec` suffix as a separate namespace segment. The `.Spec` is a dot-separated module segment, not a flat suffix appended to the module name. Files live in `spec/`, mirroring the module namespace.

```elixir
# good — ESpec, .Spec as a namespace segment
defmodule MyApp.Parser.Spec do
  use ESpec
end
# file: spec/my_app/parser_spec.exs

# avoid — flat suffix (no dot separation)
defmodule MyApp.ParserSpec do
  use ESpec
end

# avoid — .Test suffix with ESpec
defmodule MyApp.Parser.Test do
  use ESpec
end
```

Do not use flat suffixes like `MyApp.ParserSpec` or `MyApp.PipelineSpec` - the `.Spec` must be its own namespace segment: `MyApp.Parser.Spec`. Do not use non-standard suffixes like `FeatureSpec` - the suffix is always `.Spec`, regardless of the test type.

**ExUnit** — use `Module.Test` for new codebases. Follow the project's existing convention otherwise. Files live in `test/`.

```elixir
# good — ExUnit, preferred for new codebases
defmodule MyApp.Parser.Test do
  use ExUnit.Case
end
# file: test/my_app/parser_test.exs

# acceptable — ExUnit with .Spec naming; follow if already a project convention
defmodule MyApp.Parser.Spec do
  use ExUnit.Case
end

# acceptable — ExUnit flat naming (mix default); follow if already a project convention
defmodule MyApp.ParserTest do
  use ExUnit.Case
end
```

**When to deviate**: For ExUnit, always follow the naming convention already established in the project rather than introducing a mixed scheme.

---

### Spec Module Aliases

**Intent**: Reduce noise in test code while keeping module references clear.

**Convention**: Alias the spec's subject module (its parent) at the top of the spec for convenience. This is the module under test - it appears frequently throughout the spec.

For other modules referenced in the spec, only alias when the module is called more than once. A single fully qualified call is less noise than an alias declaration plus a short call.

```elixir
# good - alias the subject module
defmodule MyApp.Sensor.Spec do
  use ESpec, async: false

  alias MyApp.Sensor

  describe "when the sensor reads a value" do
    it "reports the reading" do
      Sensor.start_link
      # ...
    end
  end
end

# good - single call to a non-subject module; skip the alias
before do
  {:ok, pid} = MyApp.Sensor.start_link

  {:shared, pid: pid}
end

# avoid - aliasing a module used only once adds noise
alias MyApp.Sensor

before do
  {:ok, pid} = Sensor.start_link

  {:shared, pid: pid}
end
```

**When to deviate**: If the subject module is not directly used in the tests (only used through other modules), skip the alias.

---

### Test block keywords: semantic roles

The four block keywords split into two axes by the semantic role they play:

|          | behavior / action | scope / proposition |
|----------|-------------------|---------------------|
| grouping | `describe`        | `context`           |
| test     | `it`              | `specify`           |

**At the grouping level**, the distinction is between describing a **behavior or action** and establishing a **scope** the tests apply under:

- **`describe`** names a behavior, action, scenario, or event the tests verify. Typical describe strings are action phrases (`"add a device"`, `"remove a device"`, `"reload"`), function or command names being tested (`"decode"`, `"encode"`), `"when X"` scenario phrases (`"when the host is unreachable"`), or state transitions.
- **`context`** sets the scope, state, role, or condition the tests run under. Typical context strings are states ("logged in user"), subsystems ("sensor"), or category labels ("cache operations:"). The scope is often implied by the module name, so `context` is frequently omitted in small and medium files; reach for it when the module is complex enough to need sub-scoping or has multiple states to test.

Intent is the litmus test. If you meant the string as a scope the tests run under, it is `context`. If you meant it as the behavior or action the tests verify, it is `describe`. A string like "logged in user" is `context` - you are not describing a logged-in user, you are scoping tests to the state where a user is logged in.

**At the test level**, the distinction is grammatical and falls out of how `it` and `specify` are read:

- **`it`** is a pronoun in the test description. The string after it is read with "it" in front - `it "returns a calibrated value"` in a spec for the `Sensor` module is shorthand for "Sensor returns a calibrated value". The "it" refers to the subject under test. Grammar checks apply: the string after `it` must be a well-formed predicate of the subject.
- **`specify`** reads as just the string - no pronoun, no prepended keyword. The string stands alone as a proposition scoped to the enclosing block. Use `specify` when the string cannot be phrased as a predicate of the subject without distorting the description.

The two axes mirror each other in preference. Prefer the behavior/action form (`describe`, `it`) when it fits the intent; fall back to the scope/proposition form (`context`, `specify`) when forcing the behavior form would distort what the test is actually describing.

ExUnit has no `it`, `specify`, or `context` - `describe` is its only grouping block and `test` is its only test keyword. ExUnit's `test` is grammatically a standalone proposition (like `specify`). ExUnit's `describe` carries both the behavior/scenario and scope roles by necessity; choose the describe string based on intent, just as you would choose between ESpec `describe` and `context`.

---

### describe and context

Both `describe` and `context` are grouping blocks - they organize tests but do not execute them. `it` and `specify` are the keywords that define executable tests.

**`describe`** groups tests around a behavior, action, or scenario being verified. Its string names what is happening or what is being tested. Typical describe strings are action phrases (`describe "add a device"`, `describe "register a device"`, `describe "reload"`), function or command names being tested (`describe "decode"`, `describe "encode"`), `"when X"` or `"with X"` scenario phrases (`describe "when the input is nil"`, `describe "when the host is unreachable"`), or state-transition descriptions.

**`context`** groups tests around a scope, state, role, or category the tests run under. Its string names the scope, not the behavior. Typical context strings are states ("logged in user"), subsystems or subjects ("sensor"), or category labels ("cache operations:"). Because the module name usually implies the scope, `context` is often unnecessary in small and medium files - use it when the module is complex enough to need sub-scoping, has multiple states to test, or groups multiple `describe` blocks that share a parent scope.

**Typical nesting** is `context → describe → it`/`specify`. `context` is the outer scope, `describe` is the scenario within that scope, `it` or `specify` is the individual test. `context → it` (no intermediate `describe`) is valid but less common - it fits when the tests share a scope but no common scenario. Further nesting is a prompt to examine the module: if the module is genuinely complex and appropriately scoped, deeper nesting is fine; if the nesting is compensating for a module that has taken on too many responsibilities, decompose the module instead.

Three signals that a grouping block is warranted:

- Multiple tests share an overarching theme or scenario
- Multiple tests share the same `before`/`finally` setup - the block scopes the setup to exactly the tests that need it
- Multiple tests share behavior via shared examples - `it_behaves_like` can be scoped inside a block

**`describe` at the top level** - the default when the module name already supplies the scope. No `context` is needed if the module is small or medium and the `describe` blocks all apply to the same implicit scope:

```elixir
# good — describe at top level; module name is the scope
describe "when the input is nil" do
  it "returns a default value"
  it "logs a warning"
end

describe "when the input is out of range" do
  it "returns an error"
  it "does not update the state"
end

# avoid — context wrapper adds a nesting level that contributes nothing
context "edge cases:" do
  describe "when the input is nil" do
    it "returns a default value"
    it "logs a warning"
  end
end
```

**`context` for state, role, or subsystem** - use `context` when the tests run under a specific state, role, or subsystem scope that the module name does not already imply. The context string names the scope, not a behavior:

```elixir
# good — "logged in user" is the state the tests apply under;
# `describe` names the action within that state
context "logged in user" do
  describe "when making a purchase" do
    it "returns 200 when the transaction succeeds"
    it "returns 404 if the item is not found"
    it "returns 204 when the item is removed from the cart"
  end
end
```

**`context → it` directly** is valid but less common. It fits when a shared scope applies but the tests inside it do not share a common action or scenario that would warrant a `describe` layer:

```elixir
# good — context scopes to a state; each it is a separate behavior
# under that state
context "logged in user" do
  it "can view the dashboard"
  it "can update their profile"
end
```

**`context` for a category or subsystem grouping** - use `context` when multiple `describe` blocks share a parent scope that the module name does not imply. The context names the scope, not a scenario:

```elixir
# good — context scopes to the nvdefine function; describe blocks are
# the scenarios being tested within that scope
context "nvdefine:" do
  it "allocates an index, chosen by the TPM"

  describe "allocates an index at a specified address" do
    specify do
      # assertion...
    end

    it "returns an error if the address is already defined"
  end

  describe "allocates an index with a specified size" do
    let :size, do: 4096

    specify do
      # assertion...
    end

    it "returns an error if the TPM is out of memory"
  end
end
```

**Description concatenation** - ESpec concatenates the descriptions of nested blocks when printing test output. Once the keywords are chosen by semantic role, the concatenation usually reads naturally: `context "logged in user"` + `describe "when making a purchase"` + `it "returns 200 when the transaction succeeds"` prints as "logged in user when making a purchase returns 200 when the transaction succeeds" - a full specification of the state, action, and outcome. Source code readability is the tiebreaker: if a chain-friendly description reads awkwardly in code, adjust it.

**`describe` + `specify` for single tests with setup** - when a `describe` exists solely to scope `before`/`finally` for a single test, put the full description on `describe` and use a bare `specify` (no string) for the test body. This avoids duplicating the description between `describe` and `it`:

```elixir
# good — describe carries the description, specify is the bare assertion
describe "reports a normal reading when lux is over the threshold" do
  before do
    Resolve.inject(MyApp.Serial, quote do
      def request({:read, 1, 0x0000, 2}), do: {:ok, [0, 100]}
    end)

    {:ok, pid} = MyApp.Sensor.start_link(nil)

    {:shared, pid: pid}
  end

  specify do
    assert_receive %PropertyTable.Event{property: ["lux"], value: 100}
  end
end

# avoid — description split across describe and it
describe "when lux is over the threshold" do
  before do
    # same setup...
  end

  it "reports a normal reading" do
    assert_receive %PropertyTable.Event{property: ["lux"], value: 100}
  end
end
```

**Do not wrap a lone `it` in `describe` unless the `describe` scopes setup.** When tests share a parent's `before`/`finally` and need no per-scenario setup, use `it` directly:

```elixir
# good — it blocks share the context's setup directly
context "output control:" do
  before do
    # shared setup...
  end

  it "turns on the output when lux is below the threshold"
  it "turns off the output when lux is at the threshold"
end

# avoid — describe wraps a single it but scopes no setup
context "output control:" do
  before do
    # shared setup...
  end

  describe "when lux is below the threshold" do
    it "turns on the output"
  end

  describe "when lux is at the threshold" do
    it "turns off the output"
  end
end
```

**`before`/`finally` scoping** — multiple tests sharing setup is a primary signal to introduce a block. The block scopes the setup to exactly those tests; setup lives in one place rather than being repeated:

```elixir
# good — context scopes the shared setup
context "active session" do
  before do
    {:ok, pid} = Session.start_link(host: "localhost")

    {:shared, pid: pid}
  end

  finally do
    GenServer.stop(shared.pid)
  end

  it "can send a command"
  it "can receive a response"
  it "keeps running after a timeout"
end

# avoid — identical before/finally repeated across blocks
describe "when sending a command" do
  before do
    {:ok, pid} = Session.start_link(host: "localhost")

    {:shared, pid: pid}
  end

  finally do
    GenServer.stop(shared.pid)
  end

  it "..."
end

describe "when receiving a response" do
  before do
    {:ok, pid} = Session.start_link(host: "localhost")

    {:shared, pid: pid}
  end

  finally do
    GenServer.stop(shared.pid)
  end

  it "..."
end
```

Do not include function arity in test strings (`connect/2`, `request/1`). Arity notation is not English and breaks prose. The function name alone is sufficient - a developer can see the arity from the arguments in the test code.

`context` is a grouping label, not a test description. Grouping tests by the function they exercise is valid when all nested tests are about that function's behavior. The check: does `context + it` concatenate into grammatical prose?

```elixir
# good — context groups tests around a function; concatenation reads naturally
# prints: "write_output can turn on a digital output"
context "write_output" do
  it "can turn on a digital output"
  it "can turn off a digital output"
end

# avoid — arity notation is not English, breaks prose
context "connect/2" do
  it "returns :ok"
end

# good — concept-based grouping
context "connection" do
  describe "when the host is unreachable" do
    it "returns an error"
  end
end

# good — behavioral scenarios
describe "when steps are added to the pipeline" do
  it "can execute them in order"
end

# avoid — abstract operation names
describe "adding steps" do
  it "..."
end

describe "validation" do
  it "..."
end
```

Do not name `describe` blocks after function names ("run/2", "adding steps") or abstract operation names ("validation", "execution"). These mirror the code's structure rather than its behavior. Reframe as scenarios: "when ..." or descriptions of what the system does. However, `context` blocks named after a function (without arity) are acceptable when the tests are scoping to that function as a subsystem - `context` is scoping, not describing.

**Colon-suffix context labels** - `context` blocks may use short noun phrases with a colon suffix (e.g. `context "cache operations:"`, `context "TTL expiration:"`). The colon is a readability aid for cases where the context label would otherwise run into the nested test description awkwardly when ESpec concatenates them in output. It is not a grammatical requirement - a bare noun like `context "sensor"` does not need a colon, because "sensor returns the calibrated value" already reads cleanly. Use the colon when the label is a multi-word noun phrase that would run together awkwardly with the nested description, and omit it otherwise. This convention applies to `context` only, not `describe`.

The keyword choice inside the block still follows the `it`/`specify` rule on its own merits. A multi-word context label combined with the colon suffix interacts with both `it` and `specify` the same way a bare context would:

```elixir
# good — `specify` for a standalone proposition. Reads:
# "cache operations: stale entries are dropped after the TTL expires"
context "cache operations:" do
  specify "stale entries are dropped after the TTL expires" do
    # ...
  end
end

# good — `it` when the string reads as a predicate of the subject. Reads:
# "cache operations: drops stale entries after the TTL expires".
# Standalone test reads "it drops stale entries after the TTL expires".
context "cache operations:" do
  it "drops stale entries after the TTL expires" do
    # ...
  end
end

# avoid — `it` with a string that does not fit after the pronoun.
# Standalone reads "it stale entries are dropped" - broken. Either switch
# to `specify`, or rewrite the string to lead with a verb.
context "cache operations:" do
  it "stale entries are dropped" do
    # ...
  end
end
```

The colon is what makes the label readable; the `it`/`specify` keyword choice is decided entirely by whether the string reads as a predicate of the subject.

**When to deviate**: a flat list of `it` blocks without any grouping is acceptable for simple specs with no meaningful structure.

---

### `it`, `specify`, and `specify do`

See [Test block keywords: semantic roles](#test-block-keywords-semantic-roles) for the underlying framing. `it` and `specify` are the two test-level keywords; this section covers when to use which.

`it` is the preferred test keyword in ESpec. Craft the description so "it [string]" reads as a well-formed sentence about the subject under test. Most behavior descriptions naturally want this shape, and starting from `it` pulls descriptions toward the specification style the Tests Are Specifications rule wants.

`it` always takes a string - `it do` is not a valid form in ESpec.

**Fall back to `specify`** when an accurate description of the test genuinely resists the `it` form - typically when the string has to introduce its own scenario subject or state a property, and rewriting it to fit after `it` would distort the meaning or bury the point. `specify` reads as just the string - no pronoun to attach, no predicate to form.

Do not force a description into `it` at the cost of accuracy. But also do not reach for `specify` when a simple rewrite of the description would make `it` work.

**Converting a `specify` wording to `it`.** The practical tool is adding an auxiliary or linking verb - `can`, `has`, `is`, `does`, `returns`, or the subject's own conjugated verb. These give the "it" pronoun something to predicate against. Most descriptions that read awkwardly after `it` become clean when the right verb is supplied, and the rewrite usually forces a more accurate description of the behavior as a side effect.

```elixir
# specify "brightness value"             → it "has a brightness value"
# specify "send notification"            → it "can notify a child device"
# specify "activate alarm when too cold" → it "activates an alarm when the temperature is too cold"
```

A noun-leading scenario can often be restructured into an `it` form by moving the scenario into a `when` clause, so the subject-under-test reclaims the front of the sentence:

```elixir
# specify "value out of range returns error"
#   → it "returns an error when the value is out of range"
```

Concatenates with `context "sensor"` to "sensor returns an error when the value is out of range". Use this technique when the scenario is cleanly expressible as a `when`-clause; fall back to `specify` when the scenario subject carries too much weight to demote.

**Requirement-style language** - test descriptions should read as specifications or behavioral contracts, not as narrations of test steps. Start with a word that signals a requirement: `can`, `returns`, `has`, `is`, `does not`. These frame the test as defining what the system does, not what the test does.

Every `it` string must read as a specification, not a procedural narration. If the description sounds like a narration of what the test code does step by step, rewrite it. "parses string values" → "can parse string values"; "sends a request" → "can send a request"; "builds a nested map" → "returns a nested map".

```elixir
# good — requirement-style language (specifications)
it "can turn on the output port"
it "returns :ok on success"
it "has an initialized state after startup"
it "is a valid configuration struct"
it "does not publish a value when the request fails"
it "reports the current lux reading"

# avoid — procedural descriptions (sounds like narrating test steps)
it "turns on the output"
it "sends a request"
it "parses string values"
it "builds a nested map"

# avoid — implementation details or meaningless descriptions
it "sends the correct command"   # what is a "correct" command?
it "controlling DO0 based on lux" # "DO0" is an implementation detail

# avoid — redundant: the describe already supplies "when lux is below the
# threshold", so the it string repeats it
describe "when lux is below the threshold" do
  it "turns on the output when lux is below the threshold"
end

# good — the it string drops what the describe already provides
describe "when lux is below the threshold" do
  it "turns on the output"
end

# good — specify: property or constraint
context "zone name validation" do
  specify "name can start with a single underscore" do
    {status, _} = Zone.add("_zone")

    status |> should(eq :ok)
  end

  specify "name cannot start with a double underscore" do
    Zone.add("__zone") |> should(eq {:error, :invalid})
  end
end

# good — specify: qualifier continuing the parent phrase
# prints: "register a device with a custom polling interval"
describe "register a device" do
  specify "with a custom polling interval" do
    Device.register(:sensor, interval: 500) |> should(eq :ok)
  end

  specify "with the default polling interval" do
    Device.register(:sensor) |> should(eq :ok)
  end
end
```

**`specify do` without a string** — when the parent `describe` is the complete, self-sufficient description of the test, use `specify do` with no string. Appropriate when there is one primary test for a `describe` and the `describe` text fully describes what it verifies. `specify do` reads as "specify [the behavior described above]":

```elixir
# good — describe is the full description; no string needed
describe "defaults to port 6379" do
  let :uri, do: "mydb://host"

  specify do
    {:ok, conn} = Client.connect(uri())

    conn.port |> should(eq 6379)
  end
end

describe "add a device" do
  specify do
    Device.add(:sensor, "temp_1", opts())
    |> should(eq {:ok, device()})
  end
end

# good — specify do for the primary case alongside it for edge cases
describe "remove a device" do
  specify do
    Device.remove("temp_1") |> should(eq {:ok, device()})
  end

  it "returns an error if the device does not exist" do
    Device.remove("unknown") |> should(eq {:error, :not_found})
  end
end

# avoid — it without a string does not parse grammatically
describe "add a device" do
  it do
    Device.add(:sensor, "temp_1", opts()) |> should(eq {:ok, device()})
  end
end
```

When a `describe` has multiple tests that each need a distinguishing description, `specify do` is not appropriate — use `it` or `specify` with a string for each:

```elixir
# avoid — specify do when multiple tests need distinguishing descriptions
describe "remove a device" do
  specify do  # which removal case is this?
    ...
  end

  it "returns an error if the device does not exist" do
    ...
  end
end

# good — specify do only when it is the one primary test
describe "remove a device" do
  specify do
    Device.remove("temp_1") |> should(eq {:ok, device()})
  end
end
```

---

### Assertion Style

Use `should` and `should_not` for assertions. The subject flows naturally through the pipe, and no parentheses are required.

```elixir
# good
result |> should(eq :ok)
result |> should_not(eq :error)

# good — subject flows through a pipe chain
{value(), unix_timestamp()}
|> Result.to_iso8601
|> should(eq expected())
```

**Line wrapping** — when the subject or assertion is complex, wrap on `|>` to separate them. This divides the line into two independently understandable units. When multiple wrapped assertions appear together, separate each with a blank line. Short, related assertions stay on one line with no blank lines between them — the grouping communicates their relationship:

```elixir
# good — complex line: wrap on |> to separate subject from assertion
Device.add(:sensor, "temp_1", opts())
|> should(eq {:ok, device()})

# good — multiple wrapped assertions separated by blank lines
Device.add(:sensor, "temp_1", opts())
|> should(eq {:ok, device()})

Device.add(:sensor, "temp_2", opts())
|> should(eq {:ok, device()})

# good — short related assertions kept together; blank lines would break the flow
value_1 |> should(eq 10)
value_2 |> should(eq 20)
value_3 |> should(eq 30)
```

**Matchers** — avoid helpers that are syntax sugar around primitive values. When a matcher wraps a value you can express directly with `eq`, use `eq`:

```elixir
# avoid — sugar around primitives
result |> should(be_ok())   # :ok is just an atom
value |> should(be_nil())   # nil is just nil
flag |> should(be_true())   # testing literal true
flag |> should(be_false())  # testing literal false

# good — express primitive values directly
result |> should(eq :ok)
value |> should(eq nil)
flag |> should(eq true)
flag |> should(eq false)
```

Use `be_truthy` and `be_falsy` when testing Elixir truthiness — these are semantically different from `eq true`/`eq false`. In Elixir, only `nil` and `false` are falsy; everything else is truthy:

```elixir
# good — be_truthy/be_falsy test truthiness, not literal true/false
[] |> should(be_truthy())      # [] != true, but [] is truthy
0 |> should(be_truthy())       # 0 != true, but 0 is truthy
:error |> should(be_truthy())  # :error != true, but :error is truthy
nil |> should(be_falsy())
false |> should(be_falsy())

# avoid — eq true/false when truthiness is what's meant
[] |> should(eq true)  # wrong — [] is not equal to true
```

**Assertion must match the claim.** The assertion in a test must verify what the test description says it verifies. If the description says "does not raise", the assertion must test for exceptions - not truthiness of a return value. A mismatched assertion creates a test that always passes regardless of whether the claimed behavior holds.

Use `raise_exception` to test that code raises, and negate it to test that code does not raise:

```elixir
# good — testing that a function does not raise
it "does not raise when the input is invalid" do
  expect(fn -> Parser.parse("bad input") end)
  |> to_not(raise_exception())
end

# good — testing that a specific exception is raised
it "raises when the key is missing" do
  expect(fn -> Config.fetch!(:missing) end)
  |> to(raise_exception KeyError)
end

# good — testing exception with message
it "raises with a descriptive message" do
  expect(fn -> Config.fetch!(:missing) end)
  |> to(raise_exception KeyError, "key :missing not found")
end

# WRONG — "does not raise" but tests truthiness instead
it "does not raise" do
  result = Parser.parse("bad input")
  result |> should(be_truthy())  # vacuous — {:error, _} is truthy
end
```

Do not use `should(be_truthy())` to test that code does not raise. This is logically wrong - the assertion tests return value truthiness, not absence of exceptions. If the function raised, the test would fail due to the exception itself, making the assertion redundant. If the function returns an error tuple, the assertion passes because error tuples are truthy. Use `expect(fn -> ... end) |> to_not(raise_exception())` to test that code does not raise.

Other semantic matchers are appropriate when they test behavior with no primitive equivalent:

```elixir
pid |> should(be_alive())
collection |> should(be_empty())
value |> should(be_integer())
value |> should(be_binary())
```

ESpec matchers like `be_integer()`, `be_alive()`, `be_empty()`, `be_binary()`, `be_truthy()`, `be_falsy()`, `be_ok_result()` are function calls that return matcher structs. They MUST keep their parentheses. The zero-arity type parentheses rule (no parens on `integer`, `binary`, `atom` in `@type`/`@spec`) does NOT apply to matcher function calls. Do not strip parens from matchers.

`be_ok_result()` tests `{:ok, _}` — any value wrapped in `:ok`. This is semantically different from `eq :ok`, which tests the bare atom:

```elixir
# be_ok_result matches any {:ok, value}
Client.connect(uri()) |> should(be_ok_result())

# eq :ok only matches the bare atom — wrong for {:ok, value} return types
Client.connect(uri()) |> should(eq :ok)  # avoid — would fail
```

Use `expect |> to(accepted ...)` for mock acceptance verification — this is its primary purpose and has no equivalent in the `should` style.

```elixir
expect(Crypto) |> to(accepted :get_key, [])
expect(PropertyTable) |> to(accepted :put, :any)
```

Use `assert_receive` and `refute_receive` for message-passing assertions.

```elixir
assert_receive :configuration_done
refute_receive {:error, _}
```

When asserting on struct patterns, treat each `assert_receive` as a wrapped assertion — add a blank line between them. Struct patterns have high cognitive load even when they fit on one line. Simple atom or tuple assertions stay grouped:

```elixir
# good — struct patterns: blank line between assertions
assert_receive %MyApp.Event{
  property: ["device", "status"],
  value: :connected,
}

assert_receive %MyApp.Event{
  property: ["device", "status"],
  value: :disconnected,
}

# good — simple atoms or tuples: stay grouped
assert_receive :published
assert_receive :acknowledged
```

Do not use the RSpec-style `expect(smth).to eq(smth)` — this syntax is broken on OTP 21 and above.

---

### let and let!

Use `let` to define named, lazily-evaluated values for use across examples in a context. The value is computed on first call and memoized for the duration of that example — it resets between examples.

Call `let`-defined values as zero-arity functions: `user()`, `token()`.

`let` values are runtime function calls and cannot be used directly in pattern match positions — `assert_receive`, `receive`, `case` patterns, and function head matches are all compile-time patterns. Assign the `let` value to a local variable and pin it:

```elixir
# good — assign let value to local variable, pin in pattern
let :register, do: 0x0010

it "sends the command" do
  register = register()

  MyApp.Device.write(register, 100)

  assert_receive {:request, {:phr, 1, ^register, 100}}
end

# good — let value in assertion body (not a pattern, evaluated at runtime)
let :register, do: 0x0010

it "sends the command" do
  MyApp.Device.write(0x0010, 100)

  command |> should(eq {:phr, 1, register(), 100})

  assert_receive {:request, command}
end

# acceptable as a one-off — literal value in pattern
# avoid when the value is repeated across tests; use let instead
it "sends the command" do
  MyApp.Device.write(0x0010, 100)

  assert_receive {:request, {:phr, 1, 0x0010, 100}}
end
```

Always use the `do` form — this keeps all `let` definitions consistent regardless of value complexity:

```elixir
# good — consistent do form for all values
let :name, do: "Alex"
let :role, do: :admin
let :settings, do: %{retries: 3, timeout: 5000}

let :connection do
  {:ok, conn} = MyApp.connect(opts())
  conn
end

# avoid — mixing keyword shorthand with do blocks
let name: "Alex"
let :settings, do: %{retries: 3, timeout: 5000}
```

Use `let!` when the value must be evaluated before the example runs — for example, when a `before` block depends on it, or when side effects must happen eagerly:

```elixir
let! :started_server, do: MyApp.Server.start_link
```

Extract test inputs and outputs to `let` bindings so assertions read as concepts, not magic numbers. When a reader sees `{:fc, channel(), address(), 1}`, each component is a named concept. When they see `{:fc, 1, 0x0010, 1}`, they have to decode what each literal means - cognitive overhead that scales with every assertion. The name documents the value and provides a single place to change it. Use `let_overridable` or context-level `let` overrides when the same conceptual value differs between test groups.

Extracting literals also reveals duplication in test bodies. When two tests differ only in their `let` values, the bodies are identical - a signal that shared examples can DRY the code further.

Leave values inline when they are descriptive domain terms that are fixed and self-documenting:

```elixir
# good — shared values extracted to let; domain terms stay inline
let :slave_id, do: 1
let :register, do: 0x0010

it "can write a value to the register" do
  slave_id = slave_id()
  register = register()

  MyApp.Device.write(register, 100)

  # :phr is a protocol command (preset holding register) — descriptive, not magic
  assert_receive {:request, {:phr, slave_id, register, 100}}
end

it "can read a value from the register" do
  slave_id = slave_id()
  register = register()

  MyApp.Device.read(register)

  assert_receive {:request, {:rhr, slave_id, register, 1}}
end

# avoid — magic numbers repeated across tests
it "can write a value to the register" do
  MyApp.Device.write(0x0010, 100)

  assert_receive {:request, {:phr, 1, 0x0010, 100}}
end

it "can read a value from the register" do
  MyApp.Device.read(0x0010)

  assert_receive {:request, {:rhr, 1, 0x0010, 1}}
end
```

The distinction: extract to `let` when the value is **a numeric or opaque literal whose meaning isn't obvious from context** (a channel number, an address, a threshold). The name replaces cognitive decoding with a concept. Leave inline when the value is **a descriptive domain term that is fixed** (`:fc` for force coil, `:rhr` for read holding register, `:on`/`:off`).

Do not use `subject`. Define test values as named `let` bindings instead — it is consistent with the rest of the spec and equally readable.

**When to deviate**: Inline values are fine when a value is used only once and naming it adds no clarity.

---

### before, finally, and shared state

Use `before` to set up state before each example. Use `finally` for teardown. Return `{:shared, key: value}` from `before` to pass values to examples and nested contexts.

```elixir
before do
  {:ok, pid} = MyApp.Server.start_link

  {:shared, pid: pid}
end

finally do
  GenServer.stop(shared.pid)
end

it "responds to requests" do
  shared.pid |> should_not(eq nil)
end
```

When a `before` block has multiple setup steps, apply the same blank line rules as in any function body. Separate distinct setup phases with blank lines. Always add a blank line before `{:shared, ...}` — it is the return value of the block and must be visually separated from the preceding setup.

Do not omit the blank line before `{:shared, ...}`. Treat it like a return value in a function - it always gets a blank line above it when preceded by other statements.

```elixir
# good — blank lines between distinct setup phases; blank line before {:shared, ...}
before do
  test_pid = self()

  Resolve.inject(MyApp.Mailer, quote do
    def send_email(_to, _body) do
      send(unquote(test_pid), :email_sent)
      :ok
    end
  end)

  {:ok, pid} = MyApp.Service.start_link

  {:shared, pid: pid}
end

# avoid — cramped; {:shared, ...} buried without visual separation
before do
  test_pid = self()
  Resolve.inject(MyApp.Mailer, quote do
    def send_email(_to, _body) do
      send(unquote(test_pid), :email_sent)
      :ok
    end
  end)
  {:ok, pid} = MyApp.Service.start_link()
  {:shared, pid: pid}
end
```

Nested contexts inherit `shared` from their parent and can extend it:

```elixir
before do
  {:shared, user: create_user()}
end

context "admin role" do
  before do
    {:shared, user: %{shared.user | role: :admin}}
  end

  it "can access the dashboard" do
    # shared.user has role: :admin
  end
end
```

Use `before_all` and `after_all` for setup that runs once per module — expensive resources like database connections or server processes that are safe to share across all examples. `before_all` does not have access to `shared`.

```elixir
before_all do
  {:ok, _} = start_supervised(MyApp.Repo)
end
```

**When to deviate**: When teardown is not needed, omit `finally`. When no state needs to be shared, `before` can return `:ok` or simply perform side effects without a return value.

---

### async

ESpec runs examples synchronously by default. No declaration is needed for most specs. Set `async: true` only for specs that are fully stateless and do not use mocks or Resolve.

```elixir
# default — synchronous, no declaration needed
defmodule MyApp.Parser.Spec do
  use ESpec
end

# explicitly async — only when truly stateless
defmodule MyApp.Calculator.Spec do
  use ESpec, async: true
end
```

Never use `async: true` with mocks or Resolve — both use global state (Meck modifies module bytecode globally; Resolve uses a global ETS table) and will cause interference across concurrent examples.

**When to deviate**: Explicitly declaring `async: false` is acceptable when it serves as documentation that a spec has stateful dependencies.

---

### Pending Examples

An `it` or `specify` block with no body is a pending example — ESpec marks it as pending, not as a failure. Use pending examples to document intended behavior that has not yet been implemented.

```elixir
it "handles the edge case when input is empty"   # pending — not a failure
```

Do not leave pending examples in finished code. A pending example in a merged spec signals unfinished work.

Empty spec files (a module with `use ESpec` and no tests) are not acceptable deliverables. If a module has public functions, it needs tests. The only exception is a placeholder spec file for a placeholder module that has no implementation yet.

---

### Resolve — Production Code Pattern

Modules that use Resolve as a dependency injection point call `use Resolve` and delegate to `resolve(__MODULE__)` at the call site. The module itself is both the key and the default — if no injection is active, it resolves to itself.

```elixir
defmodule MyApp.GPIO do
  use Resolve

  def write(pin, value), do: resolve(__MODULE__).write(pin, value)
  def read(pin), do: resolve(__MODULE__).read(pin)
end
```

No behaviour definition is required. The injected module only needs to export the functions that will be called.

---

### Mocking and Dependency Injection

Use ESpec's built-in mocking (via Meck) to stub module functions. Use Resolve for dependency injection, like when the code under test runs in a separate process.

**Mocking with allow/accept** — stubs a function for the duration of an example. Mocks are automatically unloaded after each example.

```elixir
allow(MyApp.Mailer) |> to(accept :send_email, fn _to, _body -> :ok end)
```

Use pattern matching in the mock body to handle multiple call signatures and assert on arguments. Signal the test process via `send` to verify side effects:

```elixir
allow(MyApp.Mailer) |> to(accept :send_email, fn
  "admin@example.com", body ->
    body |> should(have "alert")
    send(test_runner_pid, :admin_notified)
    :ok

  _to, _body ->
    :ok
end)

assert_receive :admin_notified
expect(MyApp.Mailer) |> to(accepted :send_email, :any)
```

**Dependency injection with Resolve** — use when replacing behavior inside a GenServer or other separate process, or when swapping out entire components. Resolve uses a global ETS table visible to all processes, making it effective across process boundaries where Meck cannot reach.

Use `Resolve.inject` directly in a test to inline a stub implementation. Always revert in `finally` to avoid leaking state into subsequent examples:

```elixir
before do
  test_pid = self()

  Resolve.inject(MyApp.GPIO, quote do
    def write(pin, value) do
      send(unquote(test_pid), {:gpio_write, pin, value})
      :ok
    end
  end)
end

finally do
  Resolve.revert(MyApp.GPIO)
end
```

**Meck vs Resolve — when to use which:**

- **Meck (`allow/accept`)**: stubs functions in the same process. Use when the test directly calls the function being mocked.
- **Resolve (`Resolve.inject`)**: replaces a module across all processes via a global ETS table. Use when the code under test runs in a separate process (GenServer, `gen_statem`, Task) and calls the dependency through `resolve(Module)`.

When a module uses `use Resolve` and calls dependencies via `resolve(MyApp.Hardware).request(cmd)`, you must use `Resolve.inject` - not `allow/accept`. Meck stubs are per-process and will not be visible to the GenServer.

```elixir
# WRONG — Meck mock not visible to the GenServer process
before do
  allow(MyApp.Hardware) |> to(accept :request, fn _cmd -> :ok end)

  {:ok, pid} = MyApp.Controller.start_link([])

  {:shared, pid: pid}
end

it "sends the command" do
  MyApp.Controller.write(0, :on)
  # Controller's handle_call runs in the GenServer process
  # It calls resolve(MyApp.Hardware).request(cmd)
  # Meck mock is not visible there → :noproc error
end

# RIGHT — Resolve.inject replaces the module for all processes
before do
  test_pid = self()

  Resolve.inject(MyApp.Hardware, quote do
    def request(command) do
      send(unquote(test_pid), {:hw_request, command})
      :ok
    end
  end)

  {:ok, pid} = MyApp.Controller.start_link([])

  {:shared, pid: pid}
end

finally do
  Resolve.revert(MyApp.Hardware)
end

it "sends the command" do
  MyApp.Controller.write(0, :on)
  # Controller calls resolve(MyApp.Hardware).request(cmd)
  # Resolve returns the injected module → message sent to test process
  assert_receive {:hw_request, {:fc, 1, 0x0010, 1}}
end
```

CAUTION: If you see a `:noproc` error in a test that uses Resolve, check whether Meck (`allow/accept`) is being used where `Resolve.inject` is needed. Meck operates per-process, so mocking a module that a GenServer calls through Resolve always fails with `:noproc` because the GenServer is a separate process. The fix is always `Resolve.inject`.

Prefer ESpec/Meck over Mox — it does not require behaviour definitions and integrates naturally with ESpec. If a project already uses Mox, follow local precedence and apply the same principles: clear setup, meaningful assertions, and proper teardown.

**Signal-and-assert pattern** — the standard approach for testing asynchronous side effects. Inside a mock callback, `send` a signal to the test process, then `assert_receive` after triggering the action under test. This proves the mock was actually invoked with the right arguments — not merely that no error was raised.

When the mock runs in the same process (Meck), `self()` refers to the test process directly:

```elixir
allow(MyApp.Mailer) |> to(accept :send_email, fn
  "admin@example.com", _body ->
    send(self(), :admin_notified)
    :ok

  _to, _body ->
    :ok
end)

trigger_action()

assert_receive :admin_notified
```

When the mock runs in a different process (Resolve, GenServer), capture `self()` before the `quote` block and splice it with `unquote`. Inside a `quote` block, `self()` is quoted as AST - it is not evaluated until the injected module runs, at which point it resolves to the GenServer's pid, not the test process:

This is a common mistake when generating `Resolve.inject` code. `self()` inside `quote do ... end` does NOT refer to the test process - it refers to whatever process calls the injected function at runtime. Always capture `self()` into a variable before the `quote` block and use `unquote(variable)` to splice the test pid into the AST.

Failure mode when this is wrong: the message is sent to the GenServer (which called the injected function). The GenServer has no `handle_info` clause for the test message, so it crashes with `FunctionClauseError` pointing at the source module's `handle_info` - completely misleading. If you see a `FunctionClauseError` in `handle_info` with a test-specific message (signal atoms, test tuples), check whether `self()` was used directly inside a `quote` block instead of being captured beforehand.

```elixir
test_pid = self()

Resolve.inject(MyApp.Mailer, quote do
  def send_email("admin@example.com", _body) do
    send(unquote(test_pid), :admin_notified)
    :ok
  end
end)

trigger_action()

assert_receive :admin_notified
```

The signal atom should describe what happened (`:admin_notified`, `:shadow_published`) — not what was called (`:send_email_called`). Name it from the domain, not the implementation.

---

### Shared Examples

Define shared examples in a module with `use ESpec, shared: true`. Nest shared examples inside the spec module when they are only relevant to that spec - this keeps the namespace short and avoids making a file-local concern appear global. Extract to `spec/shared/` under its own namespace only when the shared example is reused across multiple spec files.

```elixir
# good — nested inside the spec module; scoped to this file
defmodule MyApp.Session.Spec do
  use ESpec

  defmodule AuthenticatedUser do
    use ESpec, shared: true

    it "has a valid session" do
      shared.user.session |> should_not(eq nil)
    end

    it "has a role assigned" do
      shared.user.role |> should_not(eq nil)
    end
  end

  include_examples(AuthenticatedUser)
end

# good — extracted to spec/shared/ when reused across multiple files
# file: spec/shared/authenticated_user.exs
defmodule MyApp.Shared.AuthenticatedUser do
  use ESpec, shared: true

  it "has a valid session" do
    shared.user.session |> should_not(eq nil)
  end

  it "has a role assigned" do
    shared.user.role |> should_not(eq nil)
  end
end
```

Include shared examples with `include_examples` or `it_behaves_like`. Prefer `include_examples` when DRYing repetitive setup or assertions - the shared module provides reusable pieces, not a behavioral contract. Use `it_behaves_like` when the shared examples describe a behavioral interface that multiple subjects should conform to - this is more common in object-oriented code (Ruby/RSpec) than in Elixir's functional style.

```elixir
# good — include_examples: DRYing shared setup and assertions
describe "admin user" do
  before do
    {:shared, user: create_admin()}
  end

  include_examples(AuthenticatedUser)
end

# good — it_behaves_like: behavioral conformance (less common in Elixir)
it_behaves_like(MyApp.Shared.Serializable)
```

Use `let_overridable` in shared specs to define values the including spec can override:

```elixir
defmodule MyApp.Shared.Paginated do
  use ESpec, shared: true

  let_overridable page: 1, per_page: 20

  it "returns the correct page size" do
    results() |> Enum.count |> should(eq per_page())
  end
end

include_examples(MyApp.Shared.Paginated, per_page: 10)
```

**Shared examples as setup templates** - when multiple contexts repeat identical `before`/`finally` blocks and only a parameter varies, a shared example can serve as a template. Define `let_overridable` for every value that varies between calling contexts - not just the obvious one. Include both the `before` and `finally` blocks in the shared example so it is self-contained. The calling context overrides the parameters and defines its own `it` blocks:

When building a shared example template, identify ALL values that differ between calling contexts and expose them via `let_overridable`. It is easy to parameterize the most obvious value (e.g. a return value) while hardcoding others (e.g. function arguments) that should also vary per test. Review each literal in the `before` block and ask whether it should be overridable.

```elixir
# good - all varying values exposed via let_overridable
defmodule MyApp.Sensor.Spec do
  use ESpec, async: false

  alias MyApp.Sensor

  defmodule HardwareStub do
    use ESpec, shared: true

    let_overridable \
      hardware_request: {:rhr, 1, 0, 2},
      hardware_response: {:ok, [0, 100]}

    before do
      Resolve.inject(MyApp.Hardware, quote do
        def request(unquote(hardware_request())) do
          unquote(hardware_response())
        end
      end)

      PropertyTable.subscribe(Sensors, ["sensor", "value"])
      {:ok, pid} = Sensor.start_link

      {:shared, pid: pid}
    end

    finally do
      Resolve.revert(MyApp.Hardware)
    end

    # At least one `it` block is required - see caveat below.
    it "starts the sensor process" do
      shared.pid |> should(be_alive())
    end
  end

  describe "when the sensor returns a normal reading" do
    include_examples(HardwareStub,
      hardware_response: {:ok, [0, 100]}
    )

    it "reports the reading" do
      assert_receive %PropertyTable.Event{
        property: ["sensor", "value"],
        value: 100,
      }
    end
  end

  describe "when the request fails" do
    include_examples(HardwareStub,
      hardware_response: {:error, :timeout}
    )

    it "does not publish a value" do
      refute_receive %PropertyTable.Event{property: ["sensor", "value"]}
    end
  end
end
```

Both `include_examples` and `it_behaves_like` import `before`/`finally` blocks through `example.context`, which is attached to individual examples. If the shared module has no `it` blocks, `Enum.each(module.examples, ...)` is a no-op and the `before`/`finally` blocks are NOT merged into the calling context. This is an ESpec implementation detail, not obvious from the API. Always include at least one `it` block in shared examples that define `before`/`finally`.

**Caveat: shared examples must contain at least one `it` block** for their `before` and `finally` blocks to take effect in the calling context. ESpec attaches setup and teardown to individual examples internally - a shared module with no examples has no vehicle to carry its `before`/`finally` into the calling spec.

**Alternate: module-level setup with context-level overrides** - for projects not using ESpec, or when a shared `it` block would be forced, module-level `before`/`finally` with `let` overrides avoids shared examples altogether. This approach has a gotcha: `let` values spliced into `quote` blocks via `unquote` must be valid Elixir AST. Tuples with more than 3 elements (e.g. `{:rhr, 1, 0, 2}`) are not valid AST and will raise `ArgumentError`. Wrap them with `Macro.escape/1`:

`unquote` expects valid Elixir AST nodes (2- or 3-element tuples). Simple values (atoms, integers, strings, 2-element tuples like `{:ok, [0, 100]}`) work with bare `unquote`. Complex terms (4-element tuples, nested structs) require `Macro.escape/1`. This is easy to miss because the error only surfaces at runtime when the `before` block executes. When generating code that uses `let` values inside `quote`/`unquote`, always consider whether the value might not be valid AST and wrap with `Macro.escape` proactively.

```elixir
# alternate - module-level setup, each describe overrides the parameter
defmodule MyApp.Sensor.Spec do
  use ESpec, async: false

  alias MyApp.Sensor

  before do
    # Macro.escape required: hardware_request() returns a 4-element tuple,
    # which is not valid AST for unquote.
    Resolve.inject(MyApp.Hardware, quote do
      def request(unquote(Macro.escape(hardware_request()))) do
        unquote(Macro.escape(hardware_response()))
      end
    end)

    PropertyTable.subscribe(Sensors, ["sensor", "value"])
    {:ok, pid} = Sensor.start_link

    {:shared, pid: pid}
  end

  finally do
    Resolve.revert(MyApp.Hardware)
  end

  describe "when the sensor returns a normal reading" do
    let :hardware_request, do: {:rhr, 1, 0, 2}
    let :hardware_response, do: {:ok, [0, 100]}

    it "reports the reading" do
      assert_receive %PropertyTable.Event{
        property: ["sensor", "value"],
        value: 100,
      }
    end
  end

  describe "when the request fails" do
    let :hardware_request, do: {:rhr, 1, 0, 2}
    let :hardware_response, do: {:error, :timeout}

    it "does not publish a value" do
      refute_receive %PropertyTable.Event{property: ["sensor", "value"]}
    end
  end
end
```

**When to deviate**: If shared examples grow large or are used across many files, move them to `spec/shared/` where they are auto-loaded by ESpec.

---

### Focus and Skip

When iterating on a specific test or context, use focus or file/line narrowing to run only the relevant examples rather than the full suite. This keeps the feedback loop tight.

Prefix `f` to focus a block or example; prefix `x` to skip. Run only focused examples with `--focus`.

```elixir
fdescribe "..."   # run only this describe
fcontext "..."    # run only this context
fit "..."         # run only this example

xdescribe "..."   # skip
xcontext "..."
xit "..."
```

Run focused tests: `mix espec --focus`
Run a single file: `mix espec spec/my_app/parser_spec.exs`
Run a specific line: `mix espec spec/my_app/parser_spec.exs:42`

Do not commit focused (`f`-prefixed) blocks — they silently exclude all other tests from the suite.

---

### ESpec Formatting

**`allow` with single-clause functions** — apply the line length rule from `general/CLAUDE.md`. Keep the function body inline when the line is within the soft limit. When it exceeds the soft limit, move the clause to its own line:

```elixir
# within soft limit — keep inline
allow(MyApp.Cache) |> to(accept :get, fn key ->
  Map.get(store(), key)
end)

# exceeds soft limit — clause on its own line
allow(MyApp.Device.Controller) |> to(accept :apply_profile, fn
  _, _, _, _ -> :ok
end)
```

When multiple related `allow` blocks appear together, use a consistent format across all of them. If one block needs the multi-line style, apply it to all:

```elixir
# good — consistent style across related blocks
allow(MyApp.Device.Controller) |> to(accept :poll, fn
  _, _ -> {:ok, default_poll}
end)

allow(MyApp.Device.Controller) |> to(accept :apply_profile, fn
  _, _, _, _ -> :ok
end)
```

**`accept` arguments** — do not use parentheses around the arguments to `accept`. Pass the function name and callback directly:

```elixir
# good
allow(MyApp.Server) |> to(accept :configure, fn _, _ -> :ok end)

# avoid — mix format adds parentheses
allow(MyApp.Server)
      |> to(
        accept(
          :configure,
          fn _, _ -> :ok end
        )
      )
```

**`allow` module** — newer Elixir requires parentheses on the first call in a pipe chain, so `allow(Module)` is required syntax, not a style choice. The pipe goes on the same line:

```elixir
# good
allow(MyApp.Store) |> to(accept :get, fn key ->
  Map.get(store(), key)
end)

# avoid — pipe broken to next line with no indent
allow(MyApp.Store)
|> to(accept :get, fn key -> Map.get(store(), key) end)
```

**`allow` with multi-clause functions** — keep the pipe and `fn` on one line with clauses at a shallow indent:

```elixir
# good
allow(MyApp.Mailer) |> to(accept :send_email, fn
  "admin@example.com", body ->
    send(test_pid, :admin_notified)
    :ok

  _to, _body ->
    :ok
end)

# avoid
allow(MyApp.Mailer)
      |> to(
        accept :send_email, fn
          "admin@example.com", body ->
            send(test_pid, :admin_notified)
            :ok

          _to, _body ->
            :ok
        end
      )
```

**`accept` with a keyword list** — when mocking multiple functions on one module, pass a keyword list to a single `accept`. The first key starts on the same line; each additional entry is a new keyword on its own line at the same indent. Use `fn -> ... end` for zero-argument functions — the capture operator `&` is not valid without arguments:

```elixir
# good
allow(MyApp.Scheduler) |> to(accept load_profiles: fn
  pid ->
    pid |> should(eq self())
    :ok
  end,
  list_all: fn -> [] end,
  get_pid: fn _device_id -> self() end
)

# avoid — mix format output; accept wrapped in parens, module on first line
allow MyApp.Scheduler
      |> to(
        accept(
          load_profiles: fn pid ->
            pid |> should(eq self())
            :ok
          end,
          list_all: fn -> [] end,
          get_pid: fn _device_id -> self() end
        )
      )
```

**`assert_receive`, `assert_received`, `refute_receive`, `refute_received`** — do not use parentheses around the pattern. Multi-line struct patterns follow naturally without wrapping parens:

```elixir
# good
assert_receive :published
assert_receive {:DOWN, _ref, :process, ^pid, :normal}
refute_receive {:DOWN, _ref, :process, ^pid, :normal}

assert_receive %MyApp.Event{
  table: Store,
  property: ["device", "status"],
  value: :connected,
}

# avoid
assert_receive(:published)
assert_receive({:DOWN, _ref, :process, ^pid, :normal})
assert_receive(%MyApp.Event{
  table: Store,
  property: ["device", "status"],
  value: :connected
})
```

**`Resolve.inject` with multiple function definitions** — all definitions live inside a single `quote do...end` block. Blank lines between definitions follow normal Elixir conventions:

```elixir
# good
Resolve.inject(MyApp.GPIO, quote do
  def open(_pin, :output, [initial_value: 0]),
    do: {:ok, self()}

  def open(_pin, _direction, _opts),
    do: raise "Unexpected args for open"

  def write(_pin, value) do
    send(unquote(test_pid), {:gpio, :write, value})
    :ok
  end
end)
```

**`expect` mock verification** — when verifying a mock call fits on one line, keep it inline. When the argument list is too long, break after the function name — which stays on the first line because it is the subject of the verification, not a generic argument:

```elixir
# good — fits on one line
expect(MyApp.Publisher) |> to(accepted :publish, :any)

# good — too long for one line; function name stays
# with to(accepted, args and options indent below
expect(MyApp.Publisher) |> to(accepted :publish,
  ["topic/updates", %{device_id: device_id}],
  count: 1
)

# avoid — pipe broken to next line
expect(MyApp.Publisher)
|> to(accepted :publish, ["topic/updates", %{device_id: device_id}], count: 1)
```

**`Resolve.inject`** — keep the module and `quote do` on the same line. The quoted body is indented inside the block:

```elixir
# good
Resolve.inject(MyApp.Network, quote do
  def configure("wlan0", _), do: :ok
end)

Resolve.inject(MyApp.Clock, quote do
  def now!(timezone) do
    DateTime.new!(~D[2024-01-01], ~T[08:00:00], timezone)
  end
end)

# avoid — module and quote block broken to separate lines
Resolve.inject(
  MyApp.Network,
  quote do
    def configure("wlan0", _), do: :ok
  end
)
```

`Resolve.revert/1` calls go in the `finally` block, one call per injected module:

```elixir
finally do
  Resolve.revert(MyApp.Network)
  Resolve.revert(MyApp.Clock)
end
```

**`let` with multi-line values** — when the value spans multiple lines, place `do:` on the next line, indented two spaces. Single-line values stay on the same line. Zero-arity function calls follow the Zero-Arity Calls rule — omit parentheses on module-qualified calls:

```elixir
# good — single-line value
let :uuid, do: UUID.uuid4

# good — multi-line value; do: on same line
let :settings, do: %{
  address: device_address(),
  retries: 3,
}

let :items, do: [
  %{name: "alpha", module: MyApp.Worker, restart: :permanent, timeout: 5_000}
]
```

When a list has a single item that is split across lines purely for readability — not because it is a multi-item list — omit the trailing comma. The purpose of a trailing comma is to simplify future additions and produce clean diffs; when the list is a fixed single-item fixture (common in tests), the comma adds noise without serving that purpose.

When the list grows to multiple items, each item on its own line with trailing commas:

```elixir
let :items, do: [
  %{name: "alpha", module: MyApp.Worker, restart: :permanent, timeout: 5_000},
  %{name: "beta", module: MyApp.Poller, restart: :transient, timeout: 1_000},
  %{name: "gamma", module: MyApp.Handler, restart: :temporary, timeout: 500},
]
```

An alternative for a single-item list is to open the collection inline, which avoids the single-item multi-line list entirely and allows trailing commas on the map fields:

```elixir
let :items, do: [%{
  name: "alpha",
  module: MyApp.Worker,
  restart: :permanent,
  timeout: 5_000,
}]
```

**`capture_log` and `with_log`** — assign the result to a variable and assert on it separately. Use `capture_log` when only the log output is needed; use `with_log` when both the return value and log output are needed:

```elixir
# good — capture_log: log output only
message = capture_log(fn ->
  MyApp.Worker.start |> should(eq {:error, :unavailable})
end)

message |> should(match "Unable to connect: unavailable")

# good — with_log: return value and log output
{result, message} = with_log(fn ->
  MyApp.Worker.start
end)

result |> should(eq {:error, :unavailable})
message |> should(match "Unable to connect: unavailable")
```

---
