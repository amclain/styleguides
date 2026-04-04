# C Style Guide

This file defines style conventions for C code. It is used by Claude Code to apply and review style.

The overarching philosophy is defined in the repository's top-level `CLAUDE.md`: these are recommendations, not mandates, and precedence in the codebase takes priority over this guide.

To suppress a suggestion for a specific block, add `// style:ok - reason`.

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

**Convention**: Use `snake_case` for all identifiers - functions, variables, types, and constants. Type names use a `_t` suffix. Enum values use the component prefix in uppercase. Avoid abbreviations in the body of the name - only the namespace prefix and idiomatic C suffixes (`_t`) are abbreviated.

Good C names will be longer than equivalent names in languages with modules or namespaces. This is expected - the global namespace requires each name to carry its full context.

AI NOTE: Agents use `UPPER_CASE` for `static const` arrays. Only `#define` constants and enum values use `UPPER_CASE`. `static const` arrays are variables and use `snake_case`.

AI NOTE: Agents frequently abbreviate common words in variable and constant names. Do not abbreviate `buffer` to `buf`, `length` to `len`, or `message` to `msg`. Write the full word. Use `size` as a concise alternative to `length` where appropriate (e.g. `buffer_size` instead of `buffer_length`). Accepted short forms: `ptr` (pointer), `fd` (file descriptor), `cb` (callback) - these are domain terms, not abbreviations.

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
  uint16_t port;
  app_protocol_t protocol;
} app_port_rule_t;
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

AI NOTE: Agents put the module's own header first (a C++ convention). In C, standard library headers always come first. When a file has no standard library includes, the local header can appear first with no blank line needed. External libraries (like Unity's `"unity.h"`) are group 2, not group 3 - separate them from local project headers with a blank line.

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

**When to deviate**: Long string literals (see String Literals rule below), include paths, or URLs that cannot be meaningfully broken. Use `// style:ok` for these.

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

Only split function signatures to multiple lines when the single-line version exceeds 80 characters. When splitting, keep the return type on the same line as the function name and split the arguments to multiple lines. Do not split the return type to its own line - always split on arguments instead. `) {` go together on the closing line - **never** `) \n{`. This is a common mistake. The closing paren and opening brace must be on the same line: `) {`. The `) {` serves the same role as `\n{` on a single-line signature - a uniform visual separator between function args and body. Putting `{` on yet another line adds too much visual gap.

AI NOTE: Agents consistently produce `)\n{` for multi-line function signatures. Always write `) {` on the closing parameter line, not `)` followed by `{` on the next line. Check your output after writing multi-line signatures.

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

// avoid - return type on separate line; always split on arguments instead
sensor_result_t
sensor_init(sensor_t* sensor)
{
  // ...
}

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

Casts follow the same principle - the `*` stays with the type inside the parens. A space separates the cast from the expression, just like a space separates a type from a variable name in a declaration.

AI NOTE: Agents consistently omit the space after casts. Always write `(type) expression` with a space, not `(type)expression`.

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
- `//` for inline/explanatory comments in code
- `/* GUARD */` for header guard closing comments (when not using `#pragma once`)

Doxygen uses `@` prefix for tags (`@brief`, `@param`, `@return`), not `\`. Use `///<` for trailing inline docs on struct fields, enum values, and `#define` constants. Align `@param` descriptions within their group. `@return` gets its own block separated by a blank line from the `@param` block.

Do not use section divider comments (`// --- Public API ---`, `// --- Static helpers ---`, etc.). The code structure is defined by function ordering and `static` visibility, not decoration. See the general guide's Write Self-Documenting Code rule.

AI NOTE: Agents produce section divider comments in all file types - `.c`, `.h`, and test files. Common patterns: `// -- Public API ---`, `// -- Forward declarations ---`, `// -- Helpers ---`, `// -- Tests ---`. Do not generate any of these - code structure is defined by function ordering and `static` visibility.

`/** */` is preferred over `///` for C - `///` silently breaks if one line is missing the prefix. `/** */` is also the format universally parsed by IDEs (VS Code, CLion, clangd) and compatible with all major doc generation paths (Doxygen, Sphinx via Breathe, clang-doc).

All public functions require a Doxygen docstring on the declaration in the header file - not on the implementation in the `.c` file. Header docs ride along with the SDK; source file docs get lost or compiled out. Static (file-internal) functions do not require a docstring, but may have one if the function is complex.

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

// good - trailing doc on struct fields
typedef struct {
  uint8_t type;       ///< Sensor type identifier
  uint16_t address;   ///< Hardware register address
  int32_t offset;     ///< Calibration offset in millivolts
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
```

**When to deviate**: Follow the existing style of a codebase. If the project uses `///` for docs, match that.

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

**When to deviate**: Follow the existing style of a codebase.

---

### Blank Line After Declarations

**Intent**: Visually separate variable declarations from the executable code that follows.

**Convention**: Separate block-top declarations from executable statements with a blank line. A group of one-line declarations can be written together, but a multi-line expression is its own thought and gets a blank line before and after it. This applies to multi-line function calls and assertions too - adjacent multi-line statements need blank lines between them. A `return` at the end of a logical block should be separated from the preceding assignments by a blank line. Exception: when a one-line declaration is directly tied to the action that follows (declaration-and-use as a single thought), the blank line is unnecessary. This is a style workaround for C's verbose grammar.

```c
// good - blank line after block-top declarations
void process_reading(sensor_t* sensor)
{
  int result = 0;
  int32_t value = 0;

  result = sensor_read(sensor, &value);
  if (result < 0)
    return;

  publish(value);
}

// good - inline declaration-and-use as a single thought
void process_reading(sensor_t* sensor)
{
  int result = sensor_read(sensor, &value);
  if (result < 0)
    return;

  int32_t calibrated = apply_offset(value, sensor->offset);
  publish(calibrated);
}

// good - multi-line expression separated from one-liners
bool higher_priority = candidate->priority > current->priority;

bool same_priority_earlier =
  candidate->priority == current->priority
  && candidate->sequence < current->sequence;

if (higher_priority || same_priority_earlier)
  best = (int) i;

// avoid - no blank line after block-top declarations
void process_reading(sensor_t* sensor)
{
  int result = 0;
  int32_t value = 0;
  result = sensor_read(sensor, &value);
  if (result < 0)
    return;

  publish(value);
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
  uint16_t port;

  app_protocol_t protocol;

  uint8_t flags;
} app_port_rule_t;
```

**When to deviate**: When a struct has distinct logical groups of fields (e.g. configuration fields followed by state fields), a blank line between groups improves readability.

---

### Column Alignment

**Intent**: Vertical alignment makes related groups of constants and annotations scannable.

**Convention**: The general style guide deprecates vertical alignment of code symbols. In C, two exceptions apply:

1. **`#define` groups** - align values within related groups of constants to the next tab stop after the longest name. These are lookup tables that change infrequently, and alignment makes values scannable.
2. **Inline comments** - align inline comments across related lines. Unaligned comments become visual noise. This includes `///<` trailing docs on struct fields and enum values - all `///<` comments in a group must start at the same column.

AI NOTE: Agents misalign `///<` trailing comments when one field name is longer than the others. After writing a struct or enum with `///<` comments, verify all comments in the group start at the same column.

All other cases (struct fields, enum values, designated initializers, local variables, assignments, function params, static variables) default to unaligned. Alignment in these cases creates diff noise when lines are added or changed, contradicting the benefit of trailing commas.

```c
// good - aligned values in related #define group
#define SPEED_OFF     0
#define SPEED_LOW     1
#define SPEED_MEDIUM  2
#define SPEED_HIGH    3

// good - aligned inline comments
int result = read_sensor(&sensor, &value);  // returns 0 on success
int status = calibrate(&sensor);            // must be called after read

// avoid - unaligned values in a #define group
#define SPEED_OFF 0
#define SPEED_LOW 1
#define SPEED_MEDIUM 2
#define SPEED_HIGH 3

// avoid - unaligned inline comments on related lines
int result = read_sensor(&sensor, &value); // returns 0 on success
int status = calibrate(&sensor); // must be called after read

// avoid - misaligned ///< on struct fields
typedef struct {
  int current_state; ///< Current state
  int event; ///< Triggering event
  int next_state; ///< State after transition
  action_callback_t action; ///< Optional callback; may be NULL
} transition_t;

// good - all ///< comments start at the same column
typedef struct {
  int current_state;        ///< Current state
  int event;                ///< Triggering event
  int next_state;           ///< State after transition
  action_callback_t action; ///< Optional callback; may be NULL
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
// good - packed struct for IPC message
typedef struct __attribute__((packed)) {
  uint8_t message_type;
  uint16_t payload_length;
  uint8_t payload[128];
} app_ipc_message_t;

// good - internal struct; no packing needed
typedef struct {
  uint16_t port;
  app_protocol_t protocol;
} app_port_rule_t;
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

AI NOTE: Agents default to putting static helpers first to avoid forward declarations. Always use forward declarations and place public API functions before static helpers.

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
static int find_best(const tq_t* queue)
{
  // ...
}

// good - forward declarations at top of file
static void handle_timeout(timer_t* timer);
static void handle_response(address_t* source, uint8_t* data, uint16_t length);

// good - static file-scope variables
static uint16_t network_number;
static bool initialized = false;

// avoid - internal function without static (leaks into global namespace)
int find_best(const tq_t* queue)
{
  // ...
}

// avoid - file-scope variable without static, unless intentionally global.
// Global variables should be defined and used with care.
uint16_t network_number;
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
int port_send(message_t* message)
{
  uint32_t total_bytes = htonl(message->index);
  size_t sent_bytes = 0;

  pthread_mutex_lock(&write_lock);

  int result = write(STDOUT_FILENO, &total_bytes, sizeof(total_bytes));
  if (result != 4)
    goto error;

  while (sent_bytes < message->index) {
    size_t sent = write(
      STDOUT_FILENO,
      message->buffer + sent_bytes,
      message->index - sent_bytes
    );

    if (sent < 0)
      goto error;

    sent_bytes += sent;
  }

  pthread_mutex_unlock(&write_lock);

  return 0;

error:
  pthread_mutex_unlock(&write_lock);

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

**Convention**: Use designated initializers (`.field = value`) for struct initialization. Use `= { 0 }` to zero-initialize structs and arrays. Positional initialization is a legacy pattern for any struct with more than one field.

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

**Convention**: Prefer `sizeof(variable)` or `sizeof(*pointer)` over `sizeof(type)` when a variable is in scope. The variable-based form stays correct if the type changes; the type-based form silently diverges.

AI NOTE: Agents frequently use `sizeof(type)` in `calloc` and `memset` calls even when a variable is in scope. Always use `sizeof(*pointer)` for allocation and `sizeof(variable)` for memset/memcpy.

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

**When to deviate**: When writing code that must compile as both C and C++ (C++ requires the cast). Use `// style:ok - C++ compatibility` if needed.

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

### Named Boolean Expressions

**Intent**: Complex boolean conditions should be extracted to named variables so the `if` statement reads as a simple question. See the general guide's Named Boolean Expressions rule.

AI NOTE: Agents embed complex conditions directly in `if` statements instead of extracting to named booleans. When an `if` condition has multiple comparisons joined by `&&` or `||`, extract to a `bool` variable with a descriptive name.

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

**Convention**: When an `if` statement tests the return value of a function call directly, place the literal on the left side. Alternatively, capture the return value in a variable first and compare on the next line. When captured to a variable, use the natural comparison order (`result < 0`), not literal-first (`0 > result`) - the variable name already provides readability.

AI NOTE: Agents consistently place the literal at the end of function call comparisons. Always use literal-first or capture-then-compare for function call returns in `if`.

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
