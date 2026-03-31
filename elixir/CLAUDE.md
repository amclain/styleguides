# Elixir Style Guide

This file defines style conventions for Elixir code. It is used by Claude Code to apply and review style.

The overarching philosophy is defined in the repository's top-level `CLAUDE.md`: these are recommendations, not mandates, and precedence in the codebase takes priority over this guide.

To suppress a suggestion for a specific block, add `# style:ok - reason`.

---

## Naming

### Module Names

`CamelCase`. Acronyms stay uppercase. Nested responsibilities expressed with dot notation. Avoid repeating namespace fragments. Internal/private modules marked with `@moduledoc false`.

```elixir
# good
defmodule MyApp.HTTPClient do
defmodule MyApp.DataPipeline do
defmodule MyApp.DataPipeline.State do
  @moduledoc false

# avoid
defmodule My_App.data_pipeline do
defmodule MyApp.DP do           # unclear abbreviation
defmodule Todo.Todo do           # repeated namespace fragment — prefer Todo.Item
```

---

### Function Names

`snake_case`. Boolean-returning functions end with `?`. Guard-compatible boolean functions use an `is_` prefix. Side-effecting functions that raise use `!`. Private functions use `defp`.

Private functions may share the same name as a public function when they are the direct implementation behind it — the classic case being a public function that hides an accumulator, with the private clause doing the recursive work. Avoid sharing names in other cases where a more descriptive private name would better communicate the difference in responsibility.

```elixir
# good
def fetch_status(resource_id), do: ...
def valid_config?(opts), do: ...
defguard is_valid_config(opts) when ...
def write_to_disk!(path, data), do: ...

# good — private shares name with public for accumulator pattern
def reverse(list), do: reverse(list, [])
defp reverse([], acc), do: acc
defp reverse([h | t], acc), do: reverse(t, [h | acc])

# avoid
def fetchStatus(id), do: ...    # camelCase
def check(x), do: ...           # too vague
def d(id), do: ...              # single-letter name
```

---

### Variable Names

`snake_case`. Names should describe what the value represents. A reader picking up the code 6 months later should not need to trace a variable back to its origin to understand it. Avoid abbreviations unless universally understood in Elixir/OTP. See `general/CLAUDE.md` for the general naming principle.

Acceptable short names: `pid`, `ref`, `acc`, `opts`, `mod`, `fun`, `id`.

**OTP conventions**: The GenServer state argument is always named `state`. The `start_link` parameter is `args` (not `opts`) - see **start_link Doc and Typespec**. A captured process identifier is `pid` or `<subject>_pid` (e.g. `sensor_pid`).

```elixir
# good
defp apply_timeout(connection, timeout_ms) do
  {:ok, duration_ms} = measure_roundtrip(connection)
  ...
end

# avoid
defp apply_timeout(c, t) do
  {:ok, d} = measure_roundtrip(c)
  ...
end
```

When to deviate: single-letter accumulator variables in very tight, single-line `Enum` operations where intent is clear from context.

---

### Module Attributes (Constants)

`snake_case`. Defined in the module after directives. Use underscores as thousands separators in large numeric literals. See `general/CLAUDE.md` for the general principle on when to extract a value vs leave it inline.

```elixir
# good — shared configuration values
@default_timeout_ms 5_000
@max_retry_attempts 3

# acceptable — idiomatic; milliseconds are understood in context
Process.sleep(5000)
```

### Compile-Time Configuration

Environment-specific values belong in `config/` files, not inline conditionals. Use `Application.compile_env/3` to read the configured value.

When a compile-time conditional is appropriate (rare - e.g. a value that genuinely differs by compile target and has no config file), use the `if/do/else` block form, not the inline ternary form.

```elixir
# best — value lives in config/; module just reads it
@poll_interval Application.compile_env(:my_app, :poll_interval)

# good — compile-time conditional when config is not available
if Application.compile_env(:my_app, :env) == :test do
  @poll_interval 1
else
  @poll_interval 200
end

# avoid — inline ternary is hard to read for compile-time conditionals
@poll_interval if(
  Application.compile_env(:my_app, :env) == :test,
  do: 1,
  else: 200
)
```

---

## Module Structure

### Directive Ordering

**Before writing any module header, check this list.** Directive ordering mistakes are one of the most common generation errors.

Follow this within every module, with a blank line between each group. Sort terms alphabetically within each group.

1. `@moduledoc`
2. `@behaviour`
3. `use`
4. `import`
5. `alias`
6. `require`
7. `defstruct`
8. `@type` / `@typedoc`
9. `@callback` / `@macrocallback` / `@optional_callbacks`
10. Module attributes — constants and compile-time configuration (`@name value`)
11. `defmacro`, `defguard`, `def`, etc.

The ordering moves from structural declarations (what the module is) toward implementation (what it does). Typespecs and callbacks are public API — a consumer of the module needs to see them. Module-level constants are internal implementation details and belong below the public interface. This is an application of the Newspaper Metaphor — see `general/CLAUDE.md`.

```elixir
# WRONG — constants above types
defmodule MyApp.Protocol.Parser do
  @moduledoc "Binary protocol parser"

  @magic_bytes <<0xAB, 0xCD>>
  @header_size 6
  @msg_type_ping 0x01

  @typedoc "Recognized message types"
  @type message_type :: :ping | :pong | :data
end

# RIGHT — types above constants
defmodule MyApp.Protocol.Parser do
  @moduledoc "Binary protocol parser"

  @typedoc "Recognized message types"
  @type message_type :: :ping | :pong | :data

  @magic_bytes <<0xAB, 0xCD>>
  @header_size 6
  @msg_type_ping 0x01
end
```

AI NOTE: After writing a module header that has both `@type`/`@typedoc` and module-level constants (`@name value`), verify the types appear first. This is the most common ordering mistake - the natural impulse is to define constants before types, but the rule requires types first because they are public API.

Each directive type is its own group — a blank line is required between them even when only a single directive is present in each group:

```elixir
# good — blank line between each directive group
use GenServer
use Resolve

import Bitwise

require Logger

# avoid — missing blank lines between groups
use GenServer
use Resolve
import Bitwise
require Logger
```

---

### Internal Modules

Use `@moduledoc false` for modules not intended for public documentation — internal helpers and GenServer `State` structs.

---

### Boilerplate Modules

Use `@moduledoc false` for standard scaffolding modules where documentation would add no meaningful value. The `Application` module is the primary example: it is standard OTP scaffolding with no domain-specific behavior worth documenting. Project-level documentation belongs in the README, not in the application module.

---

### Test Modules

Do not add `@moduledoc false` to test modules. ExDoc does not pick up test files by default, so the attribute is unnecessary noise.

---

### GenServer State Module

Define GenServer state in a nested `State` module with `@moduledoc false` and a `defstruct`. This makes the shape of the process state explicit and visible. Place the nested module in the directive area - after `use`/`import`/`alias`/`require` and before any function definitions. The state shape is structural context the reader needs before encountering the functions that use it.

```elixir
# good — State in directive area, before functions
defmodule MyApp.Worker do
  @moduledoc "..."

  use GenServer

  defmodule State do
    @moduledoc false
    defstruct [:connection, :job_id, :retry_count]
  end

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
end

# avoid — State after functions; reader encounters %State{} before seeing its shape
defmodule MyApp.Worker do
  @moduledoc "..."

  use GenServer

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  defmodule State do
    @moduledoc false
    defstruct [:connection, :job_id, :retry_count]
  end
end
```

---

### Self-Reference

Use `__MODULE__` when a module refers to itself, including in struct pattern matches. This ensures self-references remain valid if the module is renamed.

```elixir
# good
defmodule MyApp.Item do
  defstruct [:name, :value]

  def name(%__MODULE__{name: name}), do: name
end

# avoid
defmodule MyApp.Item do
  defstruct [:name, :value]

  def name(%MyApp.Item{name: name}), do: name  # breaks if module is renamed
end
```

---

### File Naming

Use `snake_case` for filenames. Each level of module namespace corresponds to a directory level.

```
# good
lib/my_app/http_client.ex      → defmodule MyApp.HTTPClient
lib/parser/core/xml_parser.ex  → defmodule Parser.Core.XMLParser

# avoid
lib/MyApp/HTTPClient.ex
lib/parser/core/xmlParser.ex
```

---

## Functions

### `def` Syntax

Use parentheses when a function has arguments. Omit parentheses for zero-arity functions.

```elixir
# good
def process(arg1, arg2) do ... end
def run do ... end

# avoid
def process arg1, arg2 do ... end
def run() do ... end
```

---

### Single-line vs Multiline `def`

Group consecutive single-line clauses together. Separate multiline clauses with a blank line. When multiple clauses of the same function are all multiline (`do ... end`), every pair must have a blank line between them. Mixing single-line and multiline clauses is acceptable when the single-line clauses are clearly grouped and the multiline clause is visually distinct.

```elixir
# good — clearly grouped, visually distinct
def process(nil), do: {:error, "no value"}
def process(1), do: {:ok, 10}
def process(2), do: {:ok, 20}

def process([head | tail]) do
  ...
end

# good — all multiline, blank line between each clause
def encode(%{type: :ping}) do
  build_frame(@msg_ping, <<>>)
end

def encode(%{type: :data, payload: payload}) do
  build_frame(@msg_data, payload)
end

def encode(%{type: :error, code: code, reason: reason}) do
  build_frame(@msg_error, <<code::8, reason::binary>>)
end

# WRONG — multiline clauses with no blank lines between them
def encode(%{type: :ping}) do
  build_frame(@msg_ping, <<>>)
end
def encode(%{type: :data, payload: payload}) do
  build_frame(@msg_data, payload)
end
def encode(%{type: :error, code: code, reason: reason}) do
  build_frame(@msg_error, <<code::8, reason::binary>>)
end
```

---

### Function Length and Responsibility

See `general/CLAUDE.md` for the general principle. In Elixir, private helpers are extracted with `defp`. Do not extract when the helper is so trivial that the indirection adds noise without adding meaning.

```elixir
# good — named steps document a multi-stage pipeline
def process_event(event) do
  event
  |> validate_event
  |> enrich_with_metadata
  |> dispatch_to_handler
end

defp validate_event(event), do: ...
defp enrich_with_metadata(event), do: ...
defp dispatch_to_handler(event), do: ...

# good — direct and concise when steps are trivial
def process_event(nil), do: raise "event error"
def process_event(event), do: handle(%{event: event})

# avoid — extracting helpers so trivial they add noise without meaning
def process_event(event) do
  event
  |> validate_event()
  |> enrich_with_metadata()
  |> dispatch_to_handler()
end

defp validate_event(nil), do: raise "event error"
defp validate_event(event), do: event
defp enrich_with_metadata(event), do: %{event: event}
defp dispatch_to_handler(event), do: handle(event)
```

---

### Guard Clauses

Use guards with `is_*` predicates for type dispatch. Prefer multiple function heads with guards over internal conditionals for top-level dispatch.

```elixir
# good
def coerce(value) when is_binary(value), do: String.to_integer(value)
def coerce(value) when is_integer(value), do: value

# avoid
def coerce(value) do
  if is_binary(value), do: String.to_integer(value), else: value
end
```

---

### Argument Ordering

Primary data comes first. Options and configuration come last as a keyword list. This enables natural piping.

```elixir
# good
def transform(data, opts \\ [])
def fetch(resource_id, opts \\ [])

# avoid
def transform(opts, data)
```

---

## Pattern Matching

### Function Head Matching vs Case

Use multiple function heads or a `case` expression based on what reads most clearly in context. Function head matching is concise for simple dispatch. A `case` inside the function body is more appropriate when pre-processing is needed before dispatching, or when keeping the logic in one place makes the stack trace easier to follow.

Always use pattern matching rather than accessing tuple elements with `elem/2`.

```elixir
# good — simple dispatch, function heads are concise
def handle_response({:ok, body}), do: process(body)
def handle_response({:error, reason}), do: log_failure(reason)

# good — pre-processing before dispatch, case reads naturally
def handle_response(result) do
  %{value: value} = result

  case value do
    nil -> :error
    1 -> :result_1
    _ -> :out_of_range
  end
end

# avoid — using elem/2 instead of pattern matching
def handle_response(result) do
  if elem(result, 0) == :ok do
    process(elem(result, 1))
  end
end
```

---

### Match Success, Don't Discard

When a function returns `:ok` or `{:ok, result}` and there is no practical error
recovery, pattern match the success case explicitly. A mismatch crashes the
process and surfaces the failure in logs. Silently discarding the return value
allows the process to continue in a bad state.

```elixir
# good — failure crashes the process and surfaces in logs
:ok = MyApp.Serial.write(id, address, value)
{:ok, result} = fetch_config(params)

# avoid — error silently swallowed; process continues in a bad state
MyApp.Serial.write(id, address, value)
fetch_config(params)
```

**When to deviate**: When meaningful recovery is possible, handle the error tuple
explicitly with `case` or `with` instead.

---

### `case`

Use `case` for multiple branches on a single value. When a catch-all clause does not use the matched value, use `_` for a true catch-all ("anything else") or a prefixed underscore (`_error`, `_reason`) when the concept matters but the variable is unused. A bare named variable (`other`, `error`) implies the value will be used in the clause body.

```elixir
# good — true catch-all, the value is conceptually irrelevant
case value do
  nil -> {:error, reason}
  _ -> {:ok, value}
end

# good — named concept, but unused in the body
case status do
  :ok -> proceed()
  _error -> handle_error()
end

# avoid — bare name suggests the value will be used
case status do
  :ok -> proceed()
  other -> handle_error()
end
```

---

### `with`

Use `with` for sequential operations where each step can fail. Execution stops at the first failure and falls through to the `else` clause.

---

### `cond`

Use `cond` for multiple independent boolean conditions. Use `true` as the final catch-all clause, not `:else`.

```elixir
cond do
  time < 0 -> :invalid
  time == 0 -> :zero
  true -> :positive
end
```

---

### `if`

Use `if` for a single boolean condition. It serves the same role as a ternary operator in other languages, and is also a good tool for conditional side effects. Prefer writing the positive case first. Do not use `unless` with `else` — the combination creates a double negative that makes the intent hard to read. When tempted to write `unless cond do ... else ... end`, use `case` instead: it eliminates the double negative and naturally puts the short clause first (fail-fast pattern).

For returning values across multiple branches, prefer `case` — it is fewer lines and has smoother indentation than a multi-line `if`. Use `if` when it reads more naturally than `case`.

```elixir
# WRONG — multi-line if returning a value
if checksum_valid?(data) do
  decode(data)
else
  {:error, :invalid_checksum}
end

# RIGHT — case for returning values across branches
case checksum_valid?(data) do
  true -> decode(data)
  _ -> {:error, :invalid_checksum}
end

# good — nil check with catch-all
case value do
  nil -> {:error, reason}
  _ -> {:ok, value}
end

# WRONG — false instead of catch-all
case checksum_valid?(data) do
  true -> decode(data)
  false -> {:error, :invalid_checksum}
end
```

Avoid using `if` to return a value without an `else` clause — the implicit `else: nil` is confusing.

```elixir
# good — single-line ternary
if value, do: {:ok, value}, else: :error

# good — multi-line ternary
if value_is_valid(value),
  do: call_function_1(value),
  else: :error

# good — side effect, no else needed
if value_is_valid(value),
  do: call_function_1(value)

# good — case preferred for returning values across branches
case value do
  nil -> :error
  _ -> :ok
end

# avoid — multi-line if for returning values; more lines, jarring indentation
if value == nil do
  :error
else
  :ok
end
```

---

### Multiline `case`/`cond` Clauses

If any clause in a `case` or `cond` expression needs more than one line, use multiline syntax for all clauses and separate each with a blank line.

Even when all clauses fit on one line, prefer multiline format when the clause bodies are complex (nested tuples, lists of tuples, multi-element keyword lists). The single-line form is acceptable but multiline is recommended for readability when there is high visual density.

```elixir
# good
case result do
  :ok ->
    log_success()
    proceed()

  :error ->
    log_failure()
    halt()
end

# acceptable — all clauses fit on one line
case :gen_tcp.send(socket, message) do
  :ok -> {:keep_state, data, [{:reply, from, :ok}]}
  {:error, reason} -> {:keep_state, data, [{:reply, from, {:error, reason}}]}
end

# recommended — multiline for complex clause bodies
case :gen_tcp.send(socket, message) do
  :ok ->
    {:keep_state, data, [{:reply, from, :ok}]}

  {:error, reason} ->
    {:keep_state, data, [{:reply, from, {:error, reason}}]}
end

# avoid — mixing single-line and multiline clauses
case result do
  :ok ->
    log_success()
    proceed()
  :error -> halt()
end
```

---

### `with`

Use `\` to continue to the next line after `with`, clauses indented 2 spaces, and `do` on its own line aligned with `with`. This keeps each clause at a consistent indent and makes `do` a clear visual separator between the clauses and body:

```elixir
# good
def provision(path) do
  with \
    {:ok, cert_pem} <- File.read(path),
    {:ok, _cert} <- Certificate.from_pem(cert_pem),
    :ok <- Store.write(cert_pem)
  do
    :ok
  else
    error -> error
  end
end
```

The mix format style — aligning subsequent clauses under the first character of the first clause, with `do` appended to the last clause — is acceptable when encountered, but not preferred for new code:

```elixir
# acceptable — mix format output; not preferred
def provision(path) do
  with {:ok, cert_pem} <- File.read(path),
       {:ok, _cert} <- Certificate.from_pem(cert_pem),
       :ok <- Store.write(cert_pem) do
    :ok
  else
    error -> error
  end
end
```

---

## Pipe Operator

### When to Use

Pipelines describe transformation. Use them to make multi-step transformation sequences readable as a linear series of steps — this is idiomatic Elixir. A single pipe is acceptable when it emphasizes a transformation.

When code becomes hard to read due to deeply nested calls, untangle it — either with a pipeline or with intermediate variables, whichever better names the concepts involved.

```elixir
# good — single pipe emphasizes transformation
templated_field |> StringTemplate.process(message)

# good — pipeline for multi-step transformation
raw_input
|> String.downcase
|> String.trim
|> String.codepoints

# avoid — complex nested call obscures intent
validate(%{status: get_status(state), next_value: state.value + 1})

# good — intermediate variable names the concept
def handle_event(:do_update, state) do
  data = %{
    status: get_status(state),
    value: state.value + 1,
  }

  case validate(data) do
    :ok -> {:ok, data}
    _ -> {:ok, state}
  end
end
```

---

### Pipeline Structure

The first element of a pipeline should be the subject being transformed. When a bare variable is the subject, start with it. When a function call retrieves the subject, start with that call — keeping its arguments intact rather than extracting one to start the pipeline.

In multiline pipelines, each stage goes on its own line with `|>` at the start, indented 2 spaces from the assignment. Add a blank line after a multiline pipeline assignment.

```elixir
# good — function call retrieves the subject; the user is what's being transformed
get_user_by_index(1)
|> ensure_user_is_active
|> do_update

# avoid — the index is not the subject
1
|> get_user_by_index
|> ensure_user_is_active
|> do_update

# good — the list is the subject; :my_app is part of the lookup, not the subject
Application.get_env(:my_app, :my_list, [])
|> Enum.take(1)

# avoid — :my_app is not the subject
:my_app
|> Application.get_env(:my_list, [])
|> Enum.take(1)

# good — bare variable is the subject
sanitized =
  raw_input
  |> String.downcase
  |> String.trim

process(sanitized)

# good — list literal as subject; each step on its own line, indented 2 spaces
url =
  [@base_url, "repos", user, repo, "releases"]
  |> Enum.join("/")
  |> HTTPoison.get

records =
  query_result
  |> Enum.reject(& &1["draft"] == true)
  |> Enum.find(& &1["name"] == version)
  |> Map.get("assets")
  |> Enum.reverse

# avoid — path fragments are part of the same logical unit; separating them
# distances the relationship between "my_project" and "data"
"my_project"
|> Path.join("data")
|> File.read!

# good — the full path is kept together and passed as a single argument
Path.join(["my_project", "data"])
|> File.read!
```

---

### Parentheses in Pipes

Do not use parentheses after one-arity functions when using the pipe operator. Parentheses are required when passing additional arguments — the Elixir compiler will warn if omitted.

```elixir
# good
raw |> String.downcase |> String.trim
items |> Enum.map(fn x -> x * 2 end)
items |> Enum.filter(&valid?/1)

# good — Ecto and Erlang module calls follow the same rule
Reading
|> apply_filters(opts)
|> Repo.all

%Reading{}
|> Reading.changeset(attrs)
|> Repo.insert

data
|> :binary.bin_to_list
|> Enum.sum

# WRONG — empty parens on one-arity pipe calls
Reading
|> apply_filters(opts)
|> Repo.all()

data
|> :binary.bin_to_list()
|> Enum.sum()
```

AI NOTE: Agents consistently add `()` to terminal pipe calls like `Repo.all()`, `Repo.insert()`, `Repo.one()`, `Enum.sum()`, `:binary.bin_to_list()`. These are all one-arity in the pipe (receiving the piped value as their single argument). The `()` must be removed. Parens are only needed when passing additional arguments beyond the piped value.

---

### Capture Operator

**Inline expressions** — use `& &1` when the argument name adds no meaningful information. A space is required between `&` and `&1` (they are two separate tokens: the capture operator and the argument reference). Omit parentheses — they add noise and are rarely necessary:

```elixir
# good — argument name adds no meaning; & &1 is more concise
Enum.find(releases, & &1["name"] == version)
Enum.reject(items, & &1["draft"] == true)

# good — compound boolean; no parens needed; use && not and
Enum.filter(items, & &1.active == true && &1.score > threshold)

# good — multiple arguments follow the same spacing convention
Enum.zip_with(lefts, rights, & &1 + &2)

# avoid — unnecessary fn when argument name adds nothing
Enum.find(releases, fn r -> r["name"] == version end)

# avoid — parens add noise
Enum.find(releases, &(&1["name"] == version))
```

Use `fn` when the argument name makes the expression meaningfully clearer, or when the expression is long enough that `& &1` becomes hard to read:

```elixir
# good — argument name adds context
Enum.map(users, fn user -> format_name(user) end)
Enum.zip_with(timestamps, values, fn ts, val -> {ts, val * scale} end)
```

**Named function references** — when a named function already exists that does what you need, prefer `&Module.fun/arity` or `&local_fun/arity` over writing an inline expression. No space between `&` and the function name:

```elixir
# good — named reference; no space
Enum.filter(items, &valid?/1)
Enum.map(values, &to_string/1)
Enum.each(pids, &Process.exit(&1, :kill))

# avoid — inline expression when a named function already exists
Enum.filter(items, & &1 |> String.valid?())
Enum.map(values, & &1 |> to_string())
```

---

## Error Handling

### Result Tuples

Use `{:ok, value}` / `{:error, reason}` tuples to signal success and failure. When a function establishes an `{:ok, value}` return type, the error case must be handled consistently — either as `{:ok, default}` with a sensible empty value, or as `{:error, reason}`. Returning `nil` or an ambiguous value hides failures and misleads callers.

```elixir
# bad — nil hides the failure; caller can't distinguish "no data" from "error"
def load_config(path) do
  case File.read(path) do
    {:ok, raw} -> {:ok, Jason.decode!(raw)}
    _ -> nil
  end
end

# good — sensible default consistent with the success type
def load_config(path) do
  case File.read(path) do
    {:ok, raw} -> {:ok, Jason.decode!(raw)}
    _ -> {:ok, %{}}
  end
end

# good — describe the error explicitly
def load_config(path) do
  case File.read(path) do
    {:ok, raw} -> {:ok, Jason.decode!(raw)}
    _ -> {:error, :file_not_found}
  end
end
```

---

### Error Handling Consistency

Choose one error signaling method per function and use it consistently: either result tuples or raising. Do not mix them. If a function raises on failure, name it with `!` and return the raw value unwrapped. The choice between the two depends on whether the current process can handle the error or whether it should propagate up the supervision tree.

```elixir
# bad — mixes raising and result tuple
def load_config(path) do
  raw = File.read!(path)
  {:ok, Jason.decode!(raw)}
end

# good — result tuple throughout
def load_config(path) do
  case File.read(path) do
    {:ok, raw} -> {:ok, Jason.decode!(raw)}
    _ -> {:error, :file_not_found}
  end
end

# good — raises throughout, bang name, unwrapped return value
def load_config!(path) do
  raw = File.read!(path)
  Jason.decode!(raw)
end
```

---

### Bang Functions

Bang functions signal that a function raises on failure. Use them when the failure is a higher-level application issue — one that should be handled by the supervision tree, trigger a process restart, or be written to logs as an unrecoverable error requiring developer attention (e.g. a missing deployment file, a record that should exist but doesn't).

```elixir
# good — missing config at startup is unrecoverable; supervision tree handles it
@config Application.compile_env!(:my_app, :required_key)

# good — record should always exist; absence is a developer error
def get_required_record!(id) do
  Repo.get!(Record, id)
end

# avoid — using bang when the error is recoverable and expected
def find_user!(id) do
  Repo.get!(User, id)   # user not found is a normal case, not a developer error
end
```

---

### Exceptions

Exception module names end with `Error`. Raise exceptions for programming errors, not expected failures — expected failures should use the `{:error, reason}` idiom.

Error message formatting is project-dependent — consistency within a project is more important than following a style rule. When in doubt, follow the format of existing error messages in the codebase. The preferred default is to capitalize the first word with no trailing punctuation for single sentences; use punctuation throughout for multiple sentences.

```elixir
# good
defmodule InvalidConfigError do
  defexception [:message]
end

raise ArgumentError, "Expected a non-empty list"
raise ArgumentError, "Expected a non-empty list. Got nil instead."

# avoid
defmodule BadConfigException do ...   # Exception suffix
```

---

## OTP and GenServer

### British Spelling in Elixir/Erlang Keywords

Elixir and Erlang originate from Europe and use British spellings in their keywords and standard library. These must be written as the language defines them — `@behaviour`, not `@behavior`. This applies to all language keywords and OTP module names.

When discussing these concepts in documentation or comments, follow the general rule on language (see `general/CLAUDE.md`).

### Callback Ordering

`start_link/1` is always first - it is the public API for starting the process. Public API functions come next, followed by callbacks, then private helpers at the bottom. No callback clause may appear after private helpers - all callbacks must be grouped together above the private section.

AI NOTE: Agents sometimes add a callback clause as an afterthought at the bottom of the file, after private helpers. This is incorrect. If a new callback clause is needed, place it with the other clauses of the same callback function, not at the end of the file.

**Callback order**: `init`, `handle_continue`, `terminate`, `handle_call`, `handle_cast`, `handle_info`. `handle_continue` stays near `init` because it is the continuation of initialization. `terminate` is the lifecycle bookend to `init`. The `handle_*` callbacks follow in call/cast/info order. Mixing callback types (e.g. a `handle_call` clause between `handle_info` clauses) causes compiler warnings.

All callbacks marked with `@impl ModuleName`, where `ModuleName` is the behaviour being implemented. Do NOT use `@impl true` - always name the behaviour module. The valid `@impl` targets for a module are its `use` and `@behaviour` declarations - scan those to determine the correct annotation. For Erlang behaviours, use the atom form: `@impl :gen_statem`.

```elixir
# WRONG — @impl true does not name the behaviour
@impl true
def init(args), do: {:ok, args}

# RIGHT — names the behaviour module
@impl GenServer
def init(args), do: {:ok, args}
```

AI NOTE: Agents frequently use `@impl true` instead of `@impl GenServer` (or the appropriate behaviour module). This was the single largest violation category in end-to-end testing (15 instances in one run). Always use the module name, never `true`.

Mark every callback clause with `@impl`, even when multiple clauses share the same function name. If one clause is later deleted, the `@impl` annotation remains on the surviving clauses.

```elixir
# good - @impl on every clause
@impl GenServer
def handle_call(:get_status, _from, state), do: {:reply, state.status, state}

@impl GenServer
def handle_call(:reset, _from, state), do: {:reply, :ok, %State{}}

# avoid - @impl only on the first clause
@impl GenServer
def handle_call(:get_status, _from, state), do: {:reply, state.status, state}

def handle_call(:reset, _from, state), do: {:reply, :ok, %State{}}
```

Common behaviour callbacks (no stdlib lookup needed):
- **GenServer**: `init/1`, `handle_continue/2`, `terminate/2`, `handle_call/3`, `handle_cast/2`, `handle_info/2`, `code_change/3`
- **`:gen_statem`**: `callback_mode/0`, `init/1`, `handle_event/4`, plus state-function callbacks
- **Application**: `start/2`, `stop/1`
- **Supervisor**: `init/1`

```elixir
defmodule MyApp.Worker do
  use GenServer

  # public API
  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def get_status(pid), do: GenServer.call(pid, :get_status)

  # callbacks
  @impl GenServer
  def init(args), do: {:ok, %State{}, {:continue, :init}}

  @impl GenServer
  def handle_continue(:init, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state), do: :ok

  @impl GenServer
  def handle_call(:get_status, _from, state), do: {:reply, state.status, state}

  @impl GenServer
  def handle_info(:timeout, state), do: {:noreply, state}

  # private helpers
  defp build_initial_state(opts), do: ...
end
```

```elixir
defmodule MyApp.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    children = [...]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

---

### Deferred Initialization

**Intent**: Prevent a process from blocking the supervision tree during startup.

**Convention**: A GenServer's `init/1` callback must complete before the next child in the supervision tree can start. When initialization involves work that may take time or block - connecting to external services, loading data, hardware setup - defer it to `handle_continue/2`. Return `{:ok, state, {:continue, :init}}` from `init/1` to trigger the deferred handler.

Do not use `handle_continue` for work that is instantaneous and non-blocking. A `send(self(), :poll)` or scheduling a timer does not block the supervision tree and belongs directly in `init/1`. Reserve `handle_continue` for work that involves I/O, network calls, or other operations with unpredictable latency.

`handle_continue/2` runs after the process has started but before the process services any messages from callers (`handle_call`, `handle_cast`, `handle_info`). This guarantees the deferred initialization completes before the process handles requests, while not blocking sibling processes from starting.

Name the continue message `:init` to signal that it is deferred initialization. A more descriptive name (e.g. `:configure`) is appropriate when the handler does something significantly more specific than general startup:

```elixir
# good - deferred initialization for blocking work
@impl GenServer
def init(_) do
  {:ok, %State{}, {:continue, :init}}
end

@impl GenServer
def handle_continue(:init, state) do
  {:ok, connection} = ExternalService.connect(host(), port())

  {:noreply, %State{state | connection: connection}}
end

# avoid - blocking init holds up the supervision tree
@impl GenServer
def init(_) do
  {:ok, connection} = ExternalService.connect(host(), port())

  {:ok, %State{connection: connection}}
end
```

Non-blocking work like `send` or timers belongs directly in `init`:

```elixir
# good - non-blocking work stays in init
@impl GenServer
def init(_) do
  send(self(), :poll)

  {:ok, %State{}}
end

# good - both: non-blocking in init, blocking deferred
@impl GenServer
def init(_) do
  send(self(), :poll)

  {:ok, %State{}, {:continue, :init}}
end

@impl GenServer
def handle_continue(:init, state) do
  {:ok, connection} = ExternalService.connect(host(), port())

  {:noreply, %State{state | connection: connection}}
end
```

This applies to any OTP process with an `init` callback, not just GenServer.

**When to deviate**: When initialization is fast and purely local (building a struct, subscribing to a PubSub topic, reading an ETS table), `init/1` is fine. Defer only when the work could block.

---

### start_link Doc and Typespec

`start_link` is a public function and requires a `@doc`. The description is typically a short boilerplate one-liner. Always spec with `GenServer.on_start` as the return type.

**Parameter naming**: `start_link` receives arguments from the supervisor, not keyword options. Name the parameter `args` (or a descriptive name like `configuration` when the shape is known). Do not use `opts` or `opts \\ []` - these imply optional keyword arguments, which is a different Elixir concept from the OTP argument-passing convention. When `init` does not use the argument, pass `nil` from `start_link` and match on `_` in `init`.

**Documentation heading**: When documenting `start_link` arguments, use `## Args` - not `## Opts`. The heading must match the parameter convention. `## Opts` implies keyword options, which contradicts the OTP argument-passing pattern.

```elixir
# good - args when init uses them
@doc """
Start the device poller.

## Args
- `host` - The hostname of the device to poll.
- `interval_ms` - How often to poll, in milliseconds.
"""
@spec start_link(args :: keyword) :: GenServer.on_start
def start_link(args) do
  GenServer.start_link(__MODULE__, args, name: __MODULE__)
end

# good - nil/_ when init doesn't use them
@doc """
Start the controller
"""
@spec start_link(args :: any) :: GenServer.on_start
def start_link(_args) do
  GenServer.start_link(__MODULE__, nil, name: __MODULE__)
end

# avoid - opts with default implies optional keyword arguments
def start_link(opts \\ []) do
  GenServer.start_link(__MODULE__, opts, name: __MODULE__)
end

# avoid - "Opts" heading when parameter is args
@doc """
Start the device poller.

## Opts
- `:host` - The hostname of the device to poll.
"""
def start_link(args) do
```

---

### Singleton vs Multi-Instance GenServer

A GenServer registered with `name: __MODULE__` is a singleton - there is one global instance. Its public API functions should use `__MODULE__` directly, not accept a `pid` parameter. A GenServer that supports multiple instances accepts a `pid` (or registered name) in its API.

Do not mix both patterns with a default argument like `pid \\ __MODULE__`. This is a code smell - it obscures whether the module was designed as a singleton or multi-instance:

```elixir
# good - singleton: API uses __MODULE__ directly
def get_reading do
  GenServer.call(__MODULE__, :get_reading)
end

# good - multi-instance: API accepts a pid
def get_reading(pid) do
  GenServer.call(pid, :get_reading)
end

# avoid - mixed: default suggests singleton but pid suggests multi-instance
def get_reading(pid \\ __MODULE__) do
  GenServer.call(pid, :get_reading)
end
```

---

### Message Tags

Use atoms to tag messages. Pattern match in handler heads.

```elixir
# good
@impl GenServer
def handle_info(:poll, state), do: ...
def handle_info({:job_complete, result}, state), do: ...

# avoid — dispatching inside handler body
@impl GenServer
def handle_info(message, state) do
  cond do
    message == :poll -> ...
  end
end
```

---

## Standard Library

### Prefer Elixir over Erlang

Prefer Elixir standard library functions over their Erlang equivalents when a
clean Elixir API exists. Elixir APIs are more consistent, composable, and
readable to someone unfamiliar with Erlang.

```elixir
# good
Enum.random(0..120)

# avoid — Erlang equivalent
:rand.uniform(121) - 1
```

**When to deviate**: Use Erlang modules directly when no Elixir equivalent
exists, or when the Erlang API offers specific behavior or performance
characteristics that the Elixir wrapper does not expose.

---

## Metaprogramming

Avoid needless metaprogramming. Macros and compile-time code generation are significantly harder to read, trace, and debug than equivalent runtime code. When a regular function achieves the same result, use a function.

Use macros when:
- The abstraction is genuinely impossible at runtime (DSLs like ESpec, Phoenix Router)
- You are building infrastructure imported across many modules (e.g., `__using__`)
- A compile-time guarantee is the point (e.g., `defguard`)

```elixir
# avoid — a function achieves the same result
defmacro log_and_return(expr) do
  quote do
    result = unquote(expr)
    Logger.debug("Result: #{inspect(result)}")
    result
  end
end

# good — function is simpler and just as effective
defp log_and_return(result) do
  Logger.debug("Result: #{inspect(result)}")
  result
end

# good — macro justified: sets up imports/aliases across consumer modules
defmacro __using__(_opts) do
  quote do
    import MyApp.Helpers
    alias MyApp.Repo
  end
end
```

---

## Documentation

### @moduledoc

Required for all public modules, placed immediately after `defmodule`, followed by a blank line before the next directive. Always use the heredoc format (`"""`), even for one-line descriptions - this keeps `@moduledoc` visually consistent with `@doc`. The exception is `@moduledoc false`, which is not a string. Use `@moduledoc false` for internal modules. Top-level namespace modules with no implementation (e.g. the project root module generated by `mix new`) should have `@moduledoc false` - do not leave the module body empty. Do not add `@moduledoc false` to test modules - ExDoc does not pick up test files by default, making it unnecessary noise.

```elixir
# good
defmodule MyApp.EventProcessor do
  @moduledoc """
  Processes incoming events and routes them to the appropriate handler
  """

  use GenServer

# avoid — @moduledoc after use
defmodule MyApp.EventProcessor do
  use GenServer

  @moduledoc """
  ...
  """
```

---

### @doc and @spec

`@doc` before `@spec`, both immediately before the function definition with no blank line between them. Required for all public functions. Always use the heredoc format (`"""`), even for one-line descriptions - this keeps all doc strings visually consistent and easy to spot in the code. Write in imperative voice.

```elixir
# good — heredoc format, even for one-liners
@doc """
Start the device poller
"""

# avoid — inline string format
@doc "Start the device poller"
```

Do not add `@spec` to private functions. `@spec` documents the public interface and is validated by the type checker. Adding `@spec` to private functions over-specifies internals and makes them harder to refactor - the spec becomes a constraint on code that should be free to change without updating a contract. If existing code already has `@spec` on private functions, leave them in place - do not remove them as part of unrelated work.

`@doc false` marks a function as conceptually private to the codebase. The function is technically public (the module needed to export it for internal reasons), but `@doc false` hides it from generated documentation and signals that external callers should not use it. Treat `@doc false` functions the same as private functions - do not call them from outside the library.

Begin with a single-line brief description. ExDoc uses this line as the summary in module and search listings. If additional detail is needed, separate it from the brief description with a blank line.

```elixir
# good — brief first line, detail separated by blank line
@doc """
Register a device to be polled

If polling is running, the device starts being polled immediately.
Otherwise, the device will be polled the next time start_polling() is called.
"""

# avoid — detail runs on from the first line, breaks ExDoc summary
@doc """
Register a device to be polled. If polling is running, the device starts
being polled immediately.
"""
```

The brief description (first line) of `@moduledoc`, `@typedoc`, and `@doc` never ends with a period - it is a title, not a sentence. This applies whether the brief description stands alone or is followed by extended documentation. Extended documentation (everything after the blank line) follows normal punctuation rules.

```elixir
# good - one-liners, no period
@moduledoc """
Manages serial port connections and request scheduling
"""
@typedoc "Result of parsing a binary stream"
@doc """
Start the device poller
"""

# good - extended description, brief line still has no period
@moduledoc """
Manages serial port connections and request scheduling

Manages a single serial connection and serializes requests from
multiple callers. Automatically reconnects on connection failure.
"""
@doc """
Register a device to be polled

If polling is running, the device starts being polled immediately.
Otherwise, the device will be polled the next time start_polling() is called.
"""

# avoid - period on one-liners
@moduledoc """
Manages serial port connections and request scheduling.
"""
@typedoc "Result of parsing a binary stream."
@doc """
Start the device poller.
"""
```

Use `##` level-2 Markdown headers to document arguments and options. Place each section after the summary sentence, separated by a blank line. Use a bullet list with a dash separator:

- Positional args (`## Args`): `` `name` `` — variable name, no colon
- Keyword opts (`## Opts`): `` `:name` `` — atom syntax, colon included (backticks render in ExDoc as code, making the atom visually distinct)
- Default values: shown as a parenthesized code span between the name and description: `` - `:name` - (`default`) - Description. ``
- Multi-line descriptions: end the line with `\` and indent the continuation to align with the start of the description text. ExDoc/Earmark requires continuation lines to be indented past the `- ` marker to be recognized as part of the same list item.

```elixir
@doc """
Register a target device with the poller

## Args
- `module` - The module implementing the device's polling behaviour.
- `pid` - The pid of the device process to poll.

## Opts
- `:timeout_ms` - (`5000`) - How long to wait for a poll response.
- `:on_failure` - (`:log`) - What to do if polling fails.
- `:description` - A human-readable description of the device. This can be \
                   multiple lines long.
"""
```

Common section headers: `## Args`, `## Opts`, `## Returns`, `## Examples`. Do not add `iex>` examples — use tests instead.

Add a blank line between `@spec` and `def` when the spec spans multiple lines. When the spec fits on one line, no blank line is needed.

```elixir
# good — single-line spec, no blank line
@doc """
Fetch the current status of a resource by ID
"""
@spec fetch_status(String.t) :: {:ok, map} | {:error, :not_found}
def fetch_status(resource_id), do: ...

# good — multi-line spec, blank line before def
@doc """
Set the local network number
"""
@spec set_local_network(network_number :: non_neg_integer) ::
  :ok | {:error, :out_of_range}

def set_local_network(network_number) do
  ...
end
```

When the argument list is too long for one line, each argument goes on its own line with 2-space indent. The closing paren and `::` stay together. A simple return type follows on the same line; a complex return goes on the next line:

```elixir
# good
@spec update_schedule(
  pid :: pid,
  item :: map,
  item_type :: :recurring | :exception | :override,
  comfort_settings_group_id :: non_neg_integer | nil
) :: :ok

@spec get_and_process(
  file_name :: String.t,
  process_fn :: (stream :: File.Stream.t -> any)
) :: any

# avoid — mix format aligns arguments with the opening paren
@spec update_schedule(
        pid :: pid,
        item :: map,
        item_type :: :recurring | :exception | :override,
        comfort_settings_group_id :: non_neg_integer | nil
      ) ::
        :ok
```

When the return type is a union, place the first option 4 spaces in and each subsequent `|` option 2 spaces in — the `|` acts as the visual anchor so all values align:

```elixir
# good
@spec add(type :: peripheral_type, id :: String.t, settings :: map) ::
    :ok
  | {:error, :unknown_type}
  | {:error, :exists}

@spec create(attrs :: map) ::
    {:ok, Ecto.Schema.t}
  | {:error, Ecto.Changeset.t}
  | {:error, :duplicate}
  | {:error, {:resource, :not_found, String.t}}

# avoid — mix format uses 8-space indent, losing the | alignment
@spec add(type :: peripheral_type, id :: String.t, settings :: map) ::
        :ok
        | {:error, :unknown_type}
        | {:error, :exists}
```

---

### Code Examples in Documentation

Do not add `iex>` runnable examples to new code. Do not remove them from existing code. Functionality should be demonstrated in unit tests, not inline doc examples.

---

### Typespecs

**Every `@type` in a public module must have a `@typedoc`.** This is mandatory, not optional. A public module is any module without `@moduledoc false`. Write the `@typedoc` immediately above its `@type`, with a blank line between pairs.

```elixir
# WRONG — public module, @type without @typedoc
defmodule MyApp.Parser do
  @moduledoc "Parses binary protocols"

  @type message_type :: :ping | :pong | :data
  @type parse_result :: {:ok, [message]} | {:error, atom}
end

# RIGHT — every @type has a @typedoc
defmodule MyApp.Parser do
  @moduledoc "Parses binary protocols"

  @typedoc "The type of protocol message"
  @type message_type :: :ping | :pong | :data

  @typedoc "Result of parsing a binary stream"
  @type parse_result :: {:ok, [message]} | {:error, atom}
end
```

In private or internal modules (`@moduledoc false`), `@typedoc` is not needed - list `@type` definitions consecutively without blank lines between them. Multi-line types are preceded by a blank line to visually separate them from single-line types above.

**Do not use parentheses after zero-arity types.** This applies everywhere types appear: `@type`, `@spec`, `@typedoc`, and struct type definitions. Zero-arity means the type takes no arguments. Parentheses are only used on types that take arguments (e.g. `list(atom)`, `MapSet.t(integer)`).

```elixir
# WRONG — empty parens on zero-arity types in @type
@type t :: %__MODULE__{name: String.t(), payload: binary()}
@type result :: {:ok, Reading.t()} | {:error, Ecto.Changeset.t()}

# RIGHT — no parens on zero-arity types in @type
@type t :: %__MODULE__{name: String.t, payload: binary}
@type result :: {:ok, Reading.t} | {:error, Ecto.Changeset.t}

# WRONG — empty parens on zero-arity types in @spec
@spec start_link(keyword()) :: GenServer.on_start()
@spec list_readings(filter_opts()) :: [Reading.t()]
@spec get_reading!(integer()) :: Reading.t()
@spec create_reading(map()) :: {:ok, Reading.t()} | {:error, Ecto.Changeset.t()}
@spec average_reading(String.t()) :: float() | nil

# RIGHT — no parens on zero-arity types in @spec
@spec start_link(keyword) :: GenServer.on_start
@spec list_readings(filter_opts) :: [Reading.t]
@spec get_reading!(integer) :: Reading.t
@spec create_reading(map) :: {:ok, Reading.t} | {:error, Ecto.Changeset.t}
@spec average_reading(String.t) :: float | nil

# parens are correct when the type takes arguments
@type tagged_list :: list(atom)
@type cache :: MapSet.t(String.t)
```

AI NOTE: This is the most persistent generation and review error. Both generators and reviewers miss this rule. When reviewing code, scan every `@type` and `@spec` line character by character for empty parentheses. Common misses in `@spec`: `Reading.t()`, `String.t()`, `integer()`, `map()`, `float()`, `Ecto.Changeset.t()`, `filter_opts()`, `binary()`. Every `()` after a type name that takes no arguments is wrong. The ONLY parens in typespecs should be on types that take arguments (e.g. `list(atom)`).

Long union types broken across lines with `|` at the start of each continuation, indented two spaces. Name the primary struct type `t`.

```elixir
# good — public module, typedoc paired with each type
@typedoc "Explanation of foo"
@type foo :: String.t

@typedoc "Explanation of bar"
@type bar :: non_neg_integer

# good — private/internal module, no typedocs needed
@type foo :: String.t
@type bar :: non_neg_integer
@type baz :: atom

# good — multi-line type preceded by blank line
@type foo :: String.t
@type bar :: non_neg_integer

@type errors ::
  {:error, :not_found}
  | {:error, :invalid}
  | {:error, :unauthorized}

# good — primary struct type named t
@type t :: %__MODULE__{
  name: String.t | nil,
  count: non_neg_integer,
}
```

---

## Structs

For stateful modules, use a bare atom list in `defstruct` — do not initialize fields. Initialize state at runtime, where the struct is instantiated. This applies to GenServer, `gen_statem`, and any other OTP behaviour that manages state through a `State` struct. Keeping initialization out of `defstruct` ensures state is always set up explicitly in one place, rather than silently relying on struct defaults.

AI NOTE: Agents consistently initialize fields in `defstruct` for stateful modules (e.g. `defstruct outputs: %{}, retries: 0`). This is one of the most frequent misses. For any module that manages OTP state, all fields in `defstruct` must be bare atoms (`:field_name`). Defaults like `%{}`, `0`, `[]`, `nil`, `false` belong in `init/1`, not `defstruct`.

For GenServer, initialize state in `init/1`. When initialization involves work that could block the supervision tree, defer it to `handle_continue/2` - see **Deferred Initialization**.

For structs outside of stateful modules, initialize fields with sane defaults where they exist. Use bare atoms for fields that have no meaningful default.

Use bracket list style. Short structs (roughly 3–4 fields) may be written on a single line. Longer structs should put each field on its own line with a trailing comma. Inline comments are acceptable on struct fields.

```elixir
# good — short, single line
defstruct [:name, :inserted_at]
defstruct [active: true, retries: 0]

# good — longer, one field per line
defstruct [
  :connection,
  :job_id,
  :retry_count,
  :last_error,
]

# good — stateful module, bare atoms, initialized at runtime
defmodule State do
  @moduledoc false
  defstruct [:connection, :job_id, :retry_count]
end

@impl GenServer
def init(opts) do
  {:ok, %State{
    connection: Keyword.fetch!(opts, :connection),
    job_id: Keyword.fetch!(opts, :job_id),
    retry_count: 0,
  }}
end

# avoid — GenServer state initialized in defstruct instead of init
defmodule State do
  @moduledoc false
  defstruct outputs: %{}
end

@impl GenServer
def init(_opts) do
  {:ok, %State{}}
end

# avoid — backslash continuation
defstruct \
  name: nil,
  active: true
```

---

## Collections

### Keyword Lists

Use keyword syntax for atom keys. Omit square brackets when the keyword list is the final argument and brackets are optional. When keys are not atoms, tuple syntax is required by the language.

```elixir
# good — atom keys, keyword syntax
config = [host: "localhost", port: 4000]
some_function(arg, key: "value")

# good — non-atom keys require tuple syntax
headers = [{"content-type", "application/json"}]

# avoid — tuple syntax for atom keys
config = [{:host, "localhost"}, {:port, 4000}]
some_function(arg, [key: "value"])
```

---

### Maps

Use atom shorthand syntax when all keys are atoms. Use rocket syntax when any key is not an atom — do not mix syntaxes. Mixing atom and non-atom keys in a map is often a code smell and signals that something should be redesigned — but only suggest a redesign when the map is defined in code you control, not when it originates from a library or external source.

```elixir
# good
%{host: "localhost", port: 4000}
%{"Content-Type" => "application/json"}

# avoid
%{:host => "localhost", :port => 4000}   # use shorthand for atom keys
%{"key" => val, other: val2}             # mixed syntax; likely a design issue
```

---

### Multi-line Collections

When a list, map, or struct spans multiple lines, put each element on its own line with a trailing comma. Opening bracket stays on the same line as the assignment. Closing bracket on its own line.

AI NOTE: Trailing commas are valid in collections (lists, maps, structs, keyword lists) but NOT in function argument lists. When reformatting a function call across multiple lines, do not add a trailing comma after the last argument - this is a syntax error in Elixir. The distinction: `[a, b,]` is valid (list), `foo(a, b,)` is not (function call).

```elixir
# good
config = [
  host: "localhost",
  port: 4000,
  timeout_ms: 5_000,
]

# avoid
config =
[
  host: "localhost",
  port: 4000
]
```

Supervision children lists change frequently - processes are added and removed as a project grows. Use explicit child spec tuples `{Module, args}` rather than bare module names - this makes the arguments visible and avoids relying on implicit `child_spec/1` definitions. Always use trailing commas so each such change is a one-line diff:

```elixir
# good — adding or removing a child touches only that line
children = [
  {MyApp.Repo, []},
  {MyApp.Worker, []},
  {MyApp.Server, []},
]

# avoid — removing the last child also modifies the line above it
children = [
  {MyApp.Repo, []},
  {MyApp.Worker, []},
  {MyApp.Server, []}
]
```

Struct updates follow the same pattern. A short update may fit on one line; when it grows too long, expand to multi-line with `|` at the end of the first line. When a field value is complex, prefer keeping it inline — open a collection literal on the same line as the field, or use the multi-line struct form to give a function call its own line. Extract to a local variable only when the value is complex enough that keeping it inline adds too much nesting or obscures what is changing.

Nested struct and collection updates are difficult splits with no single right answer — use judgement. There are, however, patterns that clearly don't read well: placing `state` alone on its own line before `|`, or leaving long field values running off the right edge of the screen.

```elixir
# good — fits on one line
state = %State{state | is_polling: true, device_poll_timers: updated_timers}

# good — too long or too many fields: expand to multi-line
state = %State{
  state |
  is_polling: true,
  device_poll_timers: updated_timers,
}

# avoid — state on its own line with | on the next is hard to read
%State{
  state
  | device_poll_timers: %{state.device_poll_timers | device_pid => {module, timer}}
}

# good — field value is a function call: use multi-line struct update
%State{
  state |
  device_poll_timers: Map.delete(state.device_poll_timers, device_pid)
}

# good — field value is a collection literal: open it inline with the field
%State{state | device_poll_timers: %{
  state.device_poll_timers |
  device_pid => {module, timer},
}}

# good — extract to a local variable when the map update is complex enough
# that keeping it inline adds too much nesting or obscures what is changing
device_poll_timers =
  build_updated_timers(state.device_poll_timers, device_pid, module, timer)

%State{state | device_poll_timers: device_poll_timers}
```

---

## Formatting

### Indentation and Spacing

2-space indentation. No tabs. Spaces around operators, after commas, colons, and semicolons. No spaces inside matched pairs (brackets, parentheses, braces). No trailing whitespace. Files end with a newline.

```elixir
# good
do_something({:foo, :bar})

# avoid
do_something( {:foo, :bar} )
do_something({ :foo, :bar })
```

When a function call's arguments don't fit on one line, each argument goes on its own line indented 2 spaces. The closing paren returns to the original indent level. This applies regardless of how many arguments there are:

```elixir
# good
result = MyApp.Client.post!(
  "https://api.example.com/endpoint",
  body: payload,
  headers: [auth_header(), {"Content-Type", "application/json"}]
)

{:ok, pid} = MyApp.Worker.start_link(
  host: "localhost",
  port: 4000,
  timeout: 250,
  active: false
)

# avoid — mix format aligns arguments with the opening paren
result = MyApp.Client.post!(
           "https://api.example.com/endpoint",
           body: payload,
           headers: [auth_header(), {"Content-Type", "application/json"}]
         )
```

When a chained call exceeds the line length limit, keep the full call on the first line and break the complex argument to the next line. The first line communicates what is being called; the indented line is the argument detail:

```elixir
# good — call on one line, complex argument indented below
result = resolve(MyApp.Serial).request(
  {:fc, @slave_id, @do0_coil_address + channel, value}
)

# avoid — entire expression on one line, exceeds limit
result = resolve(MyApp.Serial).request({:fc, @slave_id, @do0_coil_address + channel, value})
```

The same rule applies to function definition heads. When a `def` argument list
is too long to fit on one line, each argument goes on its own line with 2-space
indent. The closing `) do` returns to the `def` indent level:

```elixir
# good — long pattern match argument broken to its own line
@impl GenServer
def handle_info(
  %PropertyTable.Event{property: ["light_sensor", "lux"], value: lux},
  state
) do
  ...
end

# avoid — exceeds line length limit
@impl GenServer
def handle_info(%PropertyTable.Event{property: ["light_sensor", "lux"], value: lux}, state) do
  ...
end
```

Inside a `case` or `cond`, each clause body is 2 indent levels deeper than the enclosing function body — one for the block, one for the clause. When the block ends, code returns to the function body in a single 2-level jump:

```elixir
# good — each level is 2 spaces; clause body at 4, nested clause body at 6
def fetch(user, version) do
  case MyApp.API.get_releases(user) do
    {:ok, releases} ->
      release = Enum.find(releases, & &1["name"] == version)

      case release do
        nil ->
          {:error, :not_found}

        _ ->
          url = Map.get(release, "url")
          MyApp.Updater.apply(url)
      end

    error ->
      error
  end
end
```

---

### Line Length

Hard limit of 80 characters. When a line exceeds this, break it — the need to break is usually a signal that the code is too complex, and restructuring it will improve readability. See `general/CLAUDE.md` for the rationale.

Use `# style:ok` to suppress this for a specific line when the length is purely a consequence of long names and the line is not genuinely complex.

---

### Blank Lines

- Single blank line between function definitions
- Blank line after `@moduledoc` before the next directive
- Blank line after a multiline assignment as a visual cue it is complete
- When any clause in a `case`/`cond` needs multiple lines, expand all clauses to multiline (body on the next line) and add a blank line between them. When all clauses fit on one line, keep them single-line with no blank lines between
- No blank line immediately after `defmodule`
- No blank line at the start of a file; if the file begins with a header comment, the header starts at line 1 with one blank line after it before the first definition
- Blank line before the return value when the function body has preceding statements — this applies whether the return value is a simple expression or a block expression (`case`, `with`, `cond`, `if`)
- Blank line before any block expression (`case`, `with`, `cond`, `if`) when there are preceding statements in the same scope, even when it is not the return value
- Blank lines between distinct phases within a function body — when a function has an assignment phase, an action phase, and a return value, separate each with a blank line. This is especially important when individual statements are complex
- Blank line after a `Logger` call when followed by more statements — log calls are side effects that are conceptually separate from the surrounding logic. No blank line needed when the log call is the last statement before `end`

```elixir
# good — all single-line clauses, no blank lines
case value do
  nil -> :error
  _ -> :ok
end

# good — any multiline clause: expand all, blank lines between
case value do
  nil ->
    {:error, :not_present}

  _ ->
    coerced_value = coerce(value, :string)
    {:ok, coerced_value}
end

# avoid — mixing single-line and multiline clauses
case value do
  nil -> {:error, :not_present}

  _ ->
    coerced_value = coerce(value, :string)
    {:ok, coerced_value}
end

# good — blank line after multiline assignment
result =
  value
  |> transform
  |> finalize

use_result(result)

# avoid — missing blank line makes the boundary unclear
result =
  value
  |> transform
  |> finalize
use_result(result)

# good — multiline assignment followed by another statement
updated_timers =
  Map.put(state.device_poll_timers, device_pid, {module, initial_timer})

state = %State{state | device_poll_timers: updated_timers}

# good — long args broken across lines (blank line still required after)
updated_timers = Map.put(
  state.device_poll_timers,
  device_pid,
  {module, initial_timer}
)

state = %State{state | device_poll_timers: updated_timers}

# avoid — cluttered, no blank line between multiline assignment and next statement
updated_timers =
  Map.put(state.device_poll_timers, device_pid, {module, initial_timer})
state = %State{state | device_poll_timers: updated_timers}

# good — short function, single statement before return, no blank line needed
def init(_) do
  {:ok, %State{}}
end

# good — multiple statements before return, blank line required
def handle_info(:poll, state) do
  read_sensor()
  schedule_poll()

  {:noreply, state}
end

# good — blank line before simple return value
def process(data) do
  Logger.info("starting")
  result = compute(data)

  {:ok, result}
end

# good — blank line before block return value
def process(data) do
  validated = validate(data)

  case validated do
    {:ok, v} -> dispatch(v)
    error -> error
  end
end

# avoid — no blank line before block return value
def process(data) do
  validated = validate(data)
  case validated do
    {:ok, v} -> dispatch(v)
    error -> error
  end
end

# good — blank line before block even when not the return value
def process(data) do
  Logger.info("starting")

  case validate(data) do
    {:error, _} = error -> error
    {:ok, validated} ->
      store(validated)
      :ok
  end
end

# avoid — block runs directly into preceding code
def process(data) do
  Logger.info("starting")
  case validate(data) do
    {:error, _} = error -> error
    {:ok, validated} ->
      store(validated)
      :ok
  end
end

# acceptable — tight two-line pair needs no blank line
def process(data) do
  result = compute(data)
  {:ok, result}
end

# acceptable — fully inlined when the inner expression is a single simple call
def process(data) do
  {:ok, compute(data)}
end
```

---

### Comments

See `general/CLAUDE.md` for the general philosophy: write self-documenting code, use comments to explain *why* not *what*, and placement guidance.

Elixir-specific conventions:

Start comments with `# ` (one space). Short comments of one or two words don't need to be complete sentences. When a comment is several words long or reads as a sentence, capitalize it and punctuate it as one.

```elixir
# good — short inline comments on a densely packed map
state = %{
  sensor_1: -1, # Value less than 0 is an error.
  sensor_2: 0,
  sensor_3: 5,
}

# good — comment explains why, not what
defp process do
  # Proprietary algorithm required by the hardware vendor spec.
  value = proprietary_algorithm(coerced_value)
  ...
end
```

Do not use section divider comments (`# --- Private ---`, `# --- Callbacks ---`, etc.). The code structure is already defined by directive ordering, callback ordering, and the Newspaper Metaphor. Narrating the structure with dividers is redundant and adds noise.

```elixir
# avoid — section dividers narrate code structure
# --- Public API ---
def start_link(args), do: ...

# --- Callbacks ---
@impl GenServer
def init(_), do: ...

# --- Private ---
defp helper, do: ...
```

Annotation keywords use `# TAG:` format:
- `# TODO:` — missing feature to add later
- `# FIXME:` — broken code that needs fixing
- `# OPTIMIZE:` — slow or inefficient code
- `# HACK:` — questionable practice that should be refactored
- `# REVIEW:` — needs verification of correctness

---

### Zero-Arity Calls

Do not use parentheses after zero-arity functions that follow a module name. Parentheses are required by the language on zero-arity functions called alone, to disambiguate from variables.

```elixir
# good — module-qualified, no parens
MyModule.do_action

# good — standalone call, parens to distinguish from variable
value = compute()

# avoid
MyModule.do_action()   # unnecessary parens after module name
value = compute        # ambiguous: variable or function call?
```

---

### Strings

Match string prefixes using the concatenation operator `<>`, not binary pattern syntax. Exception: when parsing a binary protocol, binary pattern matching is appropriate.

```elixir
# good — string prefix matching
"hello" <> rest = "hello world"

# avoid — binary syntax for plain string matching
<<"hello"::utf8, rest::bytes>> = "hello world"

# good — binary pattern matching for protocol parsing
<<header::binary-size(4), payload::bytes>> = raw_packet
```

---

## Testing

Testing rules are defined in `elixir/testing.md`, loaded via `@` import at the top of this file.

## Deprecated Rules

These rules were previously followed but are no longer recommended for new code. They are documented here for reference when working on legacy codebases — if existing code follows these conventions, match them for consistency.

### Vertical Alignment (Deprecated)

See the top-level `CLAUDE.md` for the general rule. Elixir-specific examples of the deprecated pattern:

```elixir
# previously preferred — no longer recommended
def handle_response(nil), do: :error
def handle_response(1),   do: :result_1
def handle_response(2),   do: :result_2
def handle_response(_),   do: :out_of_range

@first_value  1
@second_value 2
@third_value  3

first_value  = Keyword.get(opts, :first_value)
second_value = Keyword.get(opts, :second_value)
third_value  = Keyword.get(opts, :third_value)

%{
  first_key:  1,
  second_key: 2,
  last_key:   3,
}
```

---

## First-Run Project Checks

Perform these checks once per project and save the results to memory. On subsequent runs, read from memory instead of re-checking. A check is due when no memory entry exists for that topic in the current project.

### Test Framework

Check which test framework the project uses by inspecting `mix.exs` for `:espec` or `:ex_unit` dependencies and scanning a sample of test files for `use ESpec` or `use ExUnit.Case`. Save the result to memory so the correct conventions are applied when generating or reviewing test code.

- **ESpec**: apply the ESpec formatting and assertion conventions defined in the Testing section of this guide.
- **ExUnit**: apply standard ExUnit conventions.
