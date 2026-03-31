# ESpec Mechanics

This file covers how ESpec works mechanically. It is loaded for projects that use ESpec (detected by the Test Framework first-run check). For style rules on writing ESpec tests, see `elixir/testing.md`. For Resolve dependency injection mechanics, see `elixir/resolve_mechanics.md`.

## Project Setup

To add ESpec to a new project:

1. Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:espec, "~> 1.9", only: :test},
  ]
end
```

2. Add the `espec` preferred CLI env and alias `test` to `espec` in `mix.exs`:

```elixir
def project do
  [
    # ...
    preferred_cli_env: [espec: :test],
    aliases: aliases(),
  ]
end

defp aliases do
  [
    test: "espec",
  ]
end
```

3. Create `spec/spec_helper.exs`:

```elixir
ESpec.configure(fn config ->
  config.before(fn tags ->
    {:shared, tags: tags}
  end)

  config.finally(fn _shared ->
    :ok
  end)
end)
```

4. Add ESpec DSL functions to `.formatter.exs` so `mix format` does not add parentheses to them:

```elixir
[
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,spec}/**/*.{ex,exs}",
  ],
  locals_without_parens: [
    # Test setup
    before: 1,
    before_all: 1,
    after_all: 1,
    finally: 1,
    subject: :*,
    subject!: :*,
    let: :*,
    let!: :*,
    let_overridable: 1,

    # Examples
    example: :*,
    it: :*,
    specify: :*,
    it_behaves_like: :*,

    # Assertions / Matchers
    eq: 1,
    eql: 1,
    be: :*,
    be_between: 2,
    have: 1,
    have_key: 1,
    have_value: 1,
    have_count: 1,
    match_pattern: 1,
    raise_exception: :*,

    # Mocking
    allow: 1,
    accept: 2,
  ]
]
```

5. Create spec files in `spec/` with the `_spec.exs` suffix. Each spec module uses `use ESpec`:

```elixir
defmodule MyApp.Widget.Spec do
  use ESpec, async: false
end
```

Run tests with `mix test` (aliased to `mix espec`).

## Meck (allow/accept)

ESpec uses Meck for mocking via the `allow`/`accept` syntax. Understanding how Meck works under the hood is essential for knowing when it will and won't work.

### How it works

`allow(Module) |> to(accept :function, fn args -> result end)` does three things:

1. Calls `:meck.new(Module, [:non_strict, :passthrough])` if the module is not already mocked
2. Calls `:meck.expect(Module, :function, fn_implementation)`
3. Tracks the mock as `{Module, self()}` in an Agent (`:espec_mock_agent`) for per-example cleanup

`:non_strict` allows mocking functions that don't exist on the original module. `:passthrough` allows unmocked functions to fall through to the original implementation.

### Automatic cleanup

ESpec unloads all Meck mocks after each example. `ESpec.Mock.unload/0` queries the tracking Agent for mocks created by the current process (`self()`), then calls `:meck.unload(modules)`. This means mocks set up via `allow`/`accept` do not persist between examples.

### When Meck works

Meck works reliably when the test controls the timing of the mocked call - the mock is set up, then the test triggers the code path that calls the mocked function, and waits for the result:

```elixir
# good - test-synchronous: test triggers the call and waits
allow(MyApp.HTTP) |> to(accept :get, fn _url -> {:ok, %{status: 200}} end)

result = MyApp.Client.fetch("https://example.com")

result |> should(eq {:ok, %{status: 200}})
```

### When Meck fails

**`self()` resolves to the calling process, not the test process.** When a Meck mock runs inside a GenServer callback, `self()` returns the GenServer's pid. A mock that uses `send(self(), :signal)` sends the message to the GenServer's mailbox - the test's `assert_receive` never sees it. This is a silent failure: the test times out waiting for a message that went to the wrong process.

```elixir
# fails silently - send goes to GenServer, not test
allow(MyApp.Serial) |> to(accept :request, fn _cmd ->
  send(self(), {:serial_request, :called})  # self() = GenServer pid
  {:ok, [0, 100]}
end)

# works - closure captures test pid
test_pid = self()

allow(MyApp.Serial) |> to(accept :request, fn _cmd ->
  send(test_pid, {:serial_request, :called})  # test_pid = test process
  {:ok, [0, 100]}
end)
```

Capturing `test_pid` in a closure fixes the signaling problem, but the pattern is error-prone - an agent writing mock code naturally reaches for `self()`. Resolve avoids this entirely: `unquote(test_pid)` is baked into the mock at definition time, making the test pid explicit and visible.

**Return value issue (unresolved):** In production codebases, Meck has been observed returning the original return value instead of the mock's when a GenServer calls a mocked function from within its callbacks. The exact trigger condition has not been isolated in synthetic tests. One potential mechanism: Meck compiles new bytecode in a spawned subprocess (`meck_proc.compile_expects`), and a process mid-execution of a callback may continue running old bytecode for that invocation.

In production codebases, the pattern is consistent: Resolve is used for modules called from GenServer callbacks, Meck is used for test-synchronous calls. Use Resolve for GenServer callback dependencies. See `elixir/resolve_mechanics.md`.

### Cleanup race condition

ESpec unloads Meck mocks after each example, restoring the original module bytecode. If a GenServer is still alive and receives a message after unload, it calls the original module - which may be a GenServer that isn't running in tests:

```
** (stop) exited in: GenServer.call(MyApp.Serial, {:request, ...}, 5000)
    ** (EXIT) no process: the process is not alive or there's no process
    currently associated with the given name
```

This is another reason to use Resolve for GenServer dependencies - Resolve gives explicit control over when the revert happens, so you can stop the process first.

### Mock verification

Use the `expect |> to(accepted ...)` form to verify a mock was called:

```elixir
allow(MyApp.Mailer) |> to(accept :send, fn _email -> :ok end)

MyApp.Notifications.send_welcome(user)

expect(MyApp.Mailer) |> to(accepted :send)
```

This is the only context where `expect |> to(...)` is used. For assertions on values, use `subject |> should(matcher)`.

## Block Lifecycle

Each example runs in its own Task process. The execution order for a single example:

1. **Run config before** - the `config.before` from `spec_helper.exs` runs first
2. **Clear let cache** - all cached let values from the previous example are wiped
3. **Register lets** - each `let` in the context is registered as `:todo` (not evaluated yet)
4. **Run befores** - outermost to innermost. Each `before` receives the current `shared` map and can extend it by returning `{:shared, key: value}`
5. **Run the example body** - the `it`/`specify` block executes. Let values are lazily evaluated on first call and memoized for the rest of the example
6. **Run finallies** - innermost to outermost (reverse order of befores). Each `finally` receives the `shared` map
7. **Run config finally** - the `config.finally` from `spec_helper.exs` runs after all user finallies
8. **Unload Meck mocks** - all mocks created by this example's process are unloaded

Befores run outermost first (module-level before, then context-level, then describe-level). Finallies run in the opposite order - innermost first. This means a `finally` at the describe level runs before a `finally` at the module level.

## Shared State

### The `shared` map

`before` blocks communicate with examples and `finally` blocks through a shared map. Return `{:shared, key: value}` from a `before` to add entries:

```elixir
before do
  {:ok, pid} = MyApp.Server.start_link(nil)

  {:shared, pid: pid}
end

it "is alive" do
  shared.pid |> should(be_alive())
end

finally do
  if shared[:pid] && Process.alive?(shared[:pid]),
    do: GenServer.stop(shared[:pid])
end
```

The return value must be `{:shared, keyword_or_map}` or `{:ok, keyword_or_map}` - both update the shared map. Any other return value (including bare `:ok`, a plain value, or `nil`) is silently ignored. Prefer `{:shared, ...}` for clarity - it signals the intent to share state. `{:ok, ...}` also works but reads like a success tuple, which can be confusing.

### Shared state accumulates across befores

Each `before` block receives the shared map built by all previous befores. An inner before sees everything set by outer befores:

```elixir
before do
  {:ok, pid} = MyApp.Server.start_link(nil)

  {:shared, pid: pid}
end

context "with a connection" do
  before do
    conn = MyApp.Server.connect(shared.pid)

    {:shared, conn: conn}
  end

  # shared has both :pid and :conn here
  it "can send a message" do
    MyApp.Server.send(shared.conn, "hello")
  end
end
```

## `let` and `let!`

### `let` - lazy, memoized

`let` defines a named value that is evaluated lazily on first call and memoized for the duration of the example. It resets between examples.

```elixir
let :channel, do: 0
let :address, do: 0x0010

it "uses the let values" do
  channel() |> should(eq 0)
  address() |> should(eq 0x0010)
end
```

Call `let`-defined values as zero-arity functions: `channel()`, `address()`.

### `let!` - eager

`let!` is syntactic sugar for `let` + a `before` that calls the accessor. The value is evaluated during the before phase, not lazily:

```elixir
# these are equivalent:
let! :server, do: MyApp.Server.start_link(nil)

# expands to:
let :server, do: MyApp.Server.start_link(nil)
before do: server()
```

Use `let!` when the value must exist before the example runs (e.g. starting a process that other befores depend on).

### Let values see the shared map

When a let block evaluates, it has access to the shared map from all completed befores. Since let evaluation is lazy (happens during the example body), the shared map is the final state after all befores have run:

```elixir
before do
  {:shared, base_address: 0x0010}
end

let :address, do: shared.base_address + channel()
let :channel, do: 0

it "computes address from shared state and other lets" do
  address() |> should(eq 0x0010)
end
```

### Shadowing

An inner `let` with the same name as an outer `let` shadows it for all examples in the inner scope. The last registration wins:

```elixir
let :response, do: {:ok, [0, 100]}

describe "when the request fails" do
  let :response, do: {:error, :timeout}

  it "uses the inner let" do
    response() |> should(eq {:error, :timeout})
  end
end

it "uses the outer let" do
  response() |> should(eq {:ok, [0, 100]})
end
```

## Shared Examples

### Defining shared examples

A shared module uses `use ESpec, shared: true`. It can contain `before`, `finally`, `let`, `let_overridable`, and `it` blocks:

```elixir
defmodule HardwareStub do
  use ESpec, shared: true

  let_overridable \
    hardware_response: {:ok, [0, 100]}

  before do
    test_pid = self()
    response = hardware_response()

    Resolve.inject(MyApp.Hardware, quote do
      def request(_command) do
        send(unquote(test_pid), :hardware_called)
        unquote(Macro.escape(response))
      end
    end)
  end

  finally do
    Resolve.revert(MyApp.Hardware)
  end

  it "calls the hardware" do
    assert_receive :hardware_called
  end
end
```

### `let_overridable`

`let_overridable` works like `let` but marks the value as overridable when included via `include_examples`. It is only valid inside shared modules:

```elixir
# in the shared module
let_overridable \
  hardware_response: {:ok, [0, 100]}

# when including - override the default
include_examples(HardwareStub,
  hardware_response: {:error, :timeout}
)
```

### `include_examples` / `it_behaves_like`

These are aliases for the same macro. When called:

1. Override lets are defined in the current scope from the keyword list
2. Each shared example's context (befores, finallies, lets) is merged with the current context
3. Shared `it` blocks are re-registered as runnable examples in the current module

**Critical detail:** shared `before`/`finally` blocks only apply to `it` blocks defined inside the shared module. They do NOT apply to `it` blocks in the calling context. If the shared module has no `it` blocks, its `before`/`finally` blocks are never executed.

### Alternative: module-level before with `let` overrides

When `include_examples` is not needed (no shared `it` blocks), use module-level `before`/`finally` with describe-level `let` overrides:

```elixir
before do
  test_pid = self()
  response = hardware_response()

  Resolve.inject(MyApp.Hardware, quote do
    def request(_command) do
      send(unquote(test_pid), :hardware_called)
      unquote(Macro.escape(response))
    end
  end)
end

finally do
  Resolve.revert(MyApp.Hardware)
end

describe "when the hardware returns a reading" do
  let :hardware_response, do: {:ok, [0, 100]}

  it "reports the reading" do
    # ...
  end
end

describe "when the hardware fails" do
  let :hardware_response, do: {:error, :timeout}

  it "does not publish a value" do
    # ...
  end
end
```

This works because ESpec registers all lets (including describe-level ones) before running befores. The module-level `before` calls `hardware_response()`, which resolves to the describe-level let's value.

## Scoping

### Lexical, not dynamic

Scoping is determined at compile time by lexical nesting. Each `it`/`specify` block captures a snapshot of all `before`, `finally`, `let`, and `context` blocks that are lexically above it. There is no runtime scope lookup.

### `describe` and `context` are identical

Both expand to the same `context` macro. They create a `%ESpec.Context{}` struct with a description string. The only difference is naming convention (style, not mechanics).

### A before at module level applies to all examples

```elixir
defmodule MyApp.Spec do
  use ESpec, async: false

  before do
    # runs before EVERY example in this module
  end

  describe "scenario A" do
    it "sees the module before"
  end

  describe "scenario B" do
    it "also sees the module before"
  end
end
```

### A before inside describe applies only to examples in that describe

```elixir
describe "scenario A" do
  before do
    # only runs for examples inside this describe
  end

  it "sees this before"
end

it "does NOT see the describe's before"
```

## `quote`/`unquote` with `let` Values

`let` values are runtime function calls. They cannot be used directly inside `quote do` blocks because `quote` captures AST, not runtime values. Capture to a local variable first:

```elixir
let :response, do: {:ok, [0, 100]}

before do
  response = response()

  Resolve.inject(MyApp.Hardware, quote do
    def request(_command) do
      unquote(Macro.escape(response))
    end
  end)
end
```

`Macro.escape/1` is required when the value is not valid Elixir AST. 2- and 3-element tuples are valid AST nodes. Tuples with 4+ elements require `Macro.escape`. When in doubt, use `Macro.escape` - it is safe on all values.

See `elixir/resolve_mechanics.md` for the full pattern including test pid capture.
