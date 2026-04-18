# General Testing Principles

Testing rules that apply across all languages. Language-specific testing rules (framework syntax, assertion styles, mock libraries) are in `<lang>/testing.md`.

Load this file when writing or reviewing test code in any language.

---

## Tests Are Specifications

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

**Casing.** Test descriptions and grouping labels are written in lowercase. The exceptions are abbreviations and initialisms that are conventionally uppercase (HTTP, JSON, TCP, I2C) and proper nouns, which are rare in test descriptions. A description is prose inside a string literal, not a sentence at the top of a paragraph - there is no reason to capitalize the first word, and doing so creates visual noise when test frameworks concatenate nested block descriptions into output.

**Grouping blocks** - many test frameworks provide one or more grouping keywords (e.g. `describe`, `context` in ESpec and RSpec; `describe` in ExUnit and Jest). Grouping blocks organize tests by semantic role: a scope the tests apply under, or a behavior or scenario being tested. Language-specific guides define which grouping keywords exist in each framework and how to choose between them when more than one is available.

In C test frameworks, the test name is a function identifier rather than a string. The same behavioral proposition principle applies - the function name should describe the expected behavior, not mirror the function under test. C frameworks do not provide grouping blocks; the file and fixture names carry the scope that grouping blocks would carry in other languages.

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

## Test at the Right Level

Unit tests verify that individual modules behave correctly in isolation. Feature tests verify that modules work together to produce the correct end-to-end behavior. Both are necessary - a system where every unit test passes can still fail if the units are wired together incorrectly.

Unit tests mock or stub external dependencies to isolate the subject. Feature tests wire real modules together and only mock at the system boundary - the external interfaces that the feature cannot control (hardware, network, OS services).

Structure the test suite so that both levels are present:
- **Unit tests** cover module-level logic, edge cases, and error paths
- **Feature tests** cover scenarios that cross module boundaries - a request flowing through parsing, validation, and response, for example

Feature tests tend to require more setup. Extract shared setup into helper functions when the same scenario scaffolding is used across multiple tests. Name helpers after the scenario they create, not the implementation steps they perform.

**When to deviate**: Small programs with few modules may not need a separate feature test layer - the unit tests may already exercise the integration points. Add feature tests when the system has enough modules that the wiring between them is a meaningful source of bugs.

---

## One Logical Concept Per Test

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

## Test Grouping Structure

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

## Tests Are Independent and Deterministic

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

## Tests Should Support a Tight Feedback Loop

**Intent**: Tests that engineers don't run provide no safety net. The goal is a suite that gets run continuously — while iterating on code, not just at the end.

**Convention**: A test suite should be fast enough that running it feels like a natural part of the development rhythm, not an interruption. When the full suite becomes too slow to run after every change, lean on tooling to narrow scope: run only the file or describe block relevant to the current work.

All tests must pass before merging. Run the full suite before submitting code for review.

Avoid coupling tests to slow external systems (real network calls, real databases, real timers) unless the test is explicitly an integration test. Slow dependencies in unit tests accumulate and eventually push the suite into "too slow to bother" territory.

**When to deviate**: Integration and end-to-end tests touch real systems by definition and belong in a separate suite with different run expectations.

---

## Coverage Metrics Are a Signal, Not a Target

**Intent**: Coverage numbers measure which lines were executed, not whether the tests are meaningful. Optimizing for coverage produces tests that execute code without verifying behavior.

**Convention**: Use coverage as a diagnostic tool — a low number signals undertested areas worth examining. Do not set coverage thresholds as pass/fail gates. Every test written should be meaningful and add understanding about the application's functionality. A test written to increase a coverage number rather than to specify behavior is noise — it bloats the suite without improving confidence.

**When to deviate**: Some organizations require coverage thresholds for compliance or audit purposes. In those cases, treat the threshold as a floor, not a goal.

---

## Tests Should Not Duplicate Implementation Logic

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

## Write Tests With the Code

When implementing a new module or function, write tests alongside the
implementation — not as a separate follow-up task. If test scaffolding already
exists (empty spec or test files for the module), fill it in as part of the
same implementation.

Unimplemented test files are not acceptable deliverables. An empty test file
provides no specification and no safety net. Every module with public functions must have tests. Before completing a code generation task, verify that every test file has at least one test.

---

## Test Code Is Production Code

**Intent**: Tests that are hard to read become tests that nobody trusts, updates, or learns from. Letting test code quality slip undermines the value of the suite.

**Convention**: Apply the same standards to test code as to production code — clear naming, small focused functions, no duplication of test setup logic, no magic numbers. A developer reading a failing test should be able to understand what it was asserting and why, without digging into the implementation.

**When to deviate**: Test helpers and fixtures can be more permissive about abstraction — a shared factory or builder that exists solely to reduce setup noise is acceptable even if it would be over-engineered in production code.

---

## Assertion Precision

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
