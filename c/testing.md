# C Testing Style Guide

Testing conventions for C. Part of the C style guide - loaded automatically via `@` import from `c/CLAUDE.md`.

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

**Evaluating a test name.** Apply the detokenize technique from the general guide: strip `test_`, replace underscores with spaces, and read the result as English. Then apply the litmus test: can you say "it [name]" and have a complete sentence?

- `test_returns_calibrated_value` → "it returns calibrated value" - complete proposition
- `test_read_sensor` → "it read sensor" - imperative, not a proposition
- `test_capacity_limit` → "it capacity limit" - noun phrase, no verb
- `test_value_preserved` → "it value preserved" - missing auxiliary verb ("is preserved")

**Three questions for finding the right name:**

1. **"Can I say 'it [name]' and have a complete sentence?"** Catches grammar problems: missing verbs, bare noun phrases, imperative mood. If the answer is no, the name needs a verb or restructuring.

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

// good - tautological name is correct when the API name is a proposition
void test_enabled_sensor_is_enabled(void) { ... }
// "enabled sensor" is the setup, "is_enabled" is the API function

// avoid - mirrors code structure
void test_read_sensor(void) { ... }
void test_parse_config(void) { ... }

// avoid - bare noun phrase, no verb
void test_registry_capacity(void) { ... }
void test_sensor_init(void) { ... }

// avoid - repeats module name from file
void test_sensor_returns_calibrated_value(void) { ... }  // in test_sensor.c

// In Google Test, the same principle applies:
// TEST(Sensor, ReturnsCalibratedValue) { ... }
// TEST(Sensor, ReturnsErrorWhenNotInitialized) { ... }
```

Test names can be long. A descriptive 60-character function name is better than a cryptic 20-character one.

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

---

## Test Code Principles

Tests are not implementation code. The goal of a test is to tell a story: what is set up, what action is taken, what is asserted. Formatting rules serve this story.

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
TEST_ASSERT_EQUAL_UINT32(0xBEEFCAFE, header.magic);
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
