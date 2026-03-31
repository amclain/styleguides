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

Use the pattern `test_<action_or_property>_when_<condition>` or `test_<condition>_<expected_outcome>`. The module name is already in the file name - don't repeat it in every test function name.

```c
// good - behavioral propositions
void test_returns_calibrated_value(void) { ... }
void test_returns_error_when_not_initialized(void) { ... }
void test_returns_null_when_sensor_not_found(void) { ... }
void test_checksum_matches_for_valid_reading(void) { ... }

// avoid - mirrors code structure, describes nothing
void test_read_sensor(void) { ... }
void test_sensor_init(void) { ... }

// avoid - repeats module name from file
void test_sensor_returns_calibrated_value(void) { ... }  // in test_sensor.c

// In Google Test, the same principle applies:
// TEST(Sensor, ReturnsCalibratedValue) { ... }
// TEST(Sensor, ReturnsErrorWhenNotInitialized) { ... }
```

Test names can be long. A descriptive 60-character function name is better than a cryptic 20-character one. The name is the specification - it should read as a behavioral proposition.

---

### setUp and tearDown

Unity calls `setUp()` before each test and `tearDown()` after each. Use them for state that every test in the file needs. Keep them short - if setUp is doing complex multi-step initialization, the tests may be at the wrong level of abstraction or the file covers too many concerns.

Only define `setUp` and `tearDown` when there is work to perform. An empty `setUp` or `tearDown` is noise.

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

When setUp grows beyond a handful of lines, extract named helper functions. Name helpers after the scenario they create, not the steps they perform.

```c
// good - name describes the scenario
static void configure_with_default_calibration(sensor_t* sensor) { ... }

// avoid - name describes the steps
static void init_sensor_and_set_offsets(sensor_t* sensor) { ... }
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
