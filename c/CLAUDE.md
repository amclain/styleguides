# C Style Guide

This file defines style conventions for C code. It is used by Claude Code to apply and review style.

The overarching philosophy is defined in the repository's top-level `CLAUDE.md`: these are recommendations, not mandates, and precedence in the codebase takes priority over this guide.

---

## Naming

### Namespace Prefixes

**Intent**: C has no module or namespace system - all types, functions, and constants share a global namespace. Prefixes prevent collisions and make ownership clear at every call site.

**Convention**: Every public type, function, and constant gets a short component prefix. The prefix is a functional requirement, not redundant context. Prefixes are short abbreviations of the application or library name, which is idiomatic to C even though the general style guide discourages abbreviations in other contexts.

Each application's public identifiers use one consistent prefix. API types carry the prefix of the application that hosts the API - consumers include the host app's headers and use its types.

The general style guide's "don't repeat context" principle applies after the prefix - the prefix itself is not considered redundant.

```c
// good - consistent prefix scopes identifiers to the component
app_connection_t conn;
app_connection_open(&conn, &config);
app_connection_close(&conn);

// good - type carries the prefix of the host API
net_address_t addr;
net_address_resolve(&addr, "example.com");

// avoid - no prefix; collides with any other "connection" type
connection_t conn;
connection_open(&conn, &config);

// avoid - prefix repeats in the body of the name
app_app_connection_open(&conn, &config);
```

**When to deviate**: Internal (file-scope `static`) functions and types do not need a prefix - `static` already limits their visibility. Avoid `fw_` as a prefix in embedded projects - it is commonly read as "firmware" and is too generic to be useful.

---

### Naming Conventions

**Intent**: C names must stand on their own in the global namespace. The full name (after the prefix) should accurately describe what the identifier represents.

**Convention**: Use `snake_case` for all identifiers - functions, variables, types, and constants. Type names use a `_t` suffix. Enum values use the component prefix in uppercase. Only `#define` constants and enum values use `UPPER_CASE`. `static const` arrays are variables and use `snake_case`.

Good C names will be longer than equivalent names in languages with modules or namespaces. This is expected - the global namespace requires each name to carry its full context.

Do not abbreviate `buffer` to `buf`, `length` to `len`, `message` to `msg`, `source` to `src`, `destination` to `dst`, or `checksum` to `cksum`. Write the full word. Use `size` as a concise alternative to `length` where appropriate (e.g. `buffer_size` instead of `buffer_length`). Accepted short forms: `ptr` (pointer), `fd` (file descriptor), `fn` (function pointer) - these are domain terms, not abbreviations. The closed list above is not exhaustive - apply the Domain Terms vs. Arbitrary Abbreviations rule from `general/CLAUDE.md` for short forms not listed here.

When a sanctioned short form appears in descriptive prose (docstrings, design documents, test plans, comments), expand it to the full word when the prose describes the mechanic or role. Use the short form only when the prose references the literal argument: in backticks naming the variable, when showing the signature or call form, or when discussing the variable's identity. The two forms serve different readers - code tokens identify a variable, prose describes the concept.

```c
// good - call form uses the short name; mechanic prose uses the full word
// After `mock_sensor_set_callback(fn)`, the registered callback runs with
// the caller's arguments.

// good - prose discussing the variable's identity uses the short name
// The argument `fn` must remain valid for the lifetime of the registration.

// avoid - mechanic prose carrying the short form
// After `mock_sensor_set_callback(fn)`, fn runs with the caller's arguments.
```

Standard acronyms from formal specifications (RFCs, IEEE standards) are acceptable in constant names when the acronym is the term used in the specification. Examples: `IHL` (Internet Header Length, RFC 791), `DSCP` (Differentiated Services Code Point, RFC 2474), `ECN` (Explicit Congestion Notification, RFC 3168), `TTL` (Time To Live). Spelling these out (`INTERNET_HEADER_LENGTH`) would make the identifiers harder to cross-reference with the source documentation. When RFC acronyms are used, add a comment referencing the relevant RFCs - either above the `#define` group or as a top-level file comment if the RFCs apply to the entire file. This follows the general guide's Documentation Notation rule: write it in the notation the documentation uses.

When a constant name includes a unit of measurement, use the `_IN_<unit>` pattern: `FILTER_TIMEOUT_IN_NS` not `FILTER_TIMEOUT_NS`. `_IN_NS` reads as "in nanoseconds" which is unambiguous. `_NS` alone could be misread as a namespace prefix. Standard unit abbreviations (`NS`, `MS`, `S`, `MB`, `KB`) are acceptable in measurement suffixes even though the general abbreviation rule says to write full words - unit abbreviations are standardized and universally understood, the identifier context makes them unambiguous, and measurement names are already long.

CAUTION: Abbreviations are invisible when reading identifiers as code tokens. See the general guide's Precision Over Length CAUTION for the detokenize technique. In C, also strip the namespace prefix before reading: `app_src_port` → "src port" → abbreviated.

```c
// good - descriptive names with appropriate suffixes
typedef struct { ... } app_sensor_reading_t;
app_sensor_reading_t reading;
int app_sensor_read(app_sensor_reading_t* out);

// good - enum values carry uppercase prefix
typedef enum {
  APP_PROTOCOL_TCP = 1,
  APP_PROTOCOL_UDP = 2,
} app_protocol_t;

// avoid - abbreviated body
typedef struct { ... } app_sr_t;
int app_sr_rd(app_sr_t* out);
```

Follow the general style guide's "Precision Over Length" principle, but recognize that C's flat namespace means names inherently carry more context than in languages with modules. Struct fields, local variables, and function parameters have richer surrounding context (struct access, nearby assignments, function signature) and can be shorter while remaining precise.

```c
// good - local variable is short; context is clear from surrounding code
app_sensor_reading_t reading;
reading.temperature = raw_value * scale;

// good - struct field is concise; the struct type provides context
typedef struct {
  uint16_t address;
  sensor_protocol_t protocol;
} sensor_channel_binding_t;
```

**When to deviate**: When heavily integrating against an established C codebase (POSIX sockets, lwIP), match its naming conventions for consistency at the integration boundary. Prefer explicit names like `ip_address` over `in_addr` in your own code.

---

## File Organization

### Include Guards

**Intent**: Prevent multiple inclusion of header files.

**Convention**: Prefer `#pragma once` over the traditional `#ifndef` / `#define` / `#endif` pattern. It is less error-prone (no risk of mismatched guard names) and communicates intent directly.

```c
// good
#pragma once

#include <stdint.h>

// avoid - verbose, guard name can drift out of sync with filename
#ifndef APP_SENSOR_H
#define APP_SENSOR_H

#include <stdint.h>

// ...

#endif /* APP_SENSOR_H */
```

**When to deviate**: If the codebase already uses `#ifndef` guards, follow that convention for consistency.

---

### Include Ordering

**Intent**: Group includes by scope so a reader can quickly identify dependencies - standard library, external, then local.

**Convention**: Group includes in this order, separated by a blank line between groups:

1. Standard library (`<stdint.h>`, `<string.h>`)
2. External libraries (`<mylib/header.h>`)
3. Local project headers (`"local_header.h"`)

```c
// good
#include <stdint.h>
#include <string.h>

#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

#include "app_config.h"
#include "app_sensor.h"

// avoid - mixed scope, no grouping
#include "app_config.h"
#include <stdint.h>
#include <zephyr/kernel.h>
#include "app_sensor.h"
#include <string.h>
```

Do not put the module's own header first - that is a C++ convention. In C, standard library headers always come first. When a file has no standard library includes, the local header can appear first with no blank line needed. External libraries (like Unity's `"unity.h"`) are group 2, not group 3 - separate them from local project headers with a blank line.

**When to deviate**: Some build systems or frameworks require a specific header to appear first (e.g. a precompiled header or framework umbrella header). Place that header before the groups.

---

### Header File Ordering

**Intent**: A header file should read top-to-bottom from general to specific, following the Newspaper Metaphor from the general guide.

**Convention**: Within a header file, order declarations:

1. Include guard (`#pragma once`)
2. Includes (grouped as above)
3. Constant definitions (`#define`)
4. Type definitions (`typedef enum`, `typedef struct`)
5. Function declarations

```c
#pragma once

#include <stdint.h>

#define APP_MAX_SENSORS 16

typedef enum {
  APP_SENSOR_TEMPERATURE = 1,
  APP_SENSOR_HUMIDITY = 2,
} app_sensor_type_t;

typedef struct {
  app_sensor_type_t type;
  uint16_t address;
} app_sensor_config_t;

int app_sensor_init(const app_sensor_config_t* config);
int app_sensor_read(app_sensor_config_t* sensor, int32_t* value);
```

Do not interleave `#define` constants with enum and struct type definitions, even when the constants feel semantically related to the types (e.g. sentinel values near enums). All `#define` constants must appear above all `typedef enum` and `typedef struct` definitions.

**When to deviate**: When a type definition depends on a constant, the constant must appear first regardless of this ordering.

---

## Formatting

### Indentation

**Intent**: Consistent indentation within a project.

**Convention**: 2-space indentation is preferred. However, C codebases vary widely in indentation style. Check the existing project convention before applying this default. On first review, check the existing indentation (2-space, 4-space, tab) and save the result to memory. Do not flag indentation issues that match the project's established convention, even if it differs from 2-space.

**When to deviate**: Always match the existing project convention. If a project uses 4-space or tab indentation, follow that.

---

### Line Length

**Intent**: Keep lines within a comfortable reading width.

**Convention**: 80 characters is the hard limit. Count characters when writing or modifying code - do not rely on visual estimation. See the general guide's Line Length rule for the cognitive load heuristic - a line with many components warrants splitting even under 80 characters.

**When to deviate**: Long string literals (see String Literals rule below), include paths, or URLs that cannot be meaningfully broken.

---

### String Literals

**Intent**: String literals must be grepable. A developer searching for an error message should find it in one place.

**Convention**: Never break string literals across lines, even if they exceed the line length limit. This does not mean the entire function call must stay on one line - the string stays intact, but arguments after the string can be broken to their own lines for readability.

```c
// good - string intact, arguments broken for readability
LOG_ERROR(
  "sensor %d returned an unexpected value: expected %d, got %d",
  id,
  expected,
  actual
);

// good - short call fits on one line
fprintf(stderr, "failed to initialize connection to %s\n", host);

// avoid - broken string literal defeats grep
fprintf(stderr, "failed to initialize connection"
  " to %s on port %d\n", host, port);

// avoid - string intact but everything crammed on one line
LOG_ERROR("sensor %d returned an unexpected value: expected %d, got %d", id, expected, actual);

// good - multi-line string split at logical boundaries (newlines, sentences)
const char* usage =
  "Usage: program [options] <input> <output>\n"
  "\n"
  "Options:\n"
  "  -h  Show this help message\n"
  "  -v  Enable verbose output\n";

// avoid - split mid-sentence (breaks grepability)
const char* message =
  "failed to initialize connection"
  " to the remote server";
```

**When to deviate**: Long multi-line strings (help text, usage messages) can be split into adjacent string literals at logical boundaries - newlines, end of sentence, or paragraph breaks. Each literal should be a complete, grepable thought. When a single sentence exceeds 80 characters, split mid-sentence to keep it readable - a developer is unlikely to scroll horizontally when skimming code. Readability takes priority over grepability for very long lines.

---

### Brace Style

**Intent**: Consistent brace placement that visually separates function signatures from bodies and keeps control flow compact.

**Convention**: Based on K&R. Single-line function signatures get the opening brace on the next line. Control flow (`if`, `for`, `while`, `switch`, `do`) gets the opening brace on the same line. `else` and `else if` go on a new line after `}` - each control block is a clear, self-contained unit.

Only split function signatures to multiple lines when the single-line version exceeds 80 characters. When splitting, keep the return type on the same line as the function name and split the arguments to multiple lines. Do not split the return type to its own line - always split on arguments instead. The exception is zero-argument signatures: when there are no arguments to split (`(void)`) and the single-line signature still exceeds 80 characters, place the return type on its own line and the function name + `(void)` on the next line. This is the only legitimate split for zero-arg signatures. `) {` go together on the closing line - **never** `) \n{`. This is a common mistake. The closing paren and opening brace must be on the same line: `) {`. The `) {` serves the same role as `\n{` on a single-line signature - a uniform visual separator between function args and body. Putting `{` on yet another line adds too much visual gap.

When a function signature or call is split across multiple lines, the closing `)` goes on its own line at the construct's indent level - never glued to the last parameter or argument. The character that follows `)` stays with it on the same line: `{` on a definition (`) {`), `;` on a declaration or call statement (`);`), or whatever syntactic punctuation continues the expression. This rule applies to definitions, declarations, and call sites uniformly. It also applies to single-argument call sites that wrap (e.g. a macro call whose argument pushes the line past 80 characters): the wrapped form is `RUN_TEST(\n  test_name\n);` with the closing `)` on its own line, not `RUN_TEST(\n  test_name);` with `);` glued to the argument. Splits happen to satisfy line-length requirements; if the construct fits on one line, keep it on one line.

Exception: when a multi-line call is the entire condition of an `if`, `while`, or `for`, the call's closing `)` and the control-flow construct's closing `)` go together as `))` on their own line - not split onto separate lines. See § Line Breaks in Long Expressions § Multi-line function calls inside `if` conditions for the full pattern. Splitting `))` onto two lines fragments a single semantic unit and pushes the body indent across two visual hops.

Multi-line parameters are indented one level (2 spaces) from the left margin - not aligned to the opening paren, and not at a deeper indent than the function body. One parameter per line. The same one-per-line principle applies to function call sites when they are split to multiple lines.

```c
// good - single-line signature: brace on next line
int start_services(void)
{
  // ...
}

// good - multi-line params: `) {` on closing line, params at body indent
static void error_handler(
  address_t* host,
  uint8_t id,
  uint8_t reason,
  bool server
) {
  // ...
}

// good - multi-line declaration: `);` on its own line at function indent
sensor_status_t sensor_write(
  sensor_t* sensor,
  const void* data,
  size_t length,
  size_t* out_written
);

// good - multi-line call site: `);` on its own line at the call's indent
sensor_write(
  sensor,
  data,
  length,
  &written
);

// good - single-arg macro wrap (test name pushes call past 80 chars):
// closing `)` on its own line, same rule as multi-arg splits
RUN_TEST(
  test_register_channel_with_callback_defers_until_lock_release
);

// good - zero-arg signature over 80 chars: return type on its own line
mock_sensor_resources_find_channel_args_t
mock_sensor_resources_find_channel_received(void);

// good - zero-arg definition over 80 chars: same split, brace on next line per single-line-signature rule
mock_sensor_resources_find_channel_args_t
mock_sensor_resources_find_channel_received(void)
{
  // ...
}

// good - control flow: brace on same line
if (result < 0) {
  handle_error();
}

// good - else on new line
if (result < 0) {
  handle_error();
}
else if (result == 0) {
  handle_empty();
}
else {
  handle_success();
}

// good - do-while
do {
  c = getchar();
} while (c != EOF);

// good - empty function body
void noop(void) {}

// good - single-line function body
void stop(void) { should_exit = true; }

// good - switch/case: case indented inside switch, blank line between cases
switch (action) {
  case ACTION_START: {
    char name[MAX_NAME_LEN];
    get_name(item, name);
    break;
  }

  case ACTION_STOP:
    cleanup(item);
    break;

  default:
    break;
}

// good - fallthrough cases grouped together
switch (priority) {
  case PRIORITY_NONE:
  case PRIORITY_LOW:
  case PRIORITY_NORMAL:
    return "default";

  case PRIORITY_HIGH:
    return "high";

  default:
    return "unknown";
}

// good - compact mapping: case maps directly to value, no logic
switch (type) {
  case SENSOR_REPORT: return "sensor_report";
  case DEVICE_STATUS: return "device_status";
  case CONFIG_UPDATE: return "config_update";
  default: return "unknown";
}

// good - struct/enum/union: brace on same line
typedef struct {
  uint8_t type;
  uint16_t instance;
} object_id_t;

// avoid - `) {` split to separate lines on multi-line signature
int sensor_configure(
  sensor_t* sensor,
  uint16_t address,
  sensor_callback_t callback
)
{
  // ...
}

// avoid - multi-line declaration: `);` glued to last parameter line
sensor_status_t sensor_write(
  sensor_t* sensor,
  const void* data,
  size_t length,
  size_t* out_written);

// avoid - multi-line call site: `);` glued to last argument line
sensor_write(
  sensor,
  data,
  length,
  &written);

// avoid - single-arg macro wrap with `);` glued to the argument
RUN_TEST(
  test_register_channel_with_callback_defers_until_lock_release);

// avoid - return type on separate line; always split on arguments instead
sensor_result_t
sensor_init(sensor_t* sensor)
{
  // ...
}

// avoid - zero-arg signature kept on one line over 80 chars; the carve-out
// applies because there are no arguments to split on
mock_sensor_resources_find_channel_args_t mock_sensor_resources_find_channel_received(void);

// avoid - function brace on same line as single-line signature
int start_services(void) {
  // ...
}

// avoid - else on same line as closing brace
if (result < 0) {
  handle_error();
} else {
  handle_success();
}

// avoid - params aligned to opening paren
static void error_handler(address_t* host,
                          uint8_t id,
                          uint8_t reason,
                          bool server) {
  // ...
}

// avoid - params at deeper indent than body
static void error_handler(
    address_t* host,
    uint8_t id,
    uint8_t reason,
    bool server
) {
  // ...
}

// avoid - multiple params per line in multi-line signature
void request_handler(
  address_t* host, int* handle,
  uint8_t* buffer, uint16_t length
) {
  // ...
}
```

**When to deviate**: Follow the existing style of a codebase. If the project uses `} else {`, use `} else {`.

---

### Single-Statement Bodies

**Intent**: Reduce visual noise by omitting braces when the body is a single statement, while keeping the statement visually distinct from the condition.

**Convention**: Omit braces for single-statement bodies. The statement goes on its own line, never on the same line as the condition. If any branch of an `if`/`else` chain needs braces (because it has multiple statements), all branches use braces. Nested single-statement control flow without braces is acceptable.

```c
// good - single statement on its own line
if (result < 0)
  return -1;

for (int i = 0; i < count; i++)
  process(i);

while (pending())
  drain();

// good - all-or-nothing: one branch needs braces, so all get braces
if (result < 0) {
  log_error(result);
  return -1;
}
else {
  process(result);
}

// good - nested single-statement without braces
for (int i = 0; i < length; i++)
  if (buffer[i] == 0)
    count++;

// avoid - braces on a single statement
if (result < 0) {
  return -1;
}

// avoid - mixed braces in if/else chain
if (result < 0) {
  log_error(result);
  return -1;
}
else
  process(result);

// avoid - same-line body blends condition and action together,
// especially for early returns where the action should be visually distinct
if (!handle) return -1;
if (index >= limit) continue;
```

**When to deviate**: Follow the existing style of a codebase. If the project uses braces on single statements, match that.

---

### Pointer Declaration Style

**Intent**: The pointer is part of the type, not part of the variable name. `int* foo` reads as "pointer to int named foo."

**Convention**: Bind the `*` to the type side: `int* p`, not `int *p`. The traditional C rationale for `int *p` is that `int *p, q` declares one pointer and one int - avoid this by not declaring multiple variables on one line.

Casts follow the same principle - the `*` stays with the type inside the parens. Always write `(type) expression` with a space after the closing paren, not `(type)expression`. The space separates the cast from the expression, just like a space separates a type from a variable name in a declaration.

```c
// good
int* values = calloc(count, sizeof(int));
const char* get_name(object_t* obj);
float temperature = (float) raw_value / 16;
const field_t* fields = (void*) raw_fields;

// avoid - star binds to variable name
int *values = calloc(count, sizeof(int));
const char *get_name(object_t *obj);

// avoid - multiple pointer declarations on one line
int *p, *q;

// avoid - no space between cast and expression
const field_t* fields = (void*)raw_fields;
```

**When to deviate**: Follow the existing style of a codebase. Exception: `*const` keeps the `*` on the variable side because `*const` is a single concept ("constant pointer"). See the `const` Correctness rule for examples.

---

### Spacing

**Intent**: Consistent spacing that visually distinguishes control flow from function calls and keeps expressions readable.

**Convention**: Space after control-flow keywords (`if`, `for`, `while`, `switch`). No space between a function name and its opening paren. No space after function-like operators (`sizeof`, `typeof`, `alignof`). Spaces around binary operators. No space between unary operators and their operands.

```c
// good - space after keywords, no space on function calls
if (result < 0)
  return -1;

for (int i = 0; i < count; i++)
  process(i);

switch (action) {
  // ...
}

size_t n = sizeof(buffer);

// good - spaces around binary operators
int total = count + offset;
bool valid = (result >= 0) && (result < limit);

// good - no space on unary operators
count++;
bool ready = !pending;
int value = *ptr;

// avoid - no space after keyword
if(result < 0)
  return -1;

// avoid - space between function name and paren
process (value);

// avoid - no spaces around binary operators
int total = count+offset;
```

**When to deviate**: Follow the existing style of a codebase.

---

### Comment Style

**Intent**: Comments should be compatible with documentation generators. Public API documentation uses Doxygen format so it can be extracted into generated docs and parsed by IDE tooling (hover tooltips, signature help).

**Convention**: Three comment forms, each with a distinct role:
- `/** */` for Doxygen documentation (functions, types, files)
- `//` for any non-Doxygen, non-header-guard prose comment, regardless of line count or position - inline trailing, standalone single line, or multi-line block. Multi-line prose uses stacked `//` lines, one per logical line.
- `/* GUARD */` for header guard closing comments (when not using `#pragma once`)

Doxygen uses `@` prefix for tags (`@brief`, `@param`, `@return`), not `\`. Use `///<` for trailing inline docs on struct fields, enum values, and `#define` constants. Align `@param` descriptions within their group. `@return` gets its own block separated by a blank line from the `@param` block.

For a `#define` constant, the form choice is between three options, in this order of preference:

- **No comment.** Most `#define` constants do not need their own docstring. The constant's meaning is typically carried by the file `@brief`, by the function that takes or returns it, or by the constant's name itself. A noisy comment that paraphrases the name is worse than no comment - see § Identifier Comment Redundancy Test for the principle and § Constants and Enum-Element Documentation for the site-specific exceptions.
- **Trailing `///<`** when a constant or group of constants warrants a short clarifying comment. For groups, the trailing form aligns column-wise across the members. For a standalone constant that needs a short single-line annotation, trailing is still the right form - block form is not the fallback when no group-context applies.
- **Block form `/** @brief X */`** only when the comment genuinely does not fit a single line - a multi-sentence contract description, a multi-paragraph contract that callers must read in full, or a constant whose use carries hidden complexity that needs paragraphs to convey. Standalone-ness alone does not justify block form; a single `#define` whose comment fits on one line uses trailing `///<`, not block.

```c
// good - no comment; the constant's name carries it and the file @brief
// covers the configuration domain
#define SENSOR_DEFAULT_POLL_MS 100

// good - trailing ///< on a group of related constants whose annotations
// align column-wise
#define SENSOR_REG_STATUS      0x00  ///< Status register; read-only.
#define SENSOR_REG_CONTROL     0x01  ///< Control register; write to enable channels.
#define SENSOR_REG_CALIBRATION 0x02  ///< Calibration record base address.

// good - block form when the constant carries a multi-sentence contract
// that does not fit a single trailing line
/**
 * @brief Fixed-point Q-format used for all sensor gain coefficients.
 *
 * Gain values supplied to `sensor_set_gain` and stored in calibration
 * records are interpreted as Q16.16 (16 integer bits, 16 fractional
 * bits). A floating-point gain `g` is encoded as `(int32_t)(g * (1 <<
 * 16))`. The driver does not validate this encoding; supplying a value
 * in any other format produces silently incorrect readings.
 */
#define SENSOR_GAIN_Q_FORMAT 16

// avoid - trailing ///< that paraphrases the constant's name and adds
// nothing the file @brief or the name itself does not already carry
#define SENSOR_DEFAULT_PORT 8080  ///< Default TCP port for sensor connections.

// avoid - block form for what would be a short trailing comment if it
// belonged anywhere
/** @brief Default TCP port for sensor connections. */
#define SENSOR_DEFAULT_PORT 8080
```

Do not use section divider comments in any file type - `.c`, `.h`, or test files. This includes `// -- Public API ---`, `// -- Forward declarations ---`, `// -- Helpers ---`, `// -- Tests ---`, and any similar decoration. The code structure is defined by function ordering and `static` visibility, not comments. See the general guide's Write Self-Documenting Code rule.

`/** */` is preferred over `///` for C - `///` silently breaks if one line is missing the prefix. `/** */` is also the format universally parsed by IDEs (VS Code, CLion, clangd) and compatible with all major doc generation paths (Doxygen, Sphinx via Breathe, clang-doc).

All public functions require a Doxygen docstring on the declaration in the header file - not on the implementation in the `.c` file. Header docs ride along with the SDK; source file docs get lost or compiled out. Static (file-internal) functions do not require a docstring, but may have one if the function is complex. Test functions are a stricter case — never carry a docstring; see `c/testing.md` § Test Function Docstrings.

```c
// good - function docs on declarations in the header
/**
 * @brief Opens a serial port device with the given configuration.
 *
 * @param device  Path to the serial device.
 * @param config  Port configuration. Must not be NULL.
 * @param timeout Connection timeout in milliseconds.
 *
 * @return Handle on success, NULL on failure.
 */
sp_port_t* sp_open(const char* device, const sp_config_t* config, uint32_t timeout);

// good - brief-only function doc (single line)
/** @brief Stops the sensor and releases resources. */
void sensor_stop(sensor_t* sensor);

// good - inline comments with //
int result = sensor_read(&sensor, &value);
if (result < 0)
  return -1; // hardware unreachable

// good - trailing doc on a struct field that needs one
typedef struct {
  uint8_t type;
  uint16_t address;
  int32_t offset;
  uint8_t mode;       ///< SENSOR_MODE_POLLED or SENSOR_MODE_INTERRUPT.
} sensor_config_t;

// good - trailing doc on enum values
typedef enum {
  SENSOR_TEMP = 1,      ///< Reads in degrees Celsius
  SENSOR_HUMIDITY = 2,  ///< Reads as relative percentage (0-100)
} sensor_type_t;

// avoid - `///` for function docs (silently breaks if one line misses prefix)
/// @brief Reads the current sensor value.
/// @param sensor Sensor handle from init.
/// @return 0 on success, -1 on failure.
int sensor_read(sensor_t* sensor, int32_t* value);

// avoid - `\` prefix for Doxygen tags
/**
 * \brief Reads the current sensor value.
 * \param sensor Sensor handle.
 * \return 0 on success.
 */

// avoid - `/* */` for inline comments in code
int result = sensor_read(&sensor, &value);
if (result < 0)
  return -1; /* hardware unreachable */

// avoid - single-line standalone `/* */` prose
/* Convert raw ADC counts to millivolts using the calibrated reference. */
int32_t millivolts = (raw * sensor->reference_mv) / SENSOR_ADC_FULL_SCALE;

// good - same comment as `//`
// Convert raw ADC counts to millivolts using the calibrated reference.
int32_t millivolts = (raw * sensor->reference_mv) / SENSOR_ADC_FULL_SCALE;

// avoid - multi-line `/* */` prose block
/*
 * The hardware loads the gain register only on the next conversion
 * cycle, so a write here does not take effect until the caller issues
 * the next sensor_read.
 */
sensor->pending_gain = gain;

// good - same comment as stacked `//`
// The hardware loads the gain register only on the next conversion
// cycle, so a write here does not take effect until the caller issues
// the next sensor_read.
sensor->pending_gain = gain;
```

**When to deviate**: Follow the existing style of a codebase. If the project uses `///` for docs, match that.

---

### Type `@brief` Body Shape

**Intent**: Type docstrings (struct, enum, typedef) name what the type IS. They are not the place for architectural narration, layout specifics, or design rationale - those belong in the design document or the file `@brief`.

**Convention**: For struct, enum, and typedef declarations, the `@brief` is a single line that names the type. **A body is the exception, not the default.** When in doubt, omit the body.

A body is justified only when one of these is true:

- A contract-level invariant the caller must know that genuinely cannot fit in the one-line `@brief` (e.g. "Codes other than `OK` are recoverable; precondition violations trap and do not return.").
- A pair-structured contrast covering the type's paired options, where the type names a paired set of choices.
- An `@internal` or audience marker required by project convention (see § Internal API Documentation).

The body is **not** for any of the following. These are the recurring leak shapes; flag each one against the decision test below before deciding to drop:

- **Byte-layout placement.** "Sits at offset 0 of the calibration record", "prepended to every reading", "stored inside the opaque sensor handle", "fixed 64 bytes regardless of channel count". Placement is an implementation choice; a unit test that allocates the type differently invalidates the docstring. Placement does not belong in type identity.
- **Architectural flow narration.** "The driver writes the configuration fields at boot and the ISR reads them on every conversion cycle", "init paths look up the entry whose channel_id matches the requested channel", "delivered to the application at the next polling interval". Describes how the system uses the type, not what the type IS. System behavior belongs in the design doc.
- **Cross-cutting design properties.** "Both the driver and the recovery thread survive a reset by re-reading this configuration", lifecycle guarantees, recovery protocols, packing rationale ("packed so the on-wire layout matches the I2C register map..."). Design rationale belongs in the design doc and the README.
- **Field listings dressed as prose.** "Carries the channel's gain and the calibration mode the driver applies on each read..." - the struct definition already lists the fields. Restating them in prose adds no information the reader did not have from looking at the struct.
- **Audience tutorials.** "Test code reads this layout directly to inspect the calibration state and to seed values for scenarios the public API cannot reach." Audience context belongs in the file `@brief`, not on every type that audience touches.
- **Implementation arithmetic.** Register-offset computations, conversion-time calculations, range predicates, counter-shape semantics ("free-running"), init sequencing. These describe how the implementation manipulates the type, not what the type IS. Implementation details belong in the implementation file's comments. (A formula that states a *contract* — e.g. a fixed-point encoding the caller must respect — is a contract-level invariant, not an implementation walk; see the good example below.)

```c
// avoid - body has architectural flow narration, byte-layout placement,
// and field listing dressed as prose
/**
 * @brief Sensor configuration parameters.
 *
 * Loaded from the configuration file at startup and applied to every
 * reading. Packed so the on-wire size matches the layout the calibration
 * tooling produces. Carries the sensor type, the address of the hardware
 * register, and a calibration offset the firmware applies to each raw
 * reading before returning it to the caller.
 */
typedef struct {
  uint8_t type;
  uint16_t address;
  int32_t offset;
} sensor_config_t;

// good - one line; what the type IS
/**
 * @brief Sensor configuration parameters.
 */
typedef struct {
  uint8_t type;
  uint16_t address;
  int32_t offset;
} sensor_config_t;

// good - body carries a contract-level invariant the caller must respect:
// recoverability, trap behavior, and which codes the recovery applies to.
// The body is not narration; each sentence is a contract a caller relies on.
/**
 * @brief Result codes returned by sensor_read() and sensor_write().
 *
 * Codes other than `SENSOR_OK` are recoverable; the caller may retry after
 * the condition that produced the code is cleared. Precondition violations
 * trap and do not return a code at all.
 */
typedef enum {
  SENSOR_OK            = 0,
  SENSOR_NOT_READY     = 1,
  SENSOR_TIMEOUT       = 2,
  SENSOR_OUT_OF_RANGE  = 3,
} sensor_status_t;
```

**Decision test**: for any candidate body sentence, name the contract-level invariant the sentence carries that the type's name does not, and that the caller cannot derive from the type's name plus general programming knowledge. If the sentence is placement, flow, rationale, field listing, audience tutorial, or implementation arithmetic, drop it.

**When to deviate**: A small number of types genuinely need contract-level body content that does not fit in the one-liner - error-code enums whose recovery semantics differ between codes, paired-option enums whose two options must be contrasted to be understood, types with non-obvious lifetime or thread-safety contracts the caller must respect, fixed-point or fixed-precision typedefs whose encoding is the contract. The body is justified in those cases.

---

### Function Docstring Body Shape

**Intent**: A function docstring describes the function's API contract - what the caller passes in, what comes back, and the invariants the caller must respect or the function will guarantee. It is not the place to describe how the function does its work, what internal state it touches, or what cooperating callers in the system observe. Mechanism belongs in source comments and the design document; cross-caller behavior belongs in the type or module documentation. Keeping the docstring at contract-level keeps the public API durable as the implementation evolves.

**Convention**: The docstring's `@brief`, `@param`, and `@return` blocks describe what the caller of *this* function must know to use it correctly. **A body is the exception, not the default.** When in doubt, omit the body.

A body is justified only when one of these is true:

- A contract-level invariant the caller must respect that does not fit in `@param`/`@return` (e.g. "Must be called from the same thread that called `sensor_init`.").
- A precondition or postcondition that crosses arguments (e.g. "If `length` is non-zero, `buffer` must point to at least `length` writable bytes.").
- A guarantee about caller-observable state at return that the return value alone does not carry (e.g. "On `SENSOR_BUSY`, `*reading` is left unchanged.").

The body is **not** for any of the following. These are the recurring leak shapes; flag each one against the decision test below before deciding to drop:

- **Restating `@param` or `@return`.** Per-status output tables ("OK → equal to `length`; FULL → 0; TRUNCATED → equal to `payload_size`"), per-argument paraphrases, "returns 0 on success and -1 on failure" prose when the return type and `@return` already carry it. The argument and return blocks are the structured form of this content; restating it in prose adds no information and decays when the structured form changes without the prose being updated.
- **Internal state-field references.** Naming private struct fields the function touches ("sets `calibration_dirty`"), naming static module variables ("updates the polling counter"), naming any identifier the caller cannot see at the API boundary. The caller does not have visibility into internal state, and naming it leaks implementation detail that constrains future refactoring.
- **Library mechanism steps.** Describing the function's internal procedure in caller-facing prose ("the function looks up the calibration entry, applies the offset, then writes the result to the output buffer"). Mechanism is the implementation's job; the docstring's job is the contract the caller relies on. A future implementation that achieves the same contract differently invalidates the prose.
- **Cross-caller behavior.** A docstring on one function that describes another caller's observations ("subsequent calls to `sensor_poll` observe the new calibration"). Each function's docstring describes what *this* caller sees and must do; cross-caller invariants belong in the type, module, or file documentation that the cooperating callers all read.
- **Architectural or audience narration.** "This function is called by the ISR after each conversion cycle", "test code uses this entry point to seed scenarios the public API cannot reach". System flow and audience context belong in the file `@brief` or the design doc, not on every function the flow touches.

```c
// avoid - body restates @param out_corrected, names internal state, and
// describes library mechanism the caller cannot observe
/**
 * @brief Apply a calibration table to the sensor's active channels.
 *
 * @param sensor         Sensor handle from sensor_init.
 * @param calibration    Calibration table to apply.
 * @param out_corrected  Number of channels whose readings were corrected.
 *
 * @return SENSOR_OK on success, SENSOR_NOT_READY if the sensor has not
 *         completed init, SENSOR_OUT_OF_RANGE if any entry's gain is zero.
 *
 * Sets the calibration_dirty flag in the sensor state and walks each
 * channel's calibration entry, applies the offset and gain, then writes
 * the corrected reading to the channel's output buffer. On SENSOR_OK,
 * out_corrected equals the active channel count; on SENSOR_NOT_READY,
 * out_corrected is zero; on SENSOR_OUT_OF_RANGE, out_corrected equals
 * the number of entries processed before the invalid one.
 */
sensor_status_t sensor_calibrate(sensor_t* sensor,
                                 const calibration_t* calibration,
                                 size_t* out_corrected);

// good - body removed; @param out_corrected and @return already carry the
// per-status outcome, and the mechanism is an implementation detail that
// does not belong in the public contract
/**
 * @brief Apply a calibration table to the sensor's active channels.
 *
 * @param sensor         Sensor handle from sensor_init.
 * @param calibration    Calibration table to apply.
 * @param out_corrected  Number of channels whose readings were corrected.
 *
 * @return SENSOR_OK on success, SENSOR_NOT_READY if the sensor has not
 *         completed init, SENSOR_OUT_OF_RANGE if any entry's gain is zero.
 */
sensor_status_t sensor_calibrate(sensor_t* sensor,
                                 const calibration_t* calibration,
                                 size_t* out_corrected);

// good - body carries a contract-level invariant that does not fit in
// @param/@return: a precondition crossing two arguments
/**
 * @brief Read up to `length` bytes from the sensor into `buffer`.
 *
 * @param sensor  Sensor handle from sensor_init.
 * @param buffer  Destination buffer.
 * @param length  Maximum bytes to read.
 *
 * @return Number of bytes read, or a negative error code.
 *
 * If `length` is non-zero, `buffer` must point to at least `length`
 * writable bytes. The function does not bounds-check `buffer`.
 */
ssize_t sensor_read(sensor_t* sensor, uint8_t* buffer, size_t length);
```

**Caller-obligation is contract, not mechanism.** A statement that names an action the *caller* must take or refrain from taking ("the caller must initialize the calibration table before calling `sensor_calibrate`", "do not call from an ISR context") is a contract-level invariant and belongs in the body when it does not fit `@param`/`@return`. The mechanism-vs-contract distinction is decided by *whose* action is being described: the library's actions are mechanism (drop them), the caller's obligations are contract (keep them when they don't fit elsewhere).

**Decision test**: for any candidate body sentence, ask: would the caller's correct use of this function change if this sentence were removed? If yes, the sentence is a contract; keep it. If no, the sentence is mechanism, narration, or restatement; drop it. The test fires per sentence, not per docstring; a body with one contract sentence and three mechanism sentences keeps the contract sentence and drops the rest.

**When to deviate**: Documented thread-safety contracts, lifecycle protocols, and cross-call invariants ("must be paired with `sensor_release`") legitimately require body content that exceeds `@param`/`@return`. The body is justified for those.

---

### Identifier Comment Redundancy Test

**Intent**: Identifiers composed of word-tokens already encode an English phrase. A `///<` comment that respaces, paraphrases, or grammatically expands the identifier into prose carries no information beyond what the name itself carries. The reader who can read the identifier already had the meaning; the comment is noise that imposes reading cost without delivering content.

**Convention**: Before writing a `///<` comment on any identifier — enum element, struct field, or `#define` constant in a documented group — apply the redundancy test. (The same principle applies when documenting any identifier with any single-line comment form, but the trailing `///<` is the canonical site where the test runs.)

A "loose `#define`" below means a `#define` constant that is not grouped under a shared `@brief` block — typically a file-scope constant whose context comes from the file `@brief` rather than a group-level docstring.

1. **Detokenize the identifier.** Split on `_` and CamelCase boundaries, lowercase, read the result as the English phrase it forms.
   - `SENSOR_OUT_OF_RANGE` → "sensor out of range"
   - `channel_count` → "channel count"
   - `gainScale` → "gain scale"
2. **Ask whether a comment would carry information beyond:**
   - That detokenized phrase
   - The enclosing type's `@brief` (for enum elements and struct fields) or the file `@brief` (for loose `#define`s)
   - The routing destination for consumer-specific content. If the meaning is "which subset this function accepts/produces" or "what this function does with the value," route it to the consuming function's `@param`/`@return` block, not to a `///<` here.

If the answer is no, the comment is redundant. Drop it.

The default is bare. A `///<` is justified only when the comment carries information the identifier and its surrounding context cannot — content like an option-set the type alone does not carry, a contract-level invariant the caller must respect, an audience or scope role that disambiguates similarly-named fields, or an acronym expansion the reader cannot recover from the name (e.g. `///< IEEE 802.1AS grandmaster identifier.` on a constant whose name uses an acronym not derivable from C training-data context). The site-specific sub-sections below name what content counts as justified for each application site.

#### Failure shapes

Three patterns produce redundant comments. Recognize each in your own draft before writing the comment, not after.

**Failure shape 1 - respacing the identifier.** The comment is the detokenized name with minor grammar (added subject, verb tense, filler words). Detokenizing the identifier produces the same phrase the comment carries.

```c
// avoid - each comment is the identifier respaced into prose
typedef enum {
  PARSER_NOT_READY     = 1, ///< Parser is not yet ready.
  PARSER_OUT_OF_RANGE  = 4, ///< Value is out of range.
  PARSER_UNCONFIGURED  = 5, ///< Parser is unconfigured.
} parser_status_t;
```

`PARSER_NOT_READY` detokenizes to "parser not ready"; the comment is the same phrase with an added verb. Drop.

**Failure shape 2 - defining a token the identifier already uses.** The comment is a paraphrase or dictionary gloss of a token already in the identifier. Detokenize the identifier and the comment's content is the same content rendered with one or two more words.

```c
// avoid - the comment glosses a token already in the identifier
typedef enum {
  PARSER_TIMEOUT  = 3, ///< The operation timed out.
  PARSER_OK       = 0, ///< Operation completed successfully.
  PARSER_BUSY     = 2, ///< Resource is currently in use.
} parser_status_t;
```

`TIMEOUT`, `OK`, and `BUSY` already encode their meaning; the comment is a gloss the reader did not need.

**Failure shape 3 - paraphrasing the set's `@brief` onto each member.** The comment restates the rationale or context the enum's (or `#define` group's) own `@brief` already establishes. The set-level documentation is correct; the per-member paraphrase duplicates it.

```c
// avoid - each comment paraphrases the enum's @brief onto the member
/** @brief Status codes returned by parser_read(). Non-zero values
 *         indicate the read could not produce a valid token. */
typedef enum {
  PARSER_OK             = 0, ///< Returned when the read produced a valid token.
  PARSER_NOT_READY      = 1, ///< Returned when the read could not produce a valid token because the parser isn't ready.
  PARSER_TIMEOUT        = 3, ///< Returned when the read could not produce a valid token due to timeout.
} parser_status_t;
```

The `@brief` already says these are status codes from `parser_read()` and that non-zero means the read failed. Repeating "returned when the read produced/could not produce a valid token" on each member adds nothing.

#### Good shape

```c
// good - identifiers detokenize into phrases that already carry the
// meaning; the enum's @brief explains the set; no per-element comment
// is justified
/** @brief Status codes returned by parser_read() and parser_write().
 *         Non-zero values indicate the operation could not complete. */
typedef enum {
  PARSER_OK            = 0,
  PARSER_NOT_READY     = 1,
  PARSER_BUSY          = 2,
  PARSER_TIMEOUT       = 3,
  PARSER_OUT_OF_RANGE  = 4,
} parser_status_t;
```

The good shape is the failure shape 3 enum with the per-member comments removed. The set-level `@brief` already carries "returned by parser_read()" and "non-zero means the operation could not complete," so the per-member glosses were duplicating it. The `@brief` and the identifiers together carry the meaning; nothing per-element is added.

Each application site (`#define` form choice, enum-element documentation, struct-field `///<` comments) instantiates this test with site-specific content categories that justify a `///<` despite the redundancy default. See § Constants and Enum-Element Documentation and § Struct Field `///<` Comments.

---

### Constants and Enum-Element Documentation

**Intent**: This section instantiates § Identifier Comment Redundancy Test for `#define` groups and enum elements. The default is bare. The site-specific exceptions below name when a `///<` is justified despite the redundancy default.

**Convention**: For a `#define` group or the elements of an enum, the per-element decision is governed by the redundancy test. Apply it before writing any `///<`. When the set-level `@brief`, the function-level argument or return docs, and the identifier itself carry the meaning, individual elements need no comment.

Documentation about a related group of constants routes to one of three places, in order of preference:

| Where the meaning lives | Carries | Example |
|---|---|---|
| The set's enclosing `@brief` | Why the options exist as a set, and what distinguishes them from each other | The enum type's `@brief` (or the file `@brief` for loose `#define`s) lays out the tradeoff that justifies the options |
| The function that takes or returns the constant | Which subset of values that function accepts or produces | A function returning the enum names the codes it can return in its `@return` block |
| The constant's name itself | The constant's identity | `PARSER_MODE_POLLED` does not need a docstring saying "polled mode" |

**Set-level `@brief` content.** The enum type's `@brief` (or the file `@brief` for a loose `#define` group) carries the set-level rationale: why the options exist, what differentiates them, and what tradeoff a caller is choosing among. The set-level `@brief` is the right place for content that applies to *all* members of the set. Duplicating that content onto each member is the redundancy failure shape "paraphrasing the set's `@brief` onto each member" - the per-member comment adds nothing the set-level prose does not already carry.

**Function-level enum selectivity.** When a function's `@param` or `@return` block references an enum type, list only the values the function actually accepts or produces. Do not list the full enum on every consuming function. A function returning a status enum names in `@return` only the codes it can return; a function accepting an enum-typed parameter names in `@param` only the values it accepts. Listing every enum element on every function dilutes the contract and produces false expectations about which values a given call can produce or accept.

If a caller needs to know which function clears a specific error condition, that information lives in the recovery function's own docs (where the call is the topic) or in the consuming function's `@return` block — not as a comment on the enum element. The enum element stays bare; navigation between codes and recovery routines is the surrounding documentation's job.

Mixed presence within a group — some elements carrying `///<`, others bare — is the expected shape, not an inconsistency to fix. The `general/CLAUDE.md` § Consistent Formatting Within Groups rule governs *how* a comment is formatted (alignment, placement, line breaks), not *whether* each element has one.

**Edge case — every element warranted**: If every element of an enum independently passes the redundancy test for distinct reasons (for example, an error enum where each code carries a contract-level invariant the type alone cannot convey), every element may legitimately carry a `///<`. The per-element test still applies; the all-commented result is downstream of every element independently warranting a comment, not a relaxation of the default.

---

### Struct Field `///<` Comments

**Intent**: This section instantiates § Identifier Comment Redundancy Test for struct fields. Field-level `///<` comments name what a field IS only when the field's name and type, in the context of the enclosing type's `@brief`, do not already convey it. Translating the field name into a short English phrase adds noise without information.

**Convention**: Field-level `///<` comments are the **exception, not the default**. Bare is the default. The redundancy test applies: a `///<` must add information the field's name + type + the enclosing type's `@brief` do not already convey.

A `///<` that translates the name into a short English phrase, restates the type, or rephrases a role the type's `@brief` already covers fails the test.

A `///<` is justified only when the comment carries one of:

- An enum option set the field's *declared* type does not carry (e.g. `///< SENSOR_MODE_*` on a `uint8_t mode` whose conceptual values come from `sensor_mode_t`). The discriminator is the declared type, not whether an enum exists conceptually — a field declared as `sensor_mode_t mode` does not need the comment because the declared type already names the value set. The comment shape is the prefix glob (`SENSOR_MODE_*`), not an enumeration of every member; enumerating members (`///< SENSOR_MODE_POLLED or SENSOR_MODE_INTERRUPT.`) is a failure shape — too verbose and prone to drifting out of sync with the enum. Skip the comment entirely when the field name already carries the prefix (e.g. `uint8_t sensor_mode;` — the name routes the reader to the enum without help from `///<`).
- An audience or scope role that disambiguates similarly-named fields (e.g. `///< Caller-owned; freed by sensor_destroy().` on a buffer pointer, distinguishing it from a callee-owned counterpart elsewhere in the same struct).
- A contract-level invariant the caller must maintain (e.g. `///< Reserved; must be zero.` on a padding array, or `///< Optional; may be NULL.` on a callback pointer).

```c
// avoid - the first four comments translate field names into English; mode
// enumerates members instead of using the prefix glob.
typedef struct {
  uint16_t register_address;  ///< Register address.
  uint16_t timeout_ms;        ///< Timeout in milliseconds.
  uint8_t  retry_count;       ///< Number of retries before giving up.
  uint8_t  channel_count;     ///< Number of channels.
  uint8_t  mode;              ///< SENSOR_MODE_POLLED or SENSOR_MODE_INTERRUPT.
  uint8_t  reserved[3];
} sensor_channel_config_t;

// good - the type's @brief and field names self-document. Only mode keeps
// a ///< because the option set is not derivable from uint8_t, and reserved
// keeps a ///< because the must-be-zero contract is not derivable from the
// name. The mode comment uses the prefix glob, not an enumeration.
typedef struct {
  uint16_t register_address;
  uint16_t timeout_ms;
  uint8_t  retry_count;
  uint8_t  channel_count;
  uint8_t  mode;          ///< SENSOR_MODE_*
  uint8_t  reserved[3];   ///< Must be zero.
} sensor_channel_config_t;
```

Mixed presence of `///<` — some fields carry it, others do not — is correct behavior when only some fields need clarification, not an inconsistency to fix. The `general/CLAUDE.md` § Consistent Formatting Within Groups rule governs *how* a comment is formatted (alignment, indent), not *whether* each field has one.

**Edge case — every field warranted**: A struct whose every field independently passes the redundancy test may legitimately have a `///<` on every field. The per-field test still applies; the all-commented result is downstream of every field independently warranting a comment, not a relaxation of the default.

---

### Internal API Documentation

**Intent**: Library-internal headers (e.g. `sensor_internal.h`) declare functions visible to library developers but excluded from generated public API docs. These declarations need documentation for the developer audience without polluting public docs.

**Convention**: Use full Doxygen docstrings on internal-header declarations, using the same tags and structure as the library's public API (`@brief`, body where useful, `@param`, `@return`), with the `@internal` tag at the top of each block. The `@internal` pattern applies to all declaration kinds in internal headers — functions, types, enums, macros — not just functions. Doxygen's `INTERNAL_DOCS` Doxyfile setting controls whether `@internal` blocks appear in generated output. Default is `NO`, so public docs omit them; a developer working on the library flips `INTERNAL_DOCS = YES` locally to see internals. This gives two audiences one source of truth and requires no alternate commenting style.

`EXCLUDE_SYMBOLS` in the Doxyfile is an optional mechanical safety net for projects with naming conventions that mark certain symbols as excluded (e.g. a project-wide prefix convention for internal helpers). It catches symbols that are missing the `@internal` tag by a typo or oversight, but it is not a substitute for the tag — the tag is what tells a human reader the symbol is internal.

```c
// good - internal header declaration with @internal tag and full docstring
/**
 * @internal
 *
 * @brief Recomputes the cached calibration coefficients for a sensor.
 *
 * Walks the calibration record loaded at boot, applies any pending
 * runtime corrections, and writes the result to the sensor's coefficient
 * cache. Called by the public sensor API whenever calibration state
 * changes; library developers call it directly when bypassing the
 * top-level entry points during fault recovery.
 *
 * @param sensor  Sensor handle.
 *
 * @return 0 on success, -1 if the calibration record is missing or invalid.
 */
int sensor_internal_recompute_calibration(sensor_t* sensor);
```

Do not use plain C comments (`/* */` or `//`) to hide internal helpers from Doxygen. Hiding the symbol from the tool is the goal, but plain C comments send the wrong signal to a human reading the source: they read as "this function is less carefully documented than the rest of the library," when the right signal is "this function is internal and the generator knows to hide it."

```c
// avoid - plain C comments to hide an internal helper from Doxygen
// Recomputes calibration coefficients. Internal use only.
int sensor_internal_recompute_calibration(sensor_t* sensor);
```

Do not use `\cond` / `\endcond` block markers for single-symbol internal documentation. The `\cond` mechanism is appropriate for structural hiding of whole file regions; single-symbol cases are what `@internal` is for, and using `\cond` for one declaration adds machinery that obscures the simpler tag.

```c
// avoid - \cond markers for a single internal declaration
/** \cond INTERNAL */
/**
 * @brief Recomputes calibration coefficients.
 */
int sensor_internal_recompute_calibration(sensor_t* sensor);
/** \endcond */
```

**When to deviate**: Single-header libraries with no separate internal header do not need this convention — all declarations are already public.

---

### File-Level Documentation

**Intent**: File headers provide high-level context about the module's purpose and its external references.

**Convention**: Every `.h` file should have an `@file` Doxygen block immediately after the license header (or after `#pragma once` if no license header). This is the public API documentation. Separate `@file` and `@brief` with a blank line - both are top-level tags and the visual separation makes them easier to scan. The body paragraph is optional - if the `@brief` is sufficient, do not force a description that restates it.

```c
/**
 * @file sensor.h
 *
 * @brief Sensor reading and calibration interface.
 */
#pragma once
```

`.c` files only get an `@file` header when the implementation needs clarification that the `.h` does not provide - external knowledge references (RFC links, protocol specifications), complex algorithms, or non-obvious design choices. Most `.c` files are straightforward implementations of their `.h` and do not need a header. `main.c` (glue/entry point) does not need a header - application-level documentation belongs in the project README. Do not append "implementation" to `.c` briefs - it is redundant with the file extension.

When listing protocol references (RFCs, IEEE standards) in a file header comment, keep all entries at the same indentation level with columns vertically aligned. Do not indent entries hierarchically to show specification relationships. The reference list is a lookup table for "which RFC defines this field," not a taxonomy.

```c
/**
 * @file packet.c
 *
 * @brief IPv4/TCP/UDP packet construction and parsing.
 *
 * Reference RFCs:
 *   IPv4   RFC 791
 *   TCP    RFC 793
 *   UDP    RFC 768
 *   DSCP   RFC 2474
 *   ECN    RFC 3168
 */
```

**When to deviate**: If a `.c` file provides information that callers benefit from but that does not belong in the `.h` header (e.g. algorithm descriptions, protocol state machines), a file header is appropriate.

---

### Line Breaks in Long Expressions

**Intent**: When an expression must span multiple lines, the break point should make the continuation immediately obvious.

**Convention**: Place the operator at the start of the continuation line. All items in the broken expression go at the same indent level - do not put the first item on the opening line. For multi-line `if` conditions, use `if (\n  conditions\n) {` - the same pattern as multi-line function params. `) {` closes the condition and opens the block on one line.

```c
// good - operator leads the continuation line
bool is_bad_request =
  header_decode(buffer, index, &call) < 0
  || call.action == ACTION_UNKNOWN
  || call.object_type == TYPE_UNKNOWN;

// good - preferred: extract to named boolean for complex conditions
bool is_valid_address =
  address.type == ADDRESS_IPV4
  && address.port > 0
  && address.port < 65535;

if (is_valid_address)
  connect(&address);

// acceptable - multi-line if with single-statement body, no braces
if (
  address.type == ADDRESS_IPV4
  && address.port > 0
  && address.port < 65535
)
  connect(&address);

// good - multi-line for: same pattern as multi-line if
for (
  const transition_t* t = fsm->transitions;
  t->current_state != 0 || t->event != 0;
  t++
) {
  // ...
}

// good - all items at same indent level
int total =
  base_value
  + offset
  + adjustment;

// avoid - operator at end of line
bool is_bad_request =
  header_decode(buffer, index, &call) < 0 ||
  call.action == ACTION_UNKNOWN ||
  call.object_type == TYPE_UNKNOWN;

// avoid - conditions aligned to paren, first item on opening line
if (address.type == ADDRESS_IPV4 &&
    address.port > 0 &&
    address.port < 65535) {
  connect(&address);
}

// avoid - first item on the opening line
int total = base_value
  + offset
  + adjustment;
```

**Multi-line function calls inside `if` conditions.** When a function call inside an `if` condition has too many arguments to fit on one line, break the call across lines:

- One argument per line at body indent (one level from the `if`).
- The call's closing `)` and the `if` condition's closing `)` both on their own line together: `))` at body indent.
- The `if` body follows on the next line, per the usual single-statement-body convention.

Do not align continuation lines to the opening paren - this produces deep indentation that is fragile under renames and drifts across the column budget. Do not tuck the closing parens onto the last argument's line - visual separation of the closing parens from the final argument matters when the reader is scanning for where the condition ends.

```c
// good - one arg per line at body indent; both closing parens on their own line
if (sensor_matches_calibration(
  calibration,
  &reading.channel,
  reading.timestamp,
  reading.value,
  clock_get_timestamp()
))
  return;

// avoid - args aligned to the opening paren (deep indentation, fragile)
if (sensor_matches_calibration(
      calibration, &reading.channel,
      reading.timestamp, reading.value,
      clock_get_timestamp()))
  return;

// avoid - closing parens tucked onto the last argument's line
if (sensor_matches_calibration(
  calibration,
  &reading.channel,
  reading.timestamp,
  reading.value,
  clock_get_timestamp()))
  return;

// avoid - call's `)` stays inline but condition's `)` drops to its own line
if (sensor_matches_calibration(
  calibration,
  &reading.channel,
  reading.timestamp,
  reading.value,
  clock_get_timestamp())
)
  return;
```

**When to deviate**: Follow the existing style of a codebase.

---

### Vertical Separation

**Intent**: Use blank lines to mark transitions between roles in a function's flow, so the reader can see the structure at a glance. See `general/CLAUDE.md` § Vertical Separation Between Concepts for the cross-language principle.

**Convention**: Insert a blank line at each role transition - setup to main work, work to a decision, decision back to work, work to teardown, work to outcome. Statements that share a role stay together regardless of statement kind. Sequential decisions (each `if (cond) return;` guard) are sequential roles and each gets its own blank line above it. A multi-line expression is its own thought and gets a blank line before and after it; this is one of the role-transition cases, since a multi-line expression's cognitive weight forces it to read as its own step. Exception: a single-statement body of a control statement (`if (condition) return;`) is one decision and is not split.

```c
// good - blank lines mark role transitions
void process_reading(sensor_t* sensor)
{
  int result = 0;
  int32_t value = 0;

  result = sensor_read(sensor, &value);

  if (result < 0)
    return;

  publish(value);
}

// good - assignment cluster stays together; blank line before the decision
bool decode_one(const char* in, uint8_t* out)
{
  int high = hex_nibble(in[0]);
  int low = hex_nibble(in[1]);

  if (high < 0 || low < 0)
    return false;

  *out = (uint8_t) ((high << 4) | low);

  return true;
}

// good - sequential guards each separated; each is its own decision
int parse_header(const uint8_t* buf, size_t length)
{
  if (buf == NULL)
    return -1;

  if (length < HEADER_SIZE)
    return -2;

  return decode_header(buf);
}

// good - return at end of logical block separated from the preceding work
bool decode_pair(const char* in, size_t length, uint8_t* out, size_t* out_length)
{
  for (size_t i = 0; i < length; i += 2) {
    int high = hex_nibble(in[i]);
    int low = hex_nibble(in[i + 1]);

    if (high < 0 || low < 0)
      return false;

    out[i / 2] = (uint8_t) ((high << 4) | low);
  }

  *out_length = length / 2;

  return true;
}

// good - multi-line expression separated from one-liners on each side
bool higher_priority = candidate->priority > current->priority;

bool same_priority_earlier =
  candidate->priority == current->priority
  && candidate->sequence < current->sequence;

if (higher_priority || same_priority_earlier)
  best = (int) i;

// good - related action calls share the "main work" role and stay together
void emit_status(const sensor_t* sensor)
{
  log_reading(sensor->last_value);
  notify_subscribers(sensor);
  update_metrics(sensor);
}

// good - mixed-kind statements that share a role stay together; transitions
// between roles get a blank line
int run(const sensor_t* sensor)
{
  initialize(sensor);

  int value = get_current_value(sensor);
  set_value("sensor_value", value);
  notify_subscribers(sensor);

  cleanup(sensor);

  return STATUS_SUCCESS;
}

// good - role transition applies to any control-flow construct, not just `if`
void process_batch(const sensor_t* sensors, size_t count)
{
  size_t valid_count = count_valid(sensors, count);

  for (size_t i = 0; i < valid_count; i++)
    process(&sensors[i]);
}

// good - the closing `}` of a control structure does not act as separation;
// the return that follows is a different role and gets its own blank line
size_t count_valid(const sensor_t* sensors, size_t count)
{
  size_t valid = 0;

  for (size_t i = 0; i < count; i++) {
    if (sensors[i].status == SENSOR_OK)
      valid++;
  }

  return valid;
}

// avoid - assignments jammed against the decision
bool decode_one(const char* in, uint8_t* out)
{
  int high = hex_nibble(in[0]);
  int low = hex_nibble(in[1]);
  if (high < 0 || low < 0)
    return false;

  *out = (uint8_t) ((high << 4) | low);
  return true;
}

// avoid - return jammed against the preceding assignment
size_t sensor_frame_size(const sensor_frame_t* frame)
{
  size_t header = sizeof(frame->header);
  size_t body = frame->body_length;
  size_t total = header + body;
  return total;
}

// avoid - statements of a shared role split by unnecessary blank lines
void emit_status(const sensor_t* sensor)
{
  log_reading(sensor->last_value);

  notify_subscribers(sensor);

  update_metrics(sensor);
}

// avoid - comment placed between an assignment and a return does not
// satisfy the separation; comments belong above what they describe
int finalize(int raw)
{
  int adjusted = raw * SCALE + OFFSET;
  // SCALE and OFFSET come from the calibration block above
  return adjusted;
}
```

**When to deviate**: Follow the existing style of a codebase.

---

### Empty Loop Bodies

**Intent**: When a loop has an intentionally empty body, make it clear the empty body is deliberate.

**Convention**: Keep the semicolon on the same line as the loop statement. The `;` completes the statement like a period ends a sentence. Putting it on a separate line leaves the statement visually incomplete.

Empty loop bodies are uncommon in practice - other mechanisms (thread waits, yields, sleeps) usually handle the cases where they would appear.

```c
// good - semicolon on the same line
while (*str++ != '\0');

for (size_t i = 0; str[i] != '\0'; i++);

// avoid - semicolon on a separate line
while (*str++ != '\0')
  ;

for (size_t i = 0; str[i] != '\0'; i++)
  ;
```

**When to deviate**: Follow the existing style of a codebase.

---

### Trailing Commas

**Intent**: Clean diffs and easier reordering in multi-line collections.

**Convention**: The general guide's trailing comma rule applies in C with these specifics:

- **Array initializers**: trailing comma is valid - use it.
- **Struct initializers** (designated or positional): trailing comma is valid - use it.
- **Enum value lists**: trailing comma is valid in C99 and later - use it.
- **Function parameter lists**: trailing comma is **not** valid - do not use it.
- **Macro argument lists**: trailing comma is **not** valid - do not use it.

```c
// good - trailing commas in initializers and enums
typedef enum {
  APP_MODE_IDLE = 1,
  APP_MODE_ACTIVE = 2,
  APP_MODE_SLEEP = 3,
} app_mode_t;

int values[] = {
  10,
  20,
  30,
};

app_config_t config = {
  .timeout_ms = 5000,
  .retries = 3,
};

// good - no trailing comma in function parameters (not valid syntax)
int app_sensor_configure(
  app_sensor_config_t* config,
  uint16_t address,
  uint8_t interval
);
```

**When to deviate**: If the project targets a pre-C99 compiler, trailing commas in enums are not valid.

---

### Whitespace in Structs

**Intent**: Use blank lines to separate logically distinct groups within a struct, but avoid excessive whitespace in flat field lists.

**Convention**: A flat list of top-level fields does not need blank lines between them. Nested blocks (`union`, `struct`) are logically separate from the surrounding fields - separate them with a blank line.

```c
// good - flat fields stay together; nested block separated
typedef struct __attribute__((packed)) {
  app_address_family_t address_family;
  uint16_t port;

  union {
    uint8_t mac[6];
    uint8_t ipv4[4];
    uint8_t ipv6[16];
  };
} app_endpoint_t;

// avoid - unnecessary blank lines between flat fields
typedef struct {
  uint16_t address;

  sensor_protocol_t protocol;

  uint8_t flags;
} sensor_channel_binding_t;
```

**When to deviate**: When a struct has distinct logical groups of fields (e.g. configuration fields followed by state fields), a blank line between groups improves readability.

---

### Column Alignment

**Intent**: Vertical alignment makes related groups of constants and annotations scannable.

**Convention**: The general style guide deprecates vertical alignment of code symbols. In C, two exceptions apply. These exceptions remain current under `--rewrite` mode; they are not subject to the general guide's vertical-alignment deprecation.

The alignment-column rule for both exceptions: a tab stop is 2 spaces (column positions at multiples of 2 from the line start: column 0, 2, 4, 6, ...). Compute the longest name's last-character column in the group (including the `#define ` keyword for `#define` groups, or the field type and name for struct fields), then place the value (or comment) column at the soonest tab stop that leaves a minimum 2-space gap past it. This is a target, not a minimum - excess padding past the soonest fitting tab stop looks like a formatting error rather than intentional alignment.

1. **`#define` groups** - left-align values within related groups of constants, with all values starting at the same column. Apply the tab-stop rule above to choose the value column. Each group is its own alignment context - separate groups (e.g. max constants vs. sentinel values) do not share a column. A shared left-aligned column makes the values scannable regardless of their internal shape (numeric, hex, type cast, macro reference, string literal). A solo define (or a group of one) follows the same tab-stop rule against its own name - it does not stretch to match an adjacent group's wider column.

   **Signed numeric groups**: when a group contains any negative numeric value, pad positive values with a leading space so the most-significant digit aligns down the column. The minus sign sits one column left of the digit column. Without the leading-space padding, the `-` would occupy the digit column on negative lines and the most-significant digit of positive values would sit one column right of the digits on negative lines, breaking magnitude reading.
2. **Inline comments** - align inline comments across related lines. Unaligned comments become visual noise. This includes `///<` trailing docs on struct fields and enum values - all `///<` comments in a group must start at the same column, chosen by the tab-stop rule above.

CAUTION: After writing a struct or enum with `///<` comments, verify all comments in the group start at the same column. One field name longer than the others causes misalignment.

All other cases (struct fields, enum values, designated initializers, local variables, assignments, function params, static variables) default to unaligned. Alignment in these cases creates diff noise when lines are added or changed, contradicting the benefit of trailing commas.

```c
// good - values left-aligned at a shared column, group-local alignment
#define MAX_SENSORS       16
#define MAX_READINGS      128
#define MAX_BUFFER_SIZE   256
#define MAX_RETRY_COUNT   8

// good - separate group, its own alignment context
#define SENSOR_NONE   0
#define SENSOR_ANY    0

// good - non-numeric values follow the same rule
#define SENSOR_RESET_CMD    "RST\r\n"
#define SENSOR_PING_CMD     "PING\r\n"
#define SENSOR_VERSION_CMD  "VER?\r\n"

// good - signed group: positive values padded so digits align down the column
#define SENSOR_OFFSET_MIN   -128
#define SENSOR_OFFSET_ZERO   0
#define SENSOR_OFFSET_MAX    127

// avoid - signed group with sign in the alignment column (digits do not
// share a column - the `1` of `-128` is one column right of the `0` and `1`
// in the unsigned values, breaking magnitude reading)
#define SENSOR_OFFSET_MIN  -128
#define SENSOR_OFFSET_ZERO 0
#define SENSOR_OFFSET_MAX  127

// avoid - separate group forced to share the wider group's column
#define SENSOR_NONE                0
#define SENSOR_ANY                 0

// avoid - excess padding past the soonest fitting tab stop
#define MAX_SENSORS               16
#define MAX_READINGS              128
#define MAX_BUFFER_SIZE           256
#define MAX_RETRY_COUNT           8

// good - aligned inline comments
int result = read_sensor(&sensor, &value);  // returns 0 on success
int status = calibrate(&sensor);            // must be called after read

// avoid - completely unaligned values
#define SPEED_OFF 0
#define SPEED_LOW 1
#define SPEED_MEDIUM 2
#define SPEED_HIGH 3

// avoid - unaligned inline comments on related lines
int result = read_sensor(&sensor, &value); // returns 0 on success
int status = calibrate(&sensor); // must be called after read

// avoid - misaligned ///< on struct fields
typedef struct {
  int current_state; ///< Index into state_table[]; -1 if uninitialized.
  int event; ///< EVENT_NONE through EVENT_MAX-1.
  int next_state; ///< Index into state_table[]; -1 to remain in current state.
  action_callback_t action; ///< Optional; may be NULL.
} transition_t;

// good - all ///< comments start at the same column
typedef struct {
  int current_state;        ///< Index into state_table[]; -1 if uninitialized.
  int event;                ///< EVENT_NONE through EVENT_MAX-1.
  int next_state;           ///< Index into state_table[]; -1 to remain in current state.
  action_callback_t action; ///< Optional; may be NULL.
} transition_t;
```

**When to deviate**: If the existing codebase uses broader alignment (struct fields, assignments), match that convention for consistency.

---

## Types

### Enums

**Intent**: Enums make valid values self-documenting and compiler-checked, removing the need for comments listing valid values.

**Convention**: Use enums for groups of related integer constants - types, states, modes, error codes. Prefer enums over `#define` for these because enum values are visible in debuggers. Use `#define` for configuration constants (sizes, limits), non-integer values, and values the preprocessor needs (`#if`). Use plain (unpacked) enums for internal use. Start enum values at 1, not 0 - this reserves 0 as an implicit "uninitialized/invalid" sentinel. Zero-initialized memory (`memset`, `calloc`, static storage) will not accidentally match a valid enum value.

Enum values are opaque identifiers, not encodings of external meaning. An address family enum should use sequential values (1, 2), not IP version numbers (4, 6) - the enum identifies the family, it does not encode the protocol version.

Do not use the zero sentinel as a wildcard or "any" value - that defeats its purpose. Use a distinct value for wildcards.

```c
// good - starts at 1; sequential opaque identifiers
typedef enum {
  APP_ADDR_FAMILY_MAC = 1,
  APP_ADDR_FAMILY_IPV4 = 2,
  APP_ADDR_FAMILY_IPV6 = 3,
} app_address_family_t;

// good - field type is the enum; no comment needed to explain valid values
typedef struct {
  app_address_family_t address_family;
  uint16_t port;
} app_endpoint_config_t;

// avoid - starts at 0; uninitialized memory matches a valid value
typedef enum {
  APP_ADDR_FAMILY_MAC = 0,
  APP_ADDR_FAMILY_IPV4 = 1,
} app_address_family_t;

// avoid - enum values encode external meaning instead of being opaque IDs
typedef enum {
  APP_ADDR_FAMILY_IPV4 = 4,
  APP_ADDR_FAMILY_IPV6 = 6,
} app_address_family_t;
```

**When to deviate**: When interfacing with an external protocol or hardware register that defines specific numeric values, the enum must match those values regardless of this convention. Wire protocols, register maps, and standardized APIs dictate their own numbering.

---

### Struct Packing

**Intent**: Ensure consistent memory layout when structs cross process, IPC, or hardware boundaries.

**Convention**: Pack structs that cross IPC or application boundaries as raw bytes using `__attribute__((packed))` (or the equivalent for the compiler). Compiler padding behavior cannot be assumed identical on each end, even with the same compiler at different optimization levels or on different architectures.

Structs used only within a single application do not need packing.

```c
// good - packed struct for an over-the-wire sensor reading frame
typedef struct __attribute__((packed)) {
  uint8_t frame_type;
  uint16_t payload_length;
  uint8_t payload[128];
} sensor_frame_t;

// good - internal struct; no packing needed
typedef struct {
  uint16_t address;
  sensor_protocol_t protocol;
} sensor_channel_binding_t;
```

**When to deviate**: Some architectures penalize or fault on unaligned access. On those platforms, weigh the portability benefit of packing against the performance cost, and consider serialization as an alternative.

---

### Anonymous Unions

**Intent**: Reduce naming noise when union members are already self-describing.

**Convention**: Use anonymous unions (C11) when the union members are self-describing and a union name would add no meaning. This is common in discriminated unions where each member already carries its type in its name.

If the union members are not self-describing, name the union. The name acts like a namespace, describing the grouping so that the members make sense in context.

```c
// good - members are self-describing; a union name adds nothing
typedef struct __attribute__((packed)) {
  app_address_family_t address_family;

  union {
    uint8_t mac[6];
    uint8_t ipv4[4];
    uint8_t ipv6[16];
  };
} app_address_t;

// access: address.ipv4[0], address.mac[0]

// good - members are not self-describing; union name adds context
typedef struct {
  uint8_t type;

  union data {
    uint32_t raw;
    float calibrated;
  } data;
} app_measurement_t;

// access: measurement.data.raw, measurement.data.calibrated
```

**When to deviate**: If the project targets a pre-C11 compiler, anonymous unions are not available. Use a named union instead.

---

## File Organization

### Function Ordering in Source Files

**Intent**: After the initial code is written, the most likely reason someone re-reads a `.c` file is to understand how the public API works. The public functions should be up front and easy to find, not buried below internal helpers.

**Convention**: Static variables (constants, lookup tables, shared state) at the top of the file, then forward declarations of static functions, then public API functions, then static helper definitions. Variables are data the functions operate on - they should be visible before the functions that use them. When forward declarations mix single-line and multi-line signatures, separate them with a blank line - the multi-line declaration is a visually distinct block.

Do not put static helpers first to avoid forward declarations. Always use forward declarations and place public API functions before static helpers.

```c
// good - forward declarations, then public API, then helpers
static int find_entry(const store_t* store, const char* key);
static int validate_key(const char* key);

int store_set(store_t* store, const char* key, int value)
{
  if (0 > validate_key(key))
    return -1;

  // ...
}

static int find_entry(const store_t* store, const char* key)
{
  // ...
}

// avoid - static helpers before public functions
static int find_entry(const store_t* store, const char* key)
{
  // ...
}

int store_set(store_t* store, const char* key, int value)
{
  // ...
}
```

**When to deviate**: Follow the existing style of a codebase.

---

### Interface and Implementation

**Intent**: The header file is the API contract. Implementation details stay in the source file.

**Convention**: Public type definitions, constants, and function declarations go in the header file. Implementation, static functions, and file-scope state stay in the `.c` file. Doxygen docs go on the declarations in the header.

```c
// good - sensor.h: public interface only
#pragma once

#include <stdint.h>

typedef struct {
  uint8_t type;
  uint16_t address;
} sensor_config_t;

/** @brief Initializes the sensor with the given configuration. */
int sensor_init(const sensor_config_t* config);

/** @brief Reads the current value. */
int sensor_read(int32_t* value);

// good - sensor.c: implementation and internal details
#include <string.h>

#include "sensor.h"

static int32_t last_reading;
static bool initialized = false;

static int validate_config(const sensor_config_t* config)
{
  // ...
}

int sensor_init(const sensor_config_t* config)
{
  if (0 > validate_config(config))
    return -1;

  // ...
  initialized = true;

  return 0;
}

// avoid - implementation details in the header
static int32_t last_reading;  // internal state exposed in header

static int validate_config(const sensor_config_t* config)  // static function in header
{
  // ...
}
```

**When to deviate**: `static inline` functions in headers are acceptable when the function must be available across translation units and is short enough to benefit from inlining.

---

### Minimize Global State

**Intent**: Global data creates hidden dependencies, complicates testing, and introduces concurrency hazards.

**Convention**: Prefer passing state through function parameters over using file-scope or global variables.

```c
// good - state passed through parameters
int sensor_read(sensor_t* sensor, int32_t* value)
{
  int result = hardware_read(sensor->address, value);
  if (result < 0)
    return -1;

  *value += sensor->offset;

  return 0;
}

// avoid - hidden dependency on global state
static uint16_t sensor_address;
static int32_t calibration_offset;

int sensor_read(int32_t* value)
{
  int result = hardware_read(sensor_address, value);
  if (result < 0)
    return -1;

  *value += calibration_offset;

  return 0;
}
```

**When to deviate**: Some state is inherently global (hardware singletons, logging configuration). Use `static` file-scope variables for these and keep the number small.

---

### Variable Declaration Placement

**Intent**: Keep declarations close to their use to minimize the reader's mental tracking burden.

**Convention**: Declare variables at the point of first use. Exceptions that go at the top of the block:
- Variables that are overwritten throughout the block (accumulators, result codes, state) - their scope is the entire block.
- Variables extracted from a config struct or options argument - these act as extended function arguments and should be visible at the top, like destructuring options in a function preamble.

```c
// good - point-of-use: variable assigned once, used in narrow scope
void process(sensor_t* sensor)
{
  int result = sensor_read(sensor, &value);
  if (result < 0)
    return;

  int32_t calibrated = apply_offset(value, sensor->offset);
  publish(calibrated);
}

// good - block-top: variables overwritten throughout the function
int encode(char* buffer, size_t buffer_size, const char* body)
{
  size_t length = 0;
  uint8_t checksum = 0x00;

  length += write_header(buffer, body);
  checksum += compute_header_checksum(buffer, length);

  length += write_body(buffer + length, body);
  checksum += compute_body_checksum(buffer, length);

  buffer[length] = checksum;
  length++;

  return (int) length;
}

// avoid - all variables at block-top when they could be at point-of-use
void process(sensor_t* sensor)
{
  int result = 0;
  int32_t value = 0;
  int32_t calibrated = 0;

  result = sensor_read(sensor, &value);
  if (result < 0)
    return;

  calibrated = apply_offset(value, sensor->offset);
  publish(calibrated);
}
```

**When to deviate**: Follow the existing style of a codebase.

---

### Header Self-Containment

**Intent**: A header must work on its own. Consumers should not need to know which other headers to include first.

**Convention**: Every header file must compile correctly when included as the first and only header in a source file. Include all types the header depends on directly - do not rely on transitive inclusions from other headers. Conversely, a `.c` file should not re-include headers already provided by its own header - the header's self-containment guarantees they are available. However, a `.c` file must include any headers it uses directly that its own header does not provide (e.g. `<stdbool.h>` for `bool` in local variables when the header doesn't use `bool`).

```c
// good - sensor.h includes everything it needs
#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct {
  uint8_t type;
  uint16_t address;
  bool enabled;
} sensor_config_t;

// avoid - relies on caller to include <stdint.h> and <stdbool.h> first
#pragma once

typedef struct {
  uint8_t type;       // undefined unless caller includes <stdint.h>
  uint16_t address;
  bool enabled;       // undefined unless caller includes <stdbool.h>
} sensor_config_t;
```

**When to deviate**: None.

---

### Internal Linkage

**Intent**: Limit the visibility of functions and variables to the translation unit that owns them. Only symbols declared in the header should have external linkage.

**Convention**: Functions and file-scope variables not visible outside their translation unit must be declared `static`. Only functions declared in the corresponding `.h` file should have external linkage. When a `static` function is referenced before its definition, place a forward declaration at the top of the `.c` file.

```c
// good - static function, no namespace prefix needed
static int find_best(const sensor_queue_t* queue)
{
  // ...
}

// good - forward declarations at top of file
static void handle_timeout(timer_t* timer);
static void handle_response(address_t* source, uint8_t* data, uint16_t length);

// good - static file-scope variables
static uint16_t sensor_count;
static bool initialized = false;

// avoid - internal function without static (leaks into global namespace)
int find_best(const sensor_queue_t* queue)
{
  // ...
}

// avoid - file-scope variable without static, unless intentionally global.
// Global variables should be defined and used with care.
uint16_t sensor_count;
```

**When to deviate**: Variables that are intentionally shared across translation units (true globals) do not use `static`. Use sparingly.

---

### Conditional Compilation

**Intent**: Keep `.c` source files free of `#ifdef` chains so function bodies read as straight-line code.

**Convention**: Prefer no-op stubs in headers or build-system file selection over `#ifdef` conditionals scattered through `.c` function bodies. Source files call unconditionally; the compiler optimizes away stubs.

```c
// good - stub in header, no #ifdef in source
// debug.h
#ifdef CONFIG_DEBUG
void debug_log(const char* message);
#else
static inline void debug_log(const char* message) {}
#endif

// sensor.c - calls unconditionally
void sensor_read(sensor_t* sensor)
{
  int32_t value = hardware_read(sensor->address);
  debug_log("sensor read complete");
}

// good - build system selects the right .c file
// datalink_tcp.c implements datalink_send for TCP
// datalink_serial.c implements datalink_send for serial
// No #ifdef in either file.

// avoid - #ifdef chains repeated in every function body
int datalink_send(address_t* destination, uint8_t* data, uint16_t length)
{
#if defined(TRANSPORT_TCP)
  return tcp_send(destination, data, length);
#elif defined(TRANSPORT_SERIAL)
  return serial_send(destination, data, length);
#elif defined(TRANSPORT_ETHERNET)
  return ethernet_send(destination, data, length);
#else
  return -1;
#endif
}

// avoid - debug output gated at every call site
void sensor_read(sensor_t* sensor)
{
  int32_t value = hardware_read(sensor->address);
#ifdef CONFIG_DEBUG
  debug_log("sensor read complete");
#endif
}
```

**When to deviate**: Short, localized `#ifdef` blocks (e.g. a single platform-specific line) are acceptable when creating a header stub would be heavier than the conditional itself.

---

### `#endif` Comments

**Intent**: Comment `#endif` and `#else` directives when the corresponding `#ifdef` is far away or nested, so the reader can see what condition is being closed.

**Convention**: Comment `#endif` and `#else` when the block is long or nested. Omit comments for short, non-nested blocks - the comments add more visual noise than clarity when you can see the opening `#ifdef` from the closing `#endif`. Long blocks and nested `#ifdef`s make it easy to get lost in the chain, so the comments are worth the noise.

```c
// good - nested conditionals: comments clarify which #endif closes which #ifdef
#ifdef CONFIG_NETWORKING
#ifdef CONFIG_IPV6
void ipv6_init(void);
#endif /* CONFIG_IPV6 */
void network_init(void);
#endif /* CONFIG_NETWORKING */

// good - short block: no comment needed
#ifdef CONFIG_DEBUG
void debug_log(const char* message);
#endif

// good - header guard: always comment
#ifndef APP_SENSOR_H
#define APP_SENSOR_H
// ...
#endif /* APP_SENSOR_H */

// avoid - short block with unnecessary comments
#ifdef CONFIG_DEBUG
void debug_log(const char* message);
#else /* !CONFIG_DEBUG */
static inline void debug_log(const char* message) {}
#endif /* CONFIG_DEBUG */

// avoid - uncommented #endif on long or nested blocks
#ifdef CONFIG_DEBUG
void debug_log(const char* message);
// (40+ lines of declarations or code)
#else
static inline void debug_log(const char* message) {}
// (40+ lines of declarations or code)
#endif
```

**When to deviate**: Header guards should always have a closing comment regardless of file length.

---

## Functions

### Function Prototypes

**Intent**: Function declarations should be self-documenting. A reader should understand what each parameter means from the declaration alone.

**Convention**: Function declarations in headers must include parameter names, not just types. Use `(void)` explicitly for functions that take no parameters - empty `()` in C means "unspecified parameters," not "no parameters."

```c
// good - parameter names document the interface
int sensor_init(const sensor_config_t* config);
int sensor_read(sensor_t* sensor, int32_t* value);
void sensor_stop(void);
int sensor_count(void);

// avoid - parameter names omitted
int sensor_init(const sensor_config_t*);
int sensor_read(sensor_t*, int32_t*);

// avoid - empty () means "unspecified parameters" in C
void sensor_stop();
int sensor_count();
```

**When to deviate**: None.

---

### `inline`

**Intent**: Prevent unnecessary use of `inline` as an optimization decoration.

**Convention**: Do not use `inline` as an optimization hint. Modern compilers make their own inlining decisions regardless of the keyword. The only valid use is `static inline` in headers - to define a function body that must be available across translation units without causing duplicate symbol errors (e.g. conditional compilation stubs). Performance-motivated `inline` requires profiling evidence.

```c
// good - static inline stub in a header (mechanical requirement)
#ifndef CONFIG_DEBUG
static inline void debug_log(const char* message) {}
#endif

// avoid - inline as optimization decoration in a .c file
inline int sensor_read(sensor_t* sensor, int32_t* value)
{
  // ...
}

// avoid - inline on a static function in a .c file (compiler decides this)
static inline int validate_config(const sensor_config_t* config)
{
  // ...
}
```

**When to deviate**: When profiling shows that a specific function call is a bottleneck and inlining resolves it.

---

### Cleanup and Error Cleanup with `goto`

**Intent**: Cleanup must complete all of its work regardless of individual failures. `goto` centralizes error cleanup so every failure path releases the same resources.

**Convention**: Use `goto` for centralized error cleanup in functions that acquire multiple resources or hold locks. The label should be descriptive (`error:`, `cleanup:`). No backward jumps, no flow-control `goto`, and only within the same function - never across functions (`longjmp`/`setjmp`).

It is OK for a cleanup function to fail and return an error - but it must not short-circuit before finishing its cleanup. An early return on failure leaves resources leaked.

```c
// good - goto centralizes cleanup; mutex is always unlocked
int sensor_publish(sensor_t* sensor, const sensor_frame_t* frame)
{
  uint32_t total_bytes = htonl(frame->payload_length);
  size_t sent_bytes = 0;

  pthread_mutex_lock(&sensor->write_lock);

  int result = write(sensor->fd, &total_bytes, sizeof(total_bytes));
  if (result != 4)
    goto error;

  while (sent_bytes < frame->payload_length) {
    size_t sent = write(
      sensor->fd,
      frame->payload + sent_bytes,
      frame->payload_length - sent_bytes
    );

    if (sent < 0)
      goto error;

    sent_bytes += sent;
  }

  pthread_mutex_unlock(&sensor->write_lock);

  return 0;

error:
  pthread_mutex_unlock(&sensor->write_lock);

  return -1;
}

// good - cleanup function continues despite individual failures
int sensor_stop(sensor_t* sensor)
{
  if (!sensor)
    return -1;

  int result = 0;

  if (0 > hardware_close(sensor->handle)) {
    LOG_WARNING("failed to close sensor handle %d", sensor->handle);
    result = -1;
  }

  sensor->handle = -1;
  sensor->initialized = false;

  return result;
}

// avoid - early return in cleanup function skips remaining work
int sensor_stop(sensor_t* sensor)
{
  if (!sensor)
    return -1;

  int result = hardware_close(sensor->handle);
  if (result < 0)
    return -1;  // handle and initialized are never reset

  sensor->handle = -1;
  sensor->initialized = false;

  return 0;
}
```

**When to deviate**: Simple functions that acquire a single resource can use early return instead of `goto` - the cleanup is a single line and `goto` would add unnecessary structure.

---

### Pointer Parameters Over Array Notation

**Intent**: Make it explicit that a function parameter is a pointer, not a copy of an array.

**Convention**: In function parameter declarations, use pointer syntax rather than array syntax.

```c
// good - pointer form is explicit
int parse(const char* input, size_t length);
void process(uint8_t* buffer, size_t count);
int sum(const int* values, size_t count);

// avoid - array notation hides the fact that these are pointers
int parse(const char input[], size_t length);
void process(uint8_t buffer[], size_t count);
int sum(const int values[], size_t count);
```

**When to deviate**: None.

---

## Types

### Fixed-Width Integer Types

**Intent**: Use types that communicate the exact size of the data, especially for struct fields, protocol values, and hardware registers.

**Convention**: Use `<stdint.h>` types (`uint8_t`, `int32_t`, `uint16_t`, etc.) for data with known size requirements - struct fields, buffer sizes, protocol values, hardware registers. Use `int` for loop counters and return codes where exact width doesn't matter. Use `size_t` for array indices and memory sizes.

```c
// good - fixed-width types for data, int for return code, size_t for indices
typedef struct {
  uint8_t type;
  uint16_t address;
  uint32_t serial_number;
  int32_t calibration_offset;
} sensor_config_t;

int sensor_read(sensor_t* sensor, int32_t* value);

size_t buffer_available(const buffer_t* buffer);

for (size_t i = 0; i < buffer->length; i++)
  buffer->data[i] = 0;

// avoid - plain int/short/long for data with known size requirements
typedef struct {
  char type;
  short address;
  long serial_number;
  int calibration_offset;
} sensor_config_t;
```

**When to deviate**: When interfacing with a library or system API that uses `int`, `long`, or other platform types, match those types at the boundary.

---

### Boolean Type

**Intent**: Use a dedicated boolean type for boolean values, not `int`.

**Convention**: Use `bool`, `true`, and `false` from `<stdbool.h>`. Do not use `int` as a boolean type.

```c
// good
#include <stdbool.h>

bool sensor_enabled = true;
bool initialized = false;

bool is_valid(const sensor_t* sensor)
{
  return sensor->address > 0 && sensor->type > 0;
}

// avoid - int as boolean
int sensor_enabled = 1;
int initialized = 0;
```

**When to deviate**: When interfacing with APIs that use `int` for boolean values (e.g. POSIX).

---

### Designated Initializers

**Intent**: Struct initialization should be self-documenting and order-independent.

**Convention**: Use designated initializers (`.field = value`) for struct initialization. Use `= { 0 }` to zero-initialize structs and arrays at declaration - do not use `memset` when `= { 0 }` works. `memset` is correct for zeroing through a pointer or reinitializing a buffer mid-function; `= { 0 }` is for declarations. Positional initialization is a legacy pattern for any struct with more than one field.

```c
// good - designated initializers
sensor_config_t config = {
  .type = SENSOR_TEMP,
  .address = 0x0048,
  .interval_ms = 1000,
};

// good - zero-initialize
sensor_config_t config = { 0 };
uint8_t buffer[256] = { 0 };

// avoid - positional initialization; reader must know field order
sensor_config_t config = { SENSOR_TEMP, 0x0048, 1000 };

// avoid - memset on a local variable when = { 0 } works
sensor_config_t config;
memset(&config, 0, sizeof(config));

// avoid - memset on a local array when = { 0 } works
uint8_t buffer[256];
memset(buffer, 0, sizeof(buffer));

// good - memset is correct for zeroing through a pointer (= { 0 } is for declarations only)
void sensor_init(sensor_config_t* config)
{
  memset(config, 0, sizeof(*config));
}
```

**When to deviate**: Positional initialization is acceptable for simple, well-known types with one or two fields (e.g. `point_t p = { 0, 0 }`).

---

### Initialize at Declaration

**Intent**: Prevent undefined behavior from uninitialized variables.

**Convention**: Initialize local variables at the point of declaration. Local variables in C have indeterminate (not zero) initial values - using them before assignment is undefined behavior.

```c
// good - initialized to zero or the value it needs
int result = 0;
int32_t value = 0;
uint8_t buffer[256] = { 0 };

// good - initialized with the value it needs
int result = sensor_read(&sensor, &value);
size_t length = strlen(body);

// avoid - uninitialized declaration
int result;
int32_t value;
result = sensor_read(&sensor, &value);
```

**When to deviate**: None.

---

### `const` Correctness

**Intent**: `const` communicates intent - it tells the reader which data is an input (read-only) and which is an output (mutated). It also prevents accidental modification of read-only data.

**Convention**: Mark pointer parameters `const` when the function does not modify the pointed-to data. `const` signals that a parameter is an input; absence of `const` signals it is an output or is mutated. This is the primary way to communicate input vs output parameters - not ordering. Use `static const` on file-scope arrays that are read-only lookup tables.

```c
// good - const signals which params are inputs, which are outputs
int sensor_read(const sensor_config_t* config, int32_t* value);
int encode(const char* body, uint8_t* output, size_t output_size);
size_t buffer_available(const buffer_t* buffer);

// good - static const on read-only file-scope arrays
static const int properties_required[] = {
  PROP_IDENTIFIER,
  PROP_NAME,
  PROP_TYPE,
};

// const pointer forms - `*const` stays together as a unit ("constant pointer")
const uint8_t* ptr;        // pointer to const data (can't modify data)
uint8_t *const ptr;        // const pointer to mutable data (can't redirect pointer)
const uint8_t *const ptr;  // const pointer to const data (can't do either)

// avoid - missing const on input parameters
int sensor_read(sensor_config_t* config, int32_t* value);
size_t buffer_available(buffer_t* buffer);
```

Note: the `*` shifts to the variable side when followed by `const` because `*const` is a single concept - "constant pointer." This is the only exception to the `type*` pointer style convention.

**When to deviate**: When interfacing with APIs that don't use `const` (legacy C code), match their signatures at the boundary.

---

### Typedef Structs

**Intent**: Structs should behave like first-class types. `sensor_config_t config;` reads cleaner and more concisely than `struct sensor_config config;`.

**Convention**: Always typedef structs. Use `typedef struct { ... } name_t;` as the standard pattern. This applies to all structs - public and internal. A typedef in a `.c` file has the same visibility as a `static` function and cannot leak into other files.

```c
// good - public API type
typedef struct {
  uint8_t type;
  uint16_t address;
  int32_t offset;
} sensor_config_t;

// good - opaque type with forward-declared tag
typedef struct sensor_t sensor_t;

// good - internal type in a .c file
typedef struct {
  int32_t last_reading;
  uint32_t read_count;
} sensor_internal_t;

// good - self-referential struct (linked list)
typedef struct node {
  int value;
  struct node* next;
} node_t;

// avoid - bare struct
struct sensor_config {
  uint8_t type;
  uint16_t address;
  int32_t offset;
};
```

**When to deviate**: When interfacing with a codebase that uses bare structs, match that convention at the boundary.

---

### Floating-Point Type

**Intent**: Use the type with adequate precision by default.

**Convention**: Use `double` as the default floating-point type. `float` has ~6 digits of precision vs ~15 for `double`, and all `math.h` functions operate on `double`. Use `float` only when required by hardware interfaces or protocols.

```c
// good - double for general computation
double temperature = raw_value / 16.0;
double average = sum / (double) count;

// good - float when hardware requires it
float sensor_value = (float) raw_register / 16;

// avoid - float for general computation
float temperature = raw_value / 16.0f;
float average = sum / (float) count;
```

**When to deviate**: When a hardware interface, protocol, or library API requires `float`.

---

### Avoid Variable-Length Arrays

**Intent**: Prevent silent stack overflows from runtime-sized stack allocations.

**Convention**: Do not use variable-length arrays. They allocate on the stack with no overflow checking - a large value silently causes a stack overflow. Use fixed-size arrays or `malloc`. C11 made VLAs optional, so they are also a portability concern.

```c
// good - fixed-size array when the maximum is known
uint8_t buffer[MAX_PACKET_SIZE];

// good - malloc when size is dynamic
uint8_t* buffer = malloc(packet_length);
if (!buffer)
  return -1;

// ... use buffer ...

free(buffer);

// avoid - VLA: stack overflow if packet_length is large
void process_packet(size_t packet_length)
{
  uint8_t buffer[packet_length];  // size determined at runtime
  // ...
}
```

**When to deviate**: None.

---

## Idioms

### `sizeof` on Variables

**Intent**: Keep `sizeof` in sync with the variable's actual type, even if the type changes later.

**Convention**: Prefer `sizeof(variable)` or `sizeof(*pointer)` over `sizeof(type)` when a variable is in scope. The variable-based form stays correct if the type changes; the type-based form silently diverges. Use `sizeof(*pointer)` for allocation and `sizeof(variable)` for memset/memcpy - do not use `sizeof(type)` when the variable is available.

```c
// good - sizeof tracks the variable's type
sensor_config_t config = { 0 };
memset(&config, 0, sizeof(config));

sensor_t* sensor = calloc(1, sizeof(*sensor));

uint8_t buffer[256] = { 0 };
memcpy(buffer, source, sizeof(buffer));

// avoid - sizeof(type) can drift from the variable's actual type
sensor_config_t config = { 0 };
memset(&config, 0, sizeof(sensor_config_t));

sensor_t* sensor = calloc(1, sizeof(sensor_t));
```

**When to deviate**: When no variable is in scope yet (e.g. computing sizes for a protocol spec before allocation).

---

### Do Not Cast `void*`

**Intent**: Avoid unnecessary casts that add noise and can mask errors.

**Convention**: Do not cast the return value of `malloc`, `calloc`, `realloc`, or any function returning `void*`. In C, `void*` converts to any pointer type implicitly. The cast is unnecessary and can hide a missing `#include <stdlib.h>`.

```c
// good
sensor_t* sensor = calloc(1, sizeof(*sensor));
uint8_t* buffer = malloc(packet_length);
uint8_t* expanded = realloc(buffer, new_size);

// avoid - unnecessary cast
sensor_t* sensor = (sensor_t*) calloc(1, sizeof(*sensor));
uint8_t* buffer = (uint8_t*) malloc(packet_length);
```

**When to deviate**: When writing code that must compile as both C and C++ (C++ requires the cast).

---

### Error Return Conventions

**Intent**: Return values should be unambiguous - the caller should know what success and failure look like from the function's name and return type.

**Convention**: Three return conventions based on function type:
- **Action functions** (imperatives: `init`, `read`, `send`) return `0` on success, non-zero on failure.
- **Predicate functions** (questions: `is_valid`, `has_pending`) return `bool` (`true`/`false`).
- **Pointer-returning functions** return `NULL` on failure.

When a function can fail in more than one way, use clearly named error definitions (enum or `#define`) so the caller can distinguish failure modes without magic numbers.

When capturing an action function's return value for error checking, name the variable `error` rather than `result`. `error` communicates intent - the reader immediately understands that zero means no error and `if (error)` reads as a natural error check. Use `result` when the return value represents different outcomes beyond just error/success (e.g. a function that returns different types of success).

```c
// good - variable named `error` makes the check self-documenting
int error = sensor_init(&config);
if (error)
  return error;

// avoid - `result` is ambiguous
int result = sensor_init(&config);
if (result < 0)
  return result;

// good - single failure mode: -1 is sufficient
int sensor_init(const sensor_config_t* config)
{
  if (!config)
    return -1;

  // ...

  return 0;
}

// good - multiple failure modes: named error codes
typedef enum {
  PORT_OK = 0,
  PORT_ERROR_INVALID = -1,
  PORT_ERROR_BUSY = -2,
  PORT_ERROR_TIMEOUT = -3,
} port_result_t;

port_result_t port_open(const port_config_t* config)
{
  if (!config)
    return PORT_ERROR_INVALID;

  if (is_in_use(config->address))
    return PORT_ERROR_BUSY;

  // ...

  return PORT_OK;
}

// good - predicate function: bool return
bool sensor_is_valid(const sensor_t* sensor)
{
  return sensor->address > 0 && sensor->type > 0;
}

// good - pointer-returning: NULL on failure
sensor_t* sensor_create(uint16_t address)
{
  sensor_t* sensor = calloc(1, sizeof(*sensor));
  if (!sensor)
    return NULL;

  sensor->address = address;

  return sensor;
}

// avoid - action function returning 1 for success (ambiguous)
int sensor_init(const sensor_config_t* config)
{
  // ...
  return 1;  // success? or true? or count?
}

// avoid - predicate returning int instead of bool
int sensor_is_valid(const sensor_t* sensor)
{
  return sensor->address > 0;
}
```

**When to deviate**: When interfacing with APIs that use different conventions (e.g. POSIX `read`/`write` return byte counts, not 0/-1).

---

### Diagnostics to `stderr`

**Intent**: Keep program output and error messages on separate streams so they can be piped and redirected independently.

**Convention**: Write error and diagnostic messages to `stderr`, not `stdout`. When the project uses logging macros, the macros handle this. When writing directly, use `fprintf(stderr, ...)`.

```c
// good - logging macros handle stderr internally
LOG_ERROR("failed to read sensor %d", sensor_id);

// good - direct fprintf to stderr
fprintf(stderr, "failed to open %s: %s\n", path, strerror(errno));

// avoid - error messages to stdout
printf("Error: failed to read sensor %d\n", sensor_id);
```

**When to deviate**: None.

---

### Check Return Values

**Intent**: Unchecked failures lead to NULL pointer dereference or silent data loss.

**Convention**: Check return values from functions that can fail - especially `malloc`, `calloc`, `realloc`, `fopen`, `fread`, `fwrite`.

```c
// good - check every fallible return
uint8_t* buffer = malloc(packet_length);
if (!buffer)
  return -1;

FILE* file = fopen(path, "r");
if (!file)
  return -1;

// good - realloc: check before overwriting the original pointer
uint8_t* expanded = realloc(buffer, new_size);
if (!expanded) {
  free(buffer);
  return -1;
}

buffer = expanded;

// good - blank line before a non-trivial condition block
uint8_t* buffer = malloc(size);

if (!buffer) {
  log_error("allocation failed for %zu bytes", size);
  cleanup_partial_state(&context);
  return -1;
}

// good - no blank line for a simple guard clause (single thought)
uint8_t* buffer = malloc(size);
if (!buffer)
  return -1;

// avoid - unchecked malloc
uint8_t* buffer = malloc(packet_length);
memcpy(buffer, source, packet_length);  // NULL dereference if malloc failed
```

**When to deviate**: None.

---

### `static inline` Over Function-Like Macros

**Intent**: Replace function-like macros with type-safe, debuggable alternatives.

**Convention**: Prefer `static inline` functions over function-like macros. `static inline` provides type safety, avoids double-evaluation, and is debuggable. Reserve macros for cases where functions can't work: stringification, token-pasting, `__VA_ARGS__`, `_Generic`, and conditional compilation stubs.

This rule is about replacing macros, not about optimization. See the `inline` rule for guidance on not using `inline` as a general optimization hint.

```c
// good - static inline: type-safe, no double-evaluation
static inline int max(int a, int b)
{
  return a > b ? a : b;
}

// good - macro is appropriate: __VA_ARGS__ can't be done with a function
#define LOG_ERROR(format, ...) fprintf(stderr, "ERROR: " format "\n", ##__VA_ARGS__)

// good - macro is appropriate: stringification
#define STRINGIFY(x) #x

// avoid - function-like macro: double-evaluation, no type checking
#define MAX(a, b) ((a) > (b) ? (a) : (b))

// MAX(i++, j++) increments twice - silent bug
int result = MAX(i++, j++);
```

**When to deviate**: When the macro must work across multiple types without `_Generic` (e.g. a type-generic `MIN`/`MAX` in a pre-C11 codebase).

---

### Macro Line Continuation

**Intent**: Multi-line macros should produce clean diffs when lines are added or changed.

**Convention**: Do not align `\` continuation characters to a column. Place each `\` immediately after the line content with a single space. Aligning backslashes to a column creates diff noise when any line changes length, requiring all other backslashes to be re-aligned.

```c
// good - unaligned backslashes
#define SENSOR_PARAMS(...) ((sensor_params_t){ \
  .type = SENSOR_TEMP, \
  .address = 0x0048, \
  .offset = 0, \
  __VA_ARGS__ \
})

// avoid - column-aligned backslashes (diff noise when lines change)
#define SENSOR_PARAMS(...) ((sensor_params_t){  \
  .type = SENSOR_TEMP,                          \
  .address = 0x0048,                            \
  .offset = 0,                                  \
  __VA_ARGS__                                   \
})
```

**When to deviate**: When the existing codebase uses column-aligned backslashes, match the local convention.

---

### Named Boolean Expressions

**Intent**: Complex boolean conditions should be extracted to named variables so the `if` statement reads as a simple question. See the general guide's Named Boolean Expressions rule.

**Convention**: When an `if` condition has multiple comparisons joined by `&&` or `||`, extract to a `bool` variable with a descriptive name. Do not embed complex conditions directly in `if` statements.

```c
// good - named boolean
bool is_valid_reading =
  sensor->status == STATUS_OK
  && sensor->value >= RANGE_MIN
  && sensor->value <= RANGE_MAX;

if (is_valid_reading)
  publish(sensor->value);

// avoid - complex condition inline with braces on single statement
if (
  sensor->status == STATUS_OK
  && sensor->value >= RANGE_MIN
  && sensor->value <= RANGE_MAX
) {
  publish(sensor->value);
}

```

**When to deviate**: Simple two-part conditions (`if (!ptr || count == 0)`) are clear enough inline.

---

### No Assignment in Conditions

**Intent**: Separate the action from the check. One thought per line.

**Convention**: Do not assign inside a condition. Assignment in conditions is difficult to read because the reader must distinguish what is being compared from what is being assigned.

```c
// good - assign first, then check
uint8_t* buffer = malloc(size);
if (!buffer)
  return -1;

int c = getchar();

while (c != EOF) {
  process(c);
  c = getchar();
}

// avoid - assignment inside condition
if ((buffer = malloc(size)) == NULL)
  return -1;

while ((c = getchar()) != EOF)
  process(c);
```

**When to deviate**: Follow the existing style of a codebase.

---

### Bounded String Functions

**Intent**: Prevent buffer overflows from unbounded string writes.

**Convention**: Prefer bounded string functions over their unbounded counterparts.

```c
// good - bounded
char buffer[256] = { 0 };
snprintf(buffer, sizeof(buffer), "sensor %d: %s", id, name);

strncpy(destination, source, sizeof(destination) - 1);
destination[sizeof(destination) - 1] = '\0';

// avoid - unbounded
sprintf(buffer, "sensor %d: %s", id, name);
strcpy(buffer, source);
```

**When to deviate**: When the source string is known at compile time and fits within the buffer (e.g. static error messages).

---

### Ternary Operator

**Intent**: Use ternary for simple value selection, not for control flow.

**Convention**: Use the ternary operator for simple value selection in assignments and return statements. Parenthesize the condition to prevent precedence bugs and add clarity. Simple ternaries stay on one line. Nested ternaries are acceptable when formatted with each `?` and `:` on its own line, indented to show the nesting structure. Do not use ternary for side effects or complex logic.

```c
// good - simple value selection
int max = (a > b) ? a : b;
const char* label = (enabled) ? "on" : "off";
return (count > 0) ? count : -1;

// good - nested ternary with structured formatting
const char* label =
  (value > 100)
  ? "high"
  : (value > 50)
    ? "medium"
    : "low";

// avoid - ternary for side effects
connected ? send(data) : log_error("not connected");

// avoid - complex logic in ternary
int result = (a > b && c != 0) ? compute(a, b) : fallback(c);
```

**When to deviate**: Follow the existing style of a codebase.

---

### Unused Parameter Suppression

**Intent**: Make intentionally unused parameters visible and deliberate.

**Convention**: Place `(void) parameter;` at the top of the function body, before any executable code. It is metadata about the parameter - a deliberate declaration that it is intentionally unused. Buried in the middle of the function, it looks like an accidental leftover.

```c
// good - at the top, reads as a conscious decision
static uint16_t checksum(
  const uint8_t* header,
  uint16_t header_length,
  const uint8_t* payload,
  uint16_t payload_length
) {
  (void) header_length;

  uint8_t pseudo[12];
  // ...
}

// avoid - buried in the middle of the function
static uint16_t checksum(
  const uint8_t* header,
  uint16_t header_length,
  const uint8_t* payload,
  uint16_t payload_length
) {
  uint8_t pseudo[12];
  // ... 10 lines of setup ...
  (void) header_length;
  // ...
}
```

**When to deviate**: None.

---

### Evaluation Order

**Intent**: Prevent undefined behavior from expressions that depend on evaluation order.

**Convention**: Do not write expressions where the result depends on evaluation order of subexpressions. Function argument evaluation order is unspecified in C.

```c
// good - separate statements with clear ordering
a[i] = value;
i++;

// avoid - undefined: i is read and modified in the same expression
a[i] = i++;

// avoid - undefined: i is modified twice
f(i++, i++);
```

**When to deviate**: None.

---

### Don't Reuse Variables for Different Purposes

**Intent**: A variable name should mean one thing throughout its scope.

**Convention**: Declare separate variables for each distinct purpose. Reusing a variable for the same purpose (e.g. sequential return code checks) is fine. Reusing it for a different meaning is not.

```c
// good - separate variables for distinct purposes
int read_result = sensor_read(&sensor, &value);
if (read_result < 0)
  return -1;

int write_result = log_write(&logger, value);
if (write_result < 0)
  return -1;

// good - same variable reused for the same purpose
int result_code = read_header(buffer, &header);
if (result_code != 0)
  return result_code;

result_code = read_body(buffer, &body);
if (result_code != 0)
  return result_code;

// avoid - `count` changes meaning mid-function
int count = sensor_count();
for (int i = 0; i < count; i++)
  read_sensor(i, &values[i]);

count = 0;  // now count is an accumulator, not a sensor count
for (int i = 0; i < MAX_SENSORS; i++)
  if (values[i] > threshold)
    count++;
```

**When to deviate**: None.

---

### Don't Shadow Outer-Scope Variables

**Intent**: Shadowing makes it unclear which variable is being referenced and is a common source of bugs.

**Convention**: Do not declare inner-scope variables with the same name as outer-scope variables.

```c
// good - distinct names
int length = strlen(name);

for (int i = 0; i < count; i++) {
  int name_length = strlen(items[i].name);
  if (name_length > length)
    truncate_name(&items[i], length);
}

// avoid - inner `length` shadows outer; compares to itself (always false)
int length = strlen(name);

for (int i = 0; i < count; i++) {
  int length = strlen(items[i].name);  // shadows outer length
  if (length > length)                 // bug: compares to itself
    truncate_name(&items[i], length);
}
```

**When to deviate**: None.

---

### Switch Completeness

**Intent**: Prevent silent fallthrough when new values are added to an enum or when unexpected values are passed.

**Convention**: Always include a `default` case in switch statements, even if all current enum values are handled. Comment intentional fall-throughs with `// fallthrough` or use C17's `[[fallthrough]]` attribute. Without a `default`, an unhandled value silently does nothing - no crash, no warning, just skipped logic.

```c
// good - default handles unexpected values
switch (sensor->type) {
  case SENSOR_TYPE_TEMP:
    read_temperature(sensor);
    break;

  case SENSOR_TYPE_HUMIDITY:
    read_humidity(sensor);
    break;

  default:
    LOG_WARNING("unknown sensor type %d", sensor->type);
    break;
}

// good - intentional fallthrough commented
switch (priority) {
  case PRIORITY_CRITICAL:
    notify_admin();
    // fallthrough

  case PRIORITY_HIGH:
    escalate();
    break;

  case PRIORITY_NORMAL:
    process();
    break;

  default:
    break;
}

// avoid - missing default
switch (sensor->type) {
  case SENSOR_TYPE_TEMP:
    read_temperature(sensor);
    break;

  case SENSOR_TYPE_HUMIDITY:
    read_humidity(sensor);
    break;
}

// avoid - unmarked fallthrough
switch (priority) {
  case PRIORITY_CRITICAL:
    notify_admin();

  case PRIORITY_HIGH:  // intentional? or missing break?
    escalate();
    break;
}
```

**When to deviate**: None.

---

### Literal-First Comparisons in `if`

**Intent**: When testing the return value of a function call in an `if`, placing the literal first makes the comparison value clearly visible. The literal can get lost at the end of a long function call.

**Convention**: When an `if` statement tests the return value of a function call directly, place the literal on the left side. Do not place the literal at the end of a function call comparison - it gets lost. Alternatively, capture the return value in a variable first and compare on the next line. When captured to a variable, use the natural comparison order (`result < 0`), not literal-first (`0 > result`) - the variable name already provides readability.

```c
// good - literal first
if (0 > sensor_read(sensor, &value))
  return -1;

if (0 > pipe(pipe_fds))
  goto error;

if (0 > close(fd))
  result = -1;

// good - capture then compare
int result = sensor_read(sensor, &value);
if (result < 0)
  return -1;

// avoid - literal at the end is easy to miss after a long function call
if (sensor_read(sensor, &value) < 0)
  return -1;

if (pipe(pipe_fds) < 0)
  goto error;

if (close(fd) < 0)
  result = -1;
```

**When to deviate**: For short function calls where the comparison is obvious, either style is acceptable.

---

### Implicit Boolean Conversion

**Intent**: Idiomatic null and zero checks that extend cleanly to C++.

**Convention**: Use implicit boolean conversion (`!ptr`, `!count`) for null checks and zero checks. This is idiomatic C and extends cleanly to C++ where implicit boolean conversion is a language feature (smart pointers, optional types). Explicit comparison (`ptr == NULL`, `count == 0`) is acceptable but not required.

```c
// good
if (!buffer)
  return -1;

if (!port || !config)
  return -1;

sensor_t* sensor = calloc(1, sizeof(*sensor));
if (!sensor)
  return -1;

// acceptable
if (buffer == NULL)
  return -1;
```

**When to deviate**: Follow the existing style of a codebase.

---

### Sentinel-Terminated Arrays

**Intent**: Allow iteration over arrays without passing a separate count.

**Convention**: Arrays that serve as lookup tables or field lists use a zero/NULL sentinel as the last element to mark the end of the list. The iterator checks for the sentinel to stop.

```c
// good - NULL sentinel terminates the list
static const field_def_t fields[] = {
  { "name", FIELD_TYPE_STRING, offsetof(config_t, name) },
  { "address", FIELD_TYPE_UINT16, offsetof(config_t, address) },
  { "timeout", FIELD_TYPE_UINT32, offsetof(config_t, timeout) },
  { NULL },
};

// iterate until sentinel
for (int i = 0; fields[i].name != NULL; i++)
  decode_field(buffer, index, &fields[i]);
```

**When to deviate**: When the array size is known at compile time and a count is more natural (e.g. fixed-size buffers).

---

### Application Assertions

**Intent**: Assertions in application code (init-time contract checks, framework assertion macros like `assert`, Zephyr `__ASSERT`, or vendor-provided assertion macros) behave like tests - they verify a contract and abort on failure. The formatting rules that make test assertions readable apply equally when assertions appear outside test files.

**Convention**: Follow the test-assertion formatting rules from `c/testing.md`:

- Separate declarations from assertions. Declare variables first; assert after.
- Assertions stand as their own visual block. Group related assertions; separate groups with a blank line.
- Do not inline a variable declaration inside an assertion call.
- Multi-line assertions use the same split formatting as test assertions: the function call goes inside, the assertion label stays outside.

**Example**:

```c
// good - declarations separated from assertions
sensor_t* sensor = sensor_create();
calibration_t calibration = {0};

ASSERT_OK(
  sensor_init(sensor, &calibration),
  "sensor init"
);

// good - related declarations grouped, assertions grouped
sensor_channel_t* primary_high, *primary_low;
sensor_channel_t* backup_high, *backup_low;

ASSERT_OK(
  sensor_channel_enable(&primary_high),
  "primary high"
);

ASSERT_OK(
  sensor_channel_enable(&primary_low),
  "primary low"
);

// good - short assertion on one line when the variable is declared immediately above
sensor_t* sensor = sensor_create();
ASSERT_OK(sensor_start(sensor), "sensor start");

// avoid - declaration buried inside assertion
ASSERT_OK(
  sensor_channel_enable(&channel), "enable"
);
```

**When to deviate**: The "inline when it fits" exception from the test guide applies - a short assertion whose variable is declared on the line immediately above may stay on one line.

**Cross-reference**: see `c/testing.md` "Test Variable Placement" and "Inline Assertions" for the canonical forms. This section extends those rules to non-test code.

---

## Testing

Testing rules are defined in `c/testing.md`. Load that file when writing or reviewing C tests.

---

## First-Run Project Checks

### Indentation Detection

On first review of a C project, check the existing indentation convention (2-space, 4-space, tab) by sampling a few source files. Save the result to memory. Apply the detected convention for the duration of the session - do not flag indentation that matches the project's established style.

### Build System Detection

Check for common C build systems: CMake (`CMakeLists.txt`), Make (`Makefile`), Meson (`meson.build`), or framework-specific build files (e.g. Zephyr's `prj.conf`). Save the result to memory - this informs how the project is built and what compiler flags may be in effect.

### Test Framework Detection

Check for test framework indicators: Unity (`unity.h` includes, `test/` directory with `test_*.c` files, Ceedling `project.yml`), Google Test (`gtest/gtest.h` includes, `*_test.cc` files, `CMakeLists.txt` with `GTest`). Save the result to memory - this determines which testing conventions from `c/testing.md` apply.
