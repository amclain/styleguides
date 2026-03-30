# ESpec Mechanics

This file covers how ESpec works mechanically. It is loaded for projects that use ESpec (detected by the Test Framework first-run check). For style rules on writing ESpec tests, see `elixir/testing.md`. For Resolve dependency injection mechanics, see `elixir/resolve_mechanics.md`.

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
