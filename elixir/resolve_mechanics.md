# Resolve Mechanics

Resolve is a dependency injection library for Elixir. It replaces module references at compile time or runtime, allowing different implementations to be swapped in per target, environment, or test without changing the source code's call structure.

This file covers how Resolve works mechanically. For style rules on writing tests with Resolve, see `elixir/testing.md`.

## Source Code Setup

Add `use Resolve` to any module that needs injectable dependencies. This defines a `resolve/1` delegate function in the module:

```elixir
defmodule MyApp.Sensor do
  use GenServer
  use Resolve

  defp read_hardware do
    resolve(MyApp.Serial).request({:read, @slave_id, @register, 2})
  end
end
```

`resolve(MyApp.Serial)` returns `MyApp.Serial` when no dependency is mapped to that module. Dependencies can be mapped two ways: compile-time mappings in config (the standard approach for production and development) or runtime injection via `Resolve.inject` (for unit testing).

## How It Works

Resolve has two modes: **compile-time** for production and development, and **runtime** (default) for unit testing. Compile-time mode resolves dependencies to a static map at compile time with no runtime overhead. Runtime mode checks a global ETS table, allowing each test to swap real modules with mocks via `Resolve.inject`.

Runtime lookup precedence:
1. ETS entry (set by `Resolve.inject` at test time) - highest priority
2. Compile-time mappings from config (`:resolve, mappings:`) - fallback
3. Original module (identity) - default

The ETS table is created lazily on first use. There is no supervised process.

## Configuration

Define compile-time mappings in config files. This is the standard approach for production and development - each target or environment maps modules to the appropriate implementation:

```elixir
# good - only map modules that need a different implementation
# config/target/gate.exs
config :resolve,
  compile: true,
  mappings: [
    {MyApp.Serial, MyApp.Serial.Uart},
  ]

# good - host uses virtual implementation
# config/host.exs
config :resolve,
  compile: true,
  mappings: [
    {MyApp.Serial, MyApp.Serial.Virtual},
  ]

# avoid - listing modules that resolve to themselves
config :resolve,
  compile: true,
  mappings: [
    {MyApp.Sensor, MyApp.Sensor},
    {MyApp.Controller, MyApp.Controller},
  ]
```

When `compile: true`, `resolve/1` is a compile-time map lookup - no ETS, no runtime cost. Runtime injection via `Resolve.inject` is not available. Only modules that need a different implementation need to be listed in `mappings` - any module not in the map resolves to itself.

For unit testing, use the default configuration (`compile: false`) - no config entry needed. This enables runtime injection via `Resolve.inject`.

## Injection API

### `Resolve.inject(module, quoted_code)`

Replaces `module` in all `resolve/1` lookups with a dynamically created module containing the quoted code:

```elixir
Resolve.inject(MyApp.Serial, quote do
  def request(command) do
    {:ok, [0, 100]}
  end
end)
```

This creates a unique anonymous module (e.g. `:"Mock12345"`) from the quoted AST via `Module.create/3`, then inserts `{MyApp.Serial, :"Mock12345"}` into ETS.

### `Resolve.inject(module, replacement_module)`

Replaces `module` with an existing module atom:

```elixir
Resolve.inject(MyApp.Serial, MyApp.Serial.Mock)
```

### `Resolve.revert(module)`

Removes the ETS entry for `module`, restoring `resolve/1` to return the original module. Idempotent - safe to call even if no injection exists:

```elixir
Resolve.revert(MyApp.Serial)
```

## Visibility

Resolve injections are **global** - visible to all processes on the BEAM node. When a GenServer calls `resolve(MyApp.Serial).request(...)` in its own process, it sees the injection made by the test process.

Meck is also global (it replaces module bytecode), but ESpec manages Meck mocks per-example - setting them up before each test and unloading them after. This means the mock lifetime is tied to ESpec's example lifecycle. Resolve's ETS-based approach gives explicit control over when the swap happens and when it reverts, independent of the test framework's lifecycle. This makes Resolve better suited for GenServer dependencies where you need the mock to persist across GenServer callbacks within a single test, and need to control revert timing relative to process cleanup.

### Why not Meck for GenServer dependencies?

When a Meck mock runs inside a GenServer callback, `self()` returns the GenServer's pid - not the test process. A mock that uses `send(self(), :signal)` sends the message to the GenServer's mailbox. The test's `assert_receive` never sees it - a silent failure that manifests as a timeout:

```elixir
# avoid - send(self()) inside Meck mock goes to GenServer, not test
allow(MyApp.Serial) |> to(accept :request, fn _cmd ->
  send(self(), {:serial_request, :called})
  {:ok, [0, 100]}
end)

{:ok, pid} = MyApp.Sensor.start_link(nil)
send(pid, :poll)

# This times out - the message went to the GenServer's mailbox
assert_receive {:serial_request, :called}
```

Resolve avoids this by baking the test pid into the mock at definition time via `unquote`:

```elixir
# good - test pid is explicit, not dependent on calling process
test_pid = self()

Resolve.inject(MyApp.Serial, quote do
  def request(command) do
    send(unquote(test_pid), {:serial_request, command})
    {:ok, [0, 100]}
  end
end)
```

A secondary issue is cleanup timing. ESpec unloads Meck mocks after each example, restoring the original module. If the GenServer is still alive and receives a message after unload, it calls the real module - which may be a GenServer that isn't running in tests:

```
** (stop) exited in: GenServer.call(MyApp.Serial, {:request, ...}, 5000)
    ** (EXIT) no process: the process is not alive or there's no process
    currently associated with the given name
```

With Resolve, the injection persists until explicitly reverted, and you control the ordering:

```elixir
# good - Resolve injection persists until you revert it
before do
  test_pid = self()

  Resolve.inject(MyApp.Serial, quote do
    def request(command) do
      send(unquote(test_pid), {:serial_request, command})
      {:ok, [0, 100]}
    end
  end)

  {:ok, pid} = MyApp.Sensor.start_link(nil)

  {:shared, pid: pid}
end

finally do
  # Stop the GenServer first, then revert - no window for :noproc
  if shared[:pid] && Process.alive?(shared[:pid]),
    do: GenServer.stop(shared[:pid])

  Resolve.revert(MyApp.Serial)
end
```

## Test Patterns

### Basic injection with test message capture

Capture the test process pid before the `quote` block. Inside `quote`, use `unquote` to splice it into the injected function:

```elixir
before do
  test_pid = self()

  Resolve.inject(MyApp.Serial, quote do
    def request(command) do
      send(unquote(test_pid), {:serial_request, command})
      {:ok, [0, 100]}
    end
  end)

  {:ok, pid} = MyApp.Sensor.start_link(nil)

  {:shared, pid: pid}
end

finally do
  Resolve.revert(MyApp.Serial)
end
```

### Using `let` values in injected code

`let` values are runtime function calls and cannot be used directly inside `quote do` blocks. Capture them to local variables first, then `unquote` the local variables:

```elixir
let :response, do: {:ok, [0, 100]}

before do
  test_pid = self()
  response = response()

  Resolve.inject(MyApp.Serial, quote do
    def request(command) do
      send(unquote(test_pid), {:serial_request, command})
      unquote(Macro.escape(response))
    end
  end)
end
```

`Macro.escape/1` is required when the value is not valid Elixir AST. Elixir AST nodes are 2- and 3-element tuples, so those work with bare `unquote`. Atoms, integers, strings, and lists of AST-safe values also work. Tuples with 4+ elements (e.g. `{:rhr, 1, 0, 2}`) are not valid AST and require `Macro.escape`. When in doubt, use `Macro.escape` - it is safe on all values.

### Revert ordering in `finally`

Stop processes that use the injected module **before** reverting the injection. If the process receives a message after revert (e.g. a PropertyTable cleanup event), it will call `resolve(Module)` and get the real module back - which may not be running, causing `:noproc`:

```elixir
# good - stop process first, then revert
finally do
  if shared[:pid] && Process.alive?(shared[:pid]),
    do: GenServer.stop(shared[:pid])

  Resolve.revert(MyApp.Serial)
end

# bad - revert first, process may still receive messages
finally do
  Resolve.revert(MyApp.Serial)
end
```

### Multiple injections

Each `Resolve.inject` call is independent. Inject and revert each module separately:

```elixir
before do
  test_pid = self()

  Resolve.inject(MyApp.Serial, quote do
    def connect(_opts), do: {:ok, :test_master}

    def request(:test_master, command) do
      send(unquote(test_pid), {:request, command})
      {:ok, [0, 100]}
    end
  end)
end

finally do
  Resolve.revert(MyApp.Serial)
end
```

Multiple functions can be defined in a single injection. The injected module replaces all public functions of the target - any function not defined in the injection will raise `UndefinedFunctionError` if called.

### Erlang module injection

Resolve works with Erlang modules (atoms) the same way as Elixir modules:

```elixir
Resolve.inject(:file, quote do
  def open('/dev/mtd0', _opts), do: {:ok, make_ref()}
  def pread(_io_device, _location, _number), do: {:ok, "data"}
end)
```

In production code: `resolve(:emqtt).start_link(opts)`.

### Re-injection

Calling `inject` again on the same module replaces the previous injection. This is useful for simulating state changes mid-test (e.g. time advancing):

```elixir
Resolve.inject(DateTime, quote do
  def now!(timezone), do: DateTime.new!(~D[2023-01-01], ~T[17:59:59], timezone)
end)

send(pid, :check_schedule)
assert_receive :not_yet

Resolve.inject(DateTime, quote do
  def now!(timezone), do: DateTime.new!(~D[2023-01-01], ~T[18:00:01], timezone)
end)

send(pid, :check_schedule)
assert_receive :triggered
```

### Stateful mocks via Agent

When a mock needs to return different values on successive calls, use a named Agent inside the injected code:

```elixir
before do
  {:ok, _} = Agent.start(fn -> 0 end, name: :call_counter)

  Resolve.inject(MyApp.Hardware, quote do
    def read_sensor do
      Agent.get_and_update(:call_counter, fn
        0 -> {{:ok, 100}, 1}
        1 -> {{:ok, 200}, 2}
        _ -> {{:error, :timeout}, :done}
      end)
    end
  end)
end

finally do
  Agent.stop(:call_counter)
  Resolve.revert(MyApp.Hardware)
end
```

Named agents are global - accessible inside the dynamically-created module, but must be stopped in `finally` to prevent leaking into subsequent tests.

### Injection scope

**There is no automatic cleanup.** Resolve has no ESpec integration and ESpec does not touch the Resolve ETS table between examples. An injection that is not explicitly reverted persists in ETS for the entire test run.

Always pair injections with `Resolve.revert` in a `finally` block. Since `Resolve.revert` is idempotent, this is safe even when injections happen per-test or are overwritten by re-injection. The `finally` block ensures cleanup regardless of whether the test passes or fails.

## When to Use Resolve vs Meck

| | Resolve | Meck (via ESpec) |
|---|---|---|
| Mechanism | ETS table lookup | Module bytecode replacement |
| Reliability in GenServer callbacks | Always works | May return original value (passthrough/timing issues) |
| Revert control | Explicit (`Resolve.revert`) | Automatic per-example in ESpec |
| Use when | Dependency called from GenServer callbacks | Dependency called from test-synchronous code paths |
| Syntax | `Resolve.inject(Module, quote do ... end)` | `allow(Module) \|> to(accept :function, fn ... end)` |
| Multiple functions | Define all in one `quote do` block | One `allow \|> to(accept ...)` per function |

**Rule of thumb:** Use Resolve for modules called from inside GenServer callbacks (`handle_call`, `handle_info`, `handle_continue`, etc.) where timing is hard to control. Use Meck (via ESpec's `allow`/`accept`) for modules called from code paths triggered synchronously by the test (e.g. the test calls a public API function and waits for the result).
