<h1 align="center">circuit</h1>

<div align="center">

<img src="/public/g55.svg" alt="circuit logo" height="180" />

<br/>

**Prevent cascading failures in your Gleam applications. Circuit breaker pattern with sliding window tracking, OTP-supervised state, and support for both Erlang and JavaScript targets.**

<br/>

[![Package Version](https://img.shields.io/hexpm/v/circuit?style=flat-square&color=ffaff3&labelColor=1a1a2e)](https://hex.pm/packages/circuit)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3?style=flat-square&labelColor=1a1a2e)](https://hexdocs.pm/circuit/)
[![License](https://img.shields.io/badge/license-MIT-a8d8a8?style=flat-square&labelColor=1a1a2e)](LICENSE)

</div>

---

## What is a circuit breaker?

When a downstream service (an API, a database, a queue) starts failing, naively retrying every call makes things worse — you flood a struggling service and slow your whole application down in the process.

A circuit breaker wraps those calls and watches for failures. After enough failures it **trips open**, blocking calls entirely and returning an error instantly instead of waiting. After a cooldown it allows a single probe call through to check if the service has recovered. If it has, the circuit closes again and normal traffic resumes.

Three states:

| State | Behaviour |
|----------|-----------|
| `Closed` | Normal. Calls pass through, results are tracked. |
| `Open` | Tripped. All calls blocked, `Error(CircuitOpen)` returned immediately. |
| `HalfOpen` | Recovery probe. One call allowed through — success closes, failure re-opens. |

---

## Installation

```sh
gleam add circuit@1
```

---

## Quick Start

```gleam
import circuit

pub fn main() {
  // 1. Configure and start a breaker
  let assert Ok(breaker) =
    circuit.new()
    |> circuit.failure_threshold(5)  // trip after 5 failures
    |> circuit.window_size(10)       // track the last 10 calls
    |> circuit.reset_timeout(30_000) // wait 30s before probing
    |> circuit.start()

  // 2. Wrap your calls
  case circuit.call(breaker, fn() {
    case fetch_user(42) {
      Ok(_user) -> circuit.Success
      Error(_)  -> circuit.Failure("fetch_user failed")
    }
  }) {
    Ok(Nil)                          -> // call succeeded
    Error(circuit.CircuitOpen)       -> // blocked — use a fallback or return cached data
    Error(circuit.CallFailed(reason)) -> // call ran but failed
  }
}
```

That's it. The breaker tracks results, manages state transitions, and runs as a supervised OTP process — no global state, no ETS tables.

---

## API

| Function | Description |
|----------|-------------|
| `new()` | Create a `Config` with default values |
| `failure_threshold(config, n)` | Set failures required to trip (default: 5) |
| `window_size(config, n)` | Set sliding window size (default: 10) |
| `reset_timeout(config, ms)` | Set cooldown before `HalfOpen` probe (default: 30 000ms) |
| `start(config)` | Spawn the breaker actor, returns `Result(CircuitBreaker, _)` |
| `call(breaker, f)` | Run `f` through the breaker, auto-records result |
| `record_result(breaker, result)` | Manually record a `Success` or `Failure` |
| `state(breaker)` | Read the current `CircuitState` |
| `reset(breaker)` | Manually reset to `Closed` and clear the window |

Full documentation: [hexdocs.pm/circuit](https://hexdocs.pm/circuit)

---

## Development

```sh
gleam test  # run the test suite
gleam build # compile and check
```

---

<div align="center">

Made with ♥ using [Gleam](https://gleam.run)

</div>
