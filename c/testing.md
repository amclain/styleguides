# C Testing Style Guide

Testing conventions for C. Part of the C style guide - loaded on demand when test code is in scope (read directly via the Read tool; not propagated to subagents via `@` import).

The general style guide's testing principles apply to C without modification. This file covers how those principles map to C-specific testing frameworks and idioms.

---

## Testing Framework

[Unity](http://www.throwtheswitch.org/unity) and [Google Test](https://github.com/google/googletest) are both recommended testing frameworks for C. [CMock](http://www.throwtheswitch.org/cmock) provides mocking via code generation from header files and is designed to work with Unity.

The conventions below use Unity/CMock for examples. Google Test conventions are TBD.

---

## Test File Structure

### File Naming

Follow the naming convention of the test framework. The test file name should make it clear which source module it tests. Feature test files include a `feature` marker to distinguish them from unit tests.

```
# Unity - test_ prefix, .c extension
test/test_sensor.c                    tests src/sensor.c
test/test_feature_reading_pipeline.c  feature test

# Google Test - _test suffix, .cc extension
test/sensor_test.cc                   tests src/sensor.c
test/feature_reading_pipeline_test.cc feature test
```

---

### Test Function Naming

Unity discovers test functions by name. Each test function is `void test_<description>(void)`. Since C function names cannot contain spaces, the name is the behavioral specification in `snake_case`.

The name is the specification - it should read as a behavioral proposition. A test name answers "what behavior does this prove exists?", not "what function does this call?"

The module name is already in the file name - don't repeat it in every test function name.

**Evaluating a test name.** Unity's `test_` prefix is scaffolding - it is not read as part of the description. Strip `test_`, replace underscores with spaces, and read the remainder alone, scoped to the file subject (the module the file is for). The name should read as a complete proposition about that subject. When writing the check out, "`subject`, `name`" is a convenient shorthand - it is just a way of reminding yourself what subject the name has to hold up against, not a literal string that appears anywhere in the code.

- `test_returns_calibrated_value` in `test_sensor.c` → "sensor, returns calibrated value" - complete proposition
- `test_read_sensor` → "sensor, read sensor" - imperative, not a proposition
- `test_capacity_limit` → "sensor, capacity limit" - noun phrase, no verb
- `test_value_preserved` → "sensor, value preserved" - missing auxiliary verb ("is preserved")

Noun-leading names are valid when the name introduces its own scenario subject scoped to the file. `test_unknown_sensor_returns_error` in `test_registry.c` reads as "registry, unknown sensor returns error" - a complete proposition where "unknown sensor" is the scenario subject within the registry's scope.

**Identifier-as-English-verb pitfall.** API tokens (function names, struct field names) often contain words that are also English verbs. When such a token appears in a test name, the detokenized form can parse as a grammatical sentence while the proposition is wrong - the token is being read as a verb describing behavior, but it is just an identifier. The Question 1 check below catches grammar problems but can be fooled by this case because the sentence parses.

This pitfall has two shapes. Both are easy to miss because the names sound natural.

*Shape 1: API token leads, then a real verb follows.* The leading token reads as the sentence's subject-verb when it is actually the API function name. Examples (for `mock_sensor.h` in `test_mock_sensor.c`):

- `test_responds_returns_configured_status` → "mock sensor, responds returns configured status" - parses (subject "responds", verb "returns") but `_responds` is the configuration setter identifier, not a verb. The mock returns the status; `_responds` does nothing in the proposition.
- `test_received_returns_false_before_any_call` → "mock sensor, received returns false before any call" - parses but `_received` is the inspector identifier; the proposition is about what the inspector returns, not about the mock's behavior.
- `test_reset_clears_all_configured_state` → "mock sensor, reset clears all configured state" - parses but `_reset` is the function being called; the proposition names the action, not the outcome (see Question 2 below for a related framing).

*Shape 2: API token chains with another API token, parsing as a multi-word sentence.*

- `test_set_callback_dispatches_to_callback_with_caller_args` → "mock sensor, set callback dispatches to callback with caller args" - parses (subject "set callback", verb "dispatches") but `_set_callback` is the installer identifier, not a behavior of the mock.

The recast: make the file subject (the unit under test) the grammatical subject and pick a verb that describes its observable behavior. The API token becomes the test's mechanism, not its proposition.

- `test_responds_returns_configured_status` → `test_returns_configured_status_on_the_next_call`
- `test_received_returns_false_before_any_call` → `test_reports_no_call_when_inspected_before_any_call`
- `test_reset_clears_all_configured_state` → `test_returns_to_uninitialized_state_after_reset`
- `test_set_callback_dispatches_to_callback_with_caller_args` → `test_invokes_installed_callback_with_caller_args`

Noun-leading scenario forms remain valid when the API token is naturally a noun phrase: `test_call_count_increments_with_each_invocation` detokenizes cleanly because "call count" is a noun, "increments" is the verb, and the file subject scopes both. The pitfall is API-token-as-verb, not API-token-as-noun.

CAUTION: when a test name's leading token is itself a function name from the unit under test (`_reset`, `_received`, `_responds`, `_init`, `_close`), inspect the name carefully. The name often violates this rule even when the rest of the name parses cleanly - especially in mock APIs where the function names are configuration/inspection setters rather than behavior verbs. Recast so the file subject is the grammatical subject, and the API token appears later as the mechanism (e.g. "after reset", "when inspected"). Some leading tokens (`_init`, `_close`) describe genuine behavior in non-mock contexts and may be correct as written; the recast is needed when the token is a procedural identifier rather than a verb naming what the unit does.

**Three questions for finding the right name:**

1. **"Does the detokenized name read as a complete proposition scoped to the enclosing subject?"** Catches grammar problems: missing verbs, bare noun phrases, imperative mood. Handles both verb-leading names (where the file subject is implicit) and noun-leading scenario names (where the name introduces its own subject).

2. **"What behavior does this prove exists?"** Derive the name from the assertion, not the function being called. The assertion is what the test proves. `TEST_ASSERT_NULL(result)` after a lookup → `test_removed_sensor_is_not_found`. Do not name it `test_remove_sensor` - that names the action, not the outcome.

3. **"Why does this matter to the system?"** Finds the precise name when the current one is generic. "valid" and "correct" say nothing. Ask why validity matters and name that: `test_reading_valid` → why? → out-of-range readings are discarded during calibration → `test_discards_reading_outside_calibration_range`.

**Active voice by default.** Active voice names the actor and the action. Passive voice buries the actor. Use passive only when the subject's capability is the point.

```c
// good - active voice, behavioral propositions
void test_returns_calibrated_value(void) { ... }
void test_returns_error_when_not_initialized(void) { ... }
void test_discards_reading_outside_calibration_range(void) { ... }
void test_finds_sensor_by_address(void) { ... }
void test_does_not_poll_disabled_sensor(void) { ... }

// good - passive voice when the subject's capability is the point
void test_sensor_can_be_removed(void) { ... }

// good - "when" clause for boundary/conditional tests
void test_returns_null_when_sensor_not_found(void) { ... }
void test_skips_poll_when_registry_is_full(void) { ... }

// good - noun-leading scenario; in test_registry.c this reads as
// "registry, unknown sensor returns error" - the name introduces
// "unknown sensor" as the scenario subject within the registry scope
void test_unknown_sensor_returns_error(void) { ... }
void test_duplicate_insert_is_idempotent(void) { ... }

// good - tautological name is correct when the API name itself forms
// part of the proposition. "enabled sensor" is the scenario setup, and
// "is_enabled" is the API function under test - the name reads as a
// test of the API's own claim: an enabled sensor reports that it is
// enabled.
void test_enabled_sensor_is_enabled(void) { ... }

// avoid - mirrors code structure
void test_read_sensor(void) { ... }
void test_parse_config(void) { ... }

// avoid - bare noun phrase, no verb
void test_registry_capacity(void) { ... }
void test_sensor_init(void) { ... }

// avoid - repeats module name from file
void test_sensor_returns_calibrated_value(void) { ... }  // in test_sensor.c
```

Test names can be long. A descriptive 60-character function name is better than a cryptic 20-character one.

Long test names interact with the test runner's call site. The `RUN_TEST(name);` line is `2 indent + 9 RUN_TEST + 1 ( + name + 2 );` characters; a 67-character test name produces an 81-character call line, exceeding the 80-character limit. Wrap the call across multiple lines per `c/CLAUDE.md` § Brace Style — single-arg macro wraps follow the same rule as multi-arg function calls: the test name goes on its own line at body indent, and the closing `);` goes together on its own line. Do not split `)` and `;` onto separate lines, and do not glue `);` to the test name on the wrap line. The styleguide-canonical form is three lines: `RUN_TEST(`, the test name indented, `);` on the closing line.

---

### Test Function Docstrings

Test functions are bare `void test_*(void)` declarations with no Doxygen docstring or `@brief` block. Test files are `.c` files, not headers, and test functions are not public API. Doxygen extracts public documentation from header declarations - test functions have no header declaration and never appear in generated documentation. A docstring on a test function is read by no one and is pure noise in the source.

The same reasoning extends to test-file-local helpers (forward-declared `static` helpers used by the tests) and inline fixture extensions. None are extracted by Doxygen, so docstrings on them are equally noise.

The test name already carries the behavioral specification (per Test Function Naming above) for any reader scanning the file directly. Section-grouping comments above clusters of tests are allowed (see Test Runner below) - per-function Doxygen blocks are not.

```c
// good - bare declaration, body opens on next line
void test_returns_calibrated_value(void)
{
  // ...
}

// avoid - Doxygen block on a test function
/**
 * @brief Verifies the calibrated value is returned after init.
 */
void test_returns_calibrated_value(void)
{
  // ...
}

// avoid - brief-only block on a test function
/** @brief Returns calibrated value after init. */
void test_returns_calibrated_value(void) { ... }
```

This is a specific case of `c/CLAUDE.md`'s Comment Style rule that "static (file-internal) functions do not require a docstring, but may have one if the function is complex." For test functions the answer is "no, never" because Doxygen extraction never reaches them - the complexity case the static-function rule allows for is not the relevant axis here.

---

### setUp and tearDown

Unity calls `setUp()` before each test and `tearDown()` after each. Use them for state that every test in the file needs. Keep them short - if setUp is doing complex multi-step initialization, the tests may be at the wrong level of abstraction or the file covers too many concerns.

Unity requires both `setUp` and `tearDown` to be defined - the linker expects both symbols even when one is empty. Define both, but keep empty implementations minimal: `void tearDown(void) {}`.

Place `setUp` and `tearDown` after static variables and helper functions, just before the first test function. They may reference static helpers or variables, so those must be defined above them.

```c
static sensor_t sensor;

void setUp(void)
{
  sensor_init(&sensor);
}

void tearDown(void)
{
  sensor_destroy(&sensor);
}
```

When setUp grows beyond a handful of lines, extract named helper functions. Name helpers after the scenario they create, not the steps they perform. Test helper names are chosen for readability in the test body - they carry the test's narrative. The helper name is more important than its arguments, since the arguments are often scaffolding the reader skips.

```c
// good - name describes the scenario; reads well in test body
static void configure_with_default_calibration(sensor_t* sensor) { ... }

// good - concise name for readability in tests
static sensor_t* add_sensor(registry_t* registry, ...) { ... }
static sensor_t* add_dependent(registry_t* registry, sensor_t* parent, ...) { ... }

// avoid - name describes the steps
static void init_sensor_and_set_offsets(sensor_t* sensor) { ... }

// avoid - mirrors module API naming instead of test readability
static sensor_t* sensor_registry_create_and_add(registry_t* registry, ...) { ... }
```

---

### Test Runner

Use the auto-runner (via Ruby/Ceedling) when the build system supports it. When writing the runner manually, group `RUN_TEST()` calls to mirror the logical sections of the test file:

```c
int main(void)
{
  UNITY_BEGIN();

  // reading
  RUN_TEST(test_returns_calibrated_value);
  RUN_TEST(test_returns_error_when_not_initialized);
  RUN_TEST(test_returns_error_when_hardware_fails);

  // configuration
  RUN_TEST(test_set_offset_succeeds);
  RUN_TEST(test_set_offset_returns_error_for_invalid_channel);

  return UNITY_END();
}
```

Comments as section headers provide the grouping that C lacks from `describe`/`context` blocks. Keep them terse - one line, lowercase.

When the test file contains a hand-written `main()` (Unity binaries with manual runners, or Google Test files with custom setup), place `main()` at the very end of the file, after all test functions and helper definitions. The runner is the file's index of tests - placing it at the bottom keeps test functions contiguous and matches C's natural forward-declaration ordering: helpers and tests defined before the runner that references them, with no top-of-file forward declaration block needed.

Most Google Test files do not have a hand-written `main()` - linking against `gtest_main` provides the default entry point that calls `::testing::InitGoogleTest` and `RUN_ALL_TESTS`. Write a custom `main()` only when the test binary needs setup the default cannot provide (custom environment objects, custom flag parsing). When you do, the placement rule above applies.

Default to `int main(void)` for hand-written runners. When a project adopts Unity's command-line filtering (`-f <substring>`, `-n <name>`, `-x <exclude>`), every test binary in that project uses the same `main(int argc, char** argv)` signature. Mixing `main(void)` and `main(int, char**)` across binaries within a filtering-enabled project breaks shared test-invocation tooling and confuses operators - the choice is project-wide, not per-binary. Unity's default `RUN_TEST` macro does not consult the parsed filters; getting filtering to work requires a per-project override. See `c/unity.md` for the mechanics, the override header, and the CMake wiring.

---

## Test Code Principles

Tests are not implementation code. The goal of a test is to tell a story: what is set up, what action is taken, what is asserted. Formatting rules serve this story.

### Test Sentinel Values

When a test needs an arbitrary recognizable non-zero value as a placeholder (a sentinel for a pointer, output parameter, or value the test does not otherwise constrain), use a value the reader will not pause on. Avoid cultural references: hex literals whose digits spell English (`0xDEADBEEF`, `0xCAFEBABE`, `0xC0FFEE` and the broader hex-word family), integers from popular culture (`42`, `1337`), and any value a reader is likely to recognize from a context other than this test.

The recognition is the bug. Developers reach for these values because they are memorable, and that is exactly the problem - a sentinel should disappear behind the test's intent, not draw attention. A reader reaching `0xDEADBEEF` or `42` pauses to evaluate whether the value is significant. It isn't, but the pause is wasted attention and the test reads as if it's testing something it isn't.

Default sentinels: `0x12345678` (32-bit), `0x123456789abcdef0` (64-bit). Any non-referential value works. Repeat the same literal in the configuration and in the assertion - for simple sentinels, this is clearer than introducing a named local that only renames the literal.

When a test needs multiple distinct sentinels (two pointers to distinguish, three handles to track), use a scannable sequence rather than incrementing the default by one. `0x11111111`, `0x22222222`, `0x33333333` are visually distinct in code and in failure messages; `0x12345678` and `0x12345679` are not - the difference disappears in a long line. Pick the pattern that is easiest to spot: repeated-nibble values (`0x11111111`, `0x22222222`), low integers (`0x00000001`, `0x00000002`), or any sequence where each value is unambiguously different from the others at a glance.

```c
// good - non-referential literal repeated in config and assertion
mock_set_response(SUCCESS, 0x12345678);

uint32_t output = 0;
read_value(&output);

TEST_ASSERT_EQUAL_UINT32(0x12345678, output);

// avoid - cultural reference draws the reader's attention
mock_set_response(SUCCESS, 0xDEADBEEF);

uint32_t output = 0;
read_value(&output);

TEST_ASSERT_EQUAL_UINT32(0xDEADBEEF, output);
```

Reach for a named `const` only when the name carries information the literal cannot - when the value is computed from a base, when the test specifies a symbolic property the name documents (`SENTINEL_PARENT_HANDLE`), or when the same value flows through enough places that consistency matters.

```c
// good - named const carries information the literal cannot;
// scannable sequence distinguishes the two
#define SENTINEL_PARENT_HANDLE  ((const void*) 0x11111111)
#define SENTINEL_CHILD_HANDLE   ((const void*) 0x22222222)

// avoid - the name only renames the literal; just write 0x12345678
#define SENTINEL_OUTPUT_VALUE 0x12345678
```

### Test Variable Placement

Declare output variables (the "what comes out") at the top of the test function alongside input variables (the "what goes in"). Together they show the test's interface before the setup scaffolding begins.

```c
// good - outputs and inputs at top, then setup, then action + assertion
void test_parses_valid_reading(void)
{
  reading_t reading;
  uint8_t frame[64] = { 0 };

  write_header(frame, MSG_TYPE_READING);
  write_payload(frame + HEADER_SIZE, 0x0048, 2350);
  size_t length = HEADER_SIZE + PAYLOAD_SIZE;

  TEST_ASSERT_EQUAL_INT(0, parse_reading(frame, length, &reading));
  TEST_ASSERT_EQUAL_UINT16(0x0048, reading.address);
}

// avoid - output variable buried after setup
void test_parses_valid_reading(void)
{
  uint8_t frame[64] = { 0 };
  write_header(frame, MSG_TYPE_READING);
  write_payload(frame + HEADER_SIZE, 0x0048, 2350);
  size_t length = HEADER_SIZE + PAYLOAD_SIZE;

  reading_t reading;
  TEST_ASSERT_EQUAL_INT(0, parse_reading(frame, length, &reading));
}
```

### Inline Assertions

When testing a function's return value, inline the call in the assertion rather than extracting to a variable. The assertion is already testing the error - extracting adds a line that says nothing new. Split the assertion to multiple lines when it exceeds 80 characters.

```c
// good - inline when it fits
TEST_ASSERT_EQUAL_INT(-1, sensor_read(NULL, &value));
TEST_ASSERT_EQUAL_INT(0, sensor_init(&config));
TEST_ASSERT_NULL(find_sensor(unknown_id));

// good - split when it exceeds 80 chars
TEST_ASSERT_EQUAL_INT(
  EXPECTED_VALUE,
  sensor_read_calibrated(&sensor, channel, &output)
);

// avoid - extracting to a variable when the assertion already tests it
int error = sensor_read(NULL, &value);
TEST_ASSERT_EQUAL_INT(-1, error);
```

### Test Fixtures with Defaults

When test helpers take many arguments, most of which are boilerplate defaults, use a params struct with a default initializer macro. Tests override only the fields that matter to their story. C99 allows duplicate designated initializers - the last one wins - so a macro can expand defaults and accept overrides via `__VA_ARGS__`.

The function under test should accept the params struct directly. Do not create intermediate wrapper functions that unpack the struct back into positional arguments - change the function signature to take `const type*` instead.

When you see repeated struct-then-override patterns in test code (`opts = defaults(); opts.field = value;`), apply the macro pattern. It collapses multi-line setup blocks into a single expression that reads as "default with these overrides."

```c
typedef struct {
  uint8_t type;
  uint16_t address;
  int32_t offset;
  uint32_t interval_ms;
  bool enabled;
} sensor_params_t;

// preferred - inline override macro
#define SENSOR_PARAMS(...) ((sensor_params_t){ \
  .type = SENSOR_TEMP, \
  .address = 0x0048, \
  .offset = 0, \
  .interval_ms = 1000, \
  .enabled = true, \
  __VA_ARGS__ \
})

// one-liner inserts - only the relevant field is visible
void test_finds_sensor_by_address(void)
{
  sensor_t* temp = add_sensor(&registry, &SENSOR_PARAMS(.address = 0x0048));
  sensor_t* humidity = add_sensor(&registry, &SENSOR_PARAMS(.address = 0x0050));
  sensor_t* pressure = add_sensor(&registry, &SENSOR_PARAMS(.address = 0x0060));

  TEST_ASSERT_EQUAL(3, sensor_count(&registry));
  TEST_ASSERT_EQUAL(humidity, find_by_address(&registry, 0x0050));
}

// multiple overrides split to lines
void test_disabled_sensor_is_skipped_during_poll(void)
{
  sensor_t* sensor = add_sensor(&registry, &SENSOR_PARAMS(
    .address = 0x0048,
    .enabled = false
  ));

  poll_all(&registry);

  TEST_ASSERT_EQUAL(0, sensor->read_count);
}
```

Also acceptable: a struct variable with field overrides before the call.

```c
void test_finds_sensor_by_address(void)
{
  sensor_params_t params = DEFAULT_SENSOR_PARAMS;

  params.address = 0x0048;
  sensor_t* temp = add_sensor(&registry, &params);

  params.address = 0x0050;
  sensor_t* humidity = add_sensor(&registry, &params);

  TEST_ASSERT_EQUAL(humidity, find_by_address(&registry, 0x0050));
}
```

---

### Don't Test Dependency Contracts

Do not write tests for defensive checks against failures in dependencies - the OS, runtime, libraries, or any other code your project depends on. Each dependency is responsible for validating its own behavior. If a library guarantees a return type, the OS guarantees a complete delivery, or a framework guarantees initialization order, testing those guarantees tests the dependency, not your code.

This extends the general principle "only validate at system boundaries." Dependency guarantees are not a system boundary the application crosses - they are the floor the application stands on. A test for "what if the library returned the wrong type" when the library's own tests guarantee the type is testing a scenario that cannot happen under the dependency's contract.

**When to deviate**: When your code explicitly handles dependency errors as part of its contract (e.g. a retry layer that handles `EAGAIN`, or a wrapper that translates library errors into domain errors), testing those paths is testing your code, not the dependency.

---

## Unity Assertions

### Prefer Specific Assertions

Use the most specific assertion macro available. Specific assertions produce better failure messages - they print both expected and actual values with appropriate formatting. Generic assertions only say "was false."

```c
// good - prints both values on failure
TEST_ASSERT_EQUAL(expected_count, sensor_count());
TEST_ASSERT_EQUAL_STRING("temperature", sensor_name);
TEST_ASSERT_EQUAL_UINT32(0x12345678, header.magic);
TEST_ASSERT_NULL(find_sensor(unknown_id));
TEST_ASSERT_NOT_NULL(create_sensor(valid_id));

// avoid - only prints "Expression Evaluated To FALSE"
TEST_ASSERT_TRUE(sensor_count() == expected_count);
TEST_ASSERT(ptr != NULL);
```

### Type-Specific vs Generic

Use type-specific variants (`TEST_ASSERT_EQUAL_UINT32`, `TEST_ASSERT_EQUAL_INT16`) when the type matters to the test's meaning - when testing values near type boundaries, or when signedness is part of the specification. Use `TEST_ASSERT_EQUAL` for general integer comparisons where the type is not the point.

```c
// good - type is part of the specification
TEST_ASSERT_EQUAL_UINT8(0xFF, register_value);  // register is 8-bit
TEST_ASSERT_EQUAL_INT16(-1, error_code);         // signed error code

// good - type is not the point
TEST_ASSERT_EQUAL(3, sensor_count());
```

### Struct Comparison

Prefer field-by-field assertions over `TEST_ASSERT_EQUAL_MEMORY` for structs. Field-by-field assertions document which fields matter and produce readable failure messages. Use `TEST_ASSERT_EQUAL_MEMORY` only when testing raw byte layout (protocol buffers, serialization).

```c
// good - documents which fields matter
TEST_ASSERT_EQUAL_UINT16(0x0048, reading.address);
TEST_ASSERT_EQUAL(SENSOR_TEMP, reading.type);
TEST_ASSERT_EQUAL_FLOAT(23.5, reading.value);

// avoid for struct comparison - opaque failure message
TEST_ASSERT_EQUAL_MEMORY(&expected, &actual, sizeof(reading_t));

// good for raw byte layout
TEST_ASSERT_EQUAL_MEMORY(expected_bytes, wire_buffer, 12);
```

### Array Assertions

Use `TEST_ASSERT_EQUAL_UINT8_ARRAY` and similar for buffer comparisons. The length parameter is the element count, not byte count.

```c
uint8_t expected[] = {0x01, 0x02, 0x03};
TEST_ASSERT_EQUAL_UINT8_ARRAY(expected, output_buffer, 3);
```

### Message Variants

Use `_MESSAGE` variants when the same assertion appears multiple times in a test and a bare failure message would be ambiguous - for example, when asserting inside a loop or checking multiple instances of the same type.

```c
// good - message disambiguates which iteration failed
for (int i = 0; i < NUM_CHANNELS; i++) {
  char message[32];
  snprintf(message, sizeof(message), "channel %d", i);
  TEST_ASSERT_TRUE_MESSAGE(channel_is_active(i), message);
}
```

---

## CMock

### Expect, Stub, and Ignore

CMock generates three mock variants from each function declaration. Choose based on what the test is specifying:

- **`_Expect`** / **`_ExpectAndReturn`**: the test specifies that this function will be called with these arguments and return this value. Failure if not called, or called with wrong arguments. Use when the interaction is part of the specification.
- **`_Stub`** / **`_StubWithCallback`**: provide a return value or behavior for any call. No verification. Use when the dependency needs to work but the interaction is not what's being tested.
- **`_Ignore`** / **`_IgnoreAndReturn`**: ignore all calls, optionally return a value. Use for dependencies that are irrelevant to the test.

```c
// good - the test specifies the interaction with hardware
void test_publishes_reading_to_event_queue(void)
{
  event_queue_send_ExpectAndReturn(&reading_event, STATUS_OK);
  sensor_poll(&sensor);
}

// good - storage needs to work but isn't the point of the test
void test_loads_calibration_from_storage(void)
{
  storage_read_StubWithCallback(fake_storage_read);
  config_t config = load_config();
  TEST_ASSERT_EQUAL(expected_offset, config.offset);
}
```

### Verification

CMock automatically verifies expectations in `tearDown`. No manual verification step is needed. If a test passes, all `_Expect` calls were satisfied. If an expected call was not made, the test fails with a clear message.

### Generated Mock Headers

CMock generates mock headers from source headers. Include them in test files with the `mock_` prefix:

```c
#include "mock_event_queue.h"   // generated from event_queue.h
#include "mock_storage.h"       // generated from storage.h
```

The build system (CMake/Ceedling) handles generation. Do not check generated mock files into version control.

---

## Feature Tests

Feature tests wire multiple real modules together with mocks only at the system boundary. They verify that modules integrate correctly to produce end-to-end behavior.

### Structure

Each feature test file covers a scenario or feature area. setUp does more work than in unit tests - it initializes the real modules and configures the mocked boundaries.

```c
// test_feature_reading_pipeline.c

#include "sensor.h"
#include "calibration.h"
#include "publisher.h"
#include "mock_hardware.h"  // only mock the system boundary

static sensor_t sensor;
static calibration_t calibration;

void setUp(void)
{
  sensor_init(&sensor);
  calibration_init(&calibration);
}

void tearDown(void)
{
  calibration_destroy(&calibration);
  sensor_destroy(&sensor);
}
```

### Setup Helpers

Feature test setUp can grow large. Extract named helpers for common scenarios:

```c
static void configure_sensor(uint16_t address, int32_t offset)
{
  sensor_set_address(&sensor, address);
  calibration_set_offset(&calibration, offset);
}

void test_publishes_calibrated_reading(void)
{
  configure_sensor(0x0048, 100);
  hardware_read_ExpectAndReturn(0x0048, 2350);

  int32_t value = 0;
  int error = sensor_read(&sensor, &calibration, &value);

  TEST_ASSERT_EQUAL(0, error);
  TEST_ASSERT_EQUAL_INT32(2450, value);
}
```

### Distinguishing Unit and Feature Tests

Keep unit tests and feature tests in the same `test/` directory. The `test_feature_` prefix is sufficient to distinguish them. When the build system supports it, configure separate test suites so unit tests can run independently (fast feedback loop) and feature tests run as a second pass.
