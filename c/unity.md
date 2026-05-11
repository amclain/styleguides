# Unity Mechanics Reference

Operational notes for the [Unity](http://www.throwtheswitch.org/unity) C testing framework. Style conventions for Unity tests live in `c/testing.md`; this file documents framework mechanics that affect how test binaries are built, invoked, and wired into a project's tooling.

Load this file when configuring test runners, build-system wiring, or command-line filter infrastructure. It is not loaded automatically - reach for it when working with Unity tooling, not when writing individual test functions.

---

## Command-Line Args and Test Filtering

Unity test binaries can accept `argc`/`argv` and parse them through `UnityParseOptions` so operators and CI can target specific tests via `<binary> -f <substring>` (or `-n <name>` to require an exact name, `-x <exclude>` to exclude). This is opt-in - a project decides whether it wants filtering.

If the project adopts filtering, apply the pattern uniformly. Mixing `main(void)` and `main(int, char**)` across binaries breaks shared test-invocation tooling and confuses operators. The choice is project-wide.

### Required `main()` signature

```c
int main(int argc, char** argv)
{
  UnityParseOptions(argc, argv);

  UNITY_BEGIN();

  RUN_TEST(test_returns_calibrated_value);
  RUN_TEST(test_returns_error_when_not_initialized);

  return UNITY_END();
}
```

### Required compile-time flag

`UnityParseOptions` is compiled out unless `UNITY_USE_COMMAND_LINE_ARGS` is defined. With CMake:

```cmake
target_compile_definitions(unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
```

For other build systems, define the macro globally for the test target.

---

## The Filter Gotcha

Unity's default `RUN_TEST` macro does NOT consult `UnityTestMatches`. (`UnityTestMatches` is a Unity-internal predicate that returns nonzero when the current test name set on `Unity.CurrentTestName` matches the parsed `-f`/`-n`/`-x` options - it is what `RUN_TEST` is supposed to gate on.) With `UNITY_USE_COMMAND_LINE_ARGS` defined and `UnityParseOptions` called, the binary parses `-f`/`-n`/`-x` cleanly and then ignores them - every test runs. The filter is silently dropped at runtime.

This is invisible in workflows that use Unity's Ruby generator scripts (`generate_test_runner.rb`), which produce runners that already consult `UnityTestMatches`. Hand-written `main()` runners (the common pattern for small C libraries) hit the orphaned-filter issue.

Verified empirically against Unity's `master` branch: a binary built with `UNITY_USE_COMMAND_LINE_ARGS`, calling `UnityParseOptions(argc, argv)` before `UNITY_BEGIN`, and using the default `RUN_TEST` macro runs all tests regardless of `-f <substring>`. The same binary built with the override below filters correctly.

### Override header

Ship a project-owned header that overrides `RUN_TEST` to gate on `UnityTestMatches`:

```c
/* unity_filter.h */
#pragma once

#include "unity.h"

#ifdef UNITY_USE_COMMAND_LINE_ARGS
int UnityTestMatches(void);

#undef RUN_TEST
#define RUN_TEST(func)                              \
  do {                                              \
    Unity.CurrentTestName = #func;                  \
    Unity.CurrentTestLineNumber = __LINE__;         \
    if (UnityTestMatches()) {                       \
      UnityDefaultTestRun(func, #func, __LINE__);   \
    }                                               \
  } while (0)
#endif
```

The macro sets `Unity.CurrentTestName` and `Unity.CurrentTestLineNumber` first so `UnityTestMatches` can compare the test name against the parsed filter options, then dispatches to `UnityDefaultTestRun` (Unity's normal per-test runner) only when the test matches. The `#ifdef UNITY_USE_COMMAND_LINE_ARGS` guard makes the override inert when filtering is disabled - the header is safe to ship even in builds that don't define the macro.

### Force-include into every test translation unit

Apply the override structurally via the compiler's force-include flag rather than per-file `#include` directives. Force-include keeps the override applied uniformly: a new test file authored without an explicit include still gets the override, so the binary cannot silently drift back to the orphaned-filter behavior.

CMake:

```cmake
target_compile_options(<test_target> PRIVATE
  -include ${CMAKE_CURRENT_SOURCE_DIR}/unity_filter.h
)
```

GCC and Clang accept `-include <header>` directly; the same flag works in Make, Meson, and any build system that surfaces compiler flags.

Per-file `#include "unity_filter.h"` works but drifts easily - a test file authored without the include builds and silently ignores filters, and the drift is invisible until someone tries to run a single test.