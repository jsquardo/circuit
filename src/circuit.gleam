import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

/// Represents the three states a circuit breaker can be in.
///
/// - `Closed` — normal operation. Calls pass through and results are tracked.
/// - `Open` — tripped state. All calls are blocked immediately and return `Error(CircuitOpen)`.
/// - `HalfOpen` — recovery probe state. A single call is allowed through to test
///   whether the downstream service has recovered. Success closes the circuit;
///   failure trips it back to `Open`.
pub type CircuitState {
  Closed
  Open
  HalfOpen
}

/// Configuration for a circuit breaker.
///
/// Use `new/0` and the builder functions to construct a `Config` rather than
/// using this constructor directly.
pub type Config {
  Config(failure_threshold: Int, window_size: Int, reset_timeout: Int)
}

/// Returns a `Config` with sensible production defaults:
///
/// - `failure_threshold`: 5
/// - `window_size`: 10
/// - `reset_timeout`: 30_000ms (30 seconds)
///
/// These defaults are a reasonable starting point. Tune them for your workload
/// using `failure_threshold/2`, `window_size/2`, and `reset_timeout/2`.
///
/// ## Example
///
/// ```gleam
/// let config =
///   circuit.new()
///   |> circuit.failure_threshold(3)
///   |> circuit.window_size(5)
///   |> circuit.reset_timeout(10_000)
/// ```
pub fn new() -> Config {
  Config(failure_threshold: 5, window_size: 10, reset_timeout: 30_000)
}

/// Sets the number of failures within the sliding window required to trip the
/// circuit from `Closed` to `Open`.
///
/// A lower value makes the breaker more sensitive. A higher value tolerates
/// more failures before tripping.
pub fn failure_threshold(config: Config, value: Int) -> Config {
  Config(..config, failure_threshold: value)
}

/// Sets the size of the sliding window — the number of most recent calls that
/// are tracked when calculating the failure rate.
///
/// For example, a `window_size` of 10 means only the last 10 call results are
/// considered. Older results are discarded automatically.
pub fn window_size(config: Config, value: Int) -> Config {
  Config(..config, window_size: value)
}

/// Sets how long (in milliseconds) the circuit stays `Open` before
/// transitioning to `HalfOpen` to probe for recovery.
///
/// A shorter timeout means faster recovery attempts. A longer timeout gives
/// the downstream service more time to recover before being probed.
pub fn reset_timeout(config: Config, value: Int) -> Config {
  Config(..config, reset_timeout: value)
}

/// The result of a single call through the circuit breaker.
///
/// Pass one of these to `record_result/2`, or return one from the function
/// you pass to `call/2`.
///
/// - `Success` — the call succeeded.
/// - `Failure(reason)` — the call failed, with a string describing why.
pub type CallResult {
  Success
  Failure(reason: String)
}

pub type Message {
  RecordResult(CallResult)
  GetState(Subject(CircuitState))
  Reset
}

pub type ActorState {
  ActorState(
    circuit_state: CircuitState,
    window: List(CallResult),
    config: Config,
  )
}

/// The error type returned by `call/2`.
///
/// - `CircuitOpen` — the circuit is currently `Open` and the call was blocked
///   without executing the function.
/// - `CallFailed(reason)` — the circuit was not open, the function ran, but it
///   returned `Failure(reason)`.
pub type CallError {
  CircuitOpen
  CallFailed(reason: String)
}

/// An opaque handle to a running circuit breaker process.
///
/// Obtain one via `start/1`. Pass it to `call/2`, `state/1`, `reset/1`, and
/// `record_result/2`. The internals (actor `Subject`, message protocol) are
/// hidden — interact with the breaker only through the public API.
pub opaque type CircuitBreaker {
  CircuitBreaker(subject: Subject(Message))
}

pub fn transition(
  state: CircuitState,
  result: CallResult,
  failures: Int,
  config: Config,
) -> CircuitState {
  case state, result {
    Closed, Failure(_) if failures >= config.failure_threshold -> Open
    Closed, _ -> Closed
    Open, _ -> Open
    HalfOpen, Success -> Closed
    HalfOpen, Failure(_) -> Open
  }
}

fn handle_message(
  state: ActorState,
  message: Message,
) -> actor.Next(ActorState, Message) {
  case message {
    RecordResult(result) -> {
      let new_window =
        list.take([result, ..state.window], state.config.window_size)
      let failure_count =
        list.count(new_window, fn(r) {
          case r {
            Failure(_) -> True
            Success -> False
          }
        })
      let new_circuit_state =
        transition(state.circuit_state, result, failure_count, state.config)
      actor.continue(
        ActorState(
          ..state,
          circuit_state: new_circuit_state,
          window: new_window,
        ),
      )
    }
    GetState(subject) -> {
      process.send(subject, state.circuit_state)
      actor.continue(state)
    }
    Reset ->
      actor.continue(ActorState(..state, circuit_state: Closed, window: []))
  }
}

/// Starts a new circuit breaker process with the given `Config`.
///
/// Returns `Ok(CircuitBreaker)` on success, or `Error(actor.StartError)` if
/// the underlying OTP actor fails to start.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(breaker) =
///   circuit.new()
///   |> circuit.failure_threshold(5)
///   |> circuit.start()
/// ```
pub fn start(config: Config) -> Result(CircuitBreaker, actor.StartError) {
  let initial_state =
    ActorState(circuit_state: Closed, window: [], config: config)
  case
    actor.new(initial_state) |> actor.on_message(handle_message) |> actor.start
  {
    Ok(started) -> Ok(CircuitBreaker(subject: started.data))
    Error(e) -> Error(e)
  }
}

/// Returns the current `CircuitState` of the breaker (`Closed`, `Open`, or `HalfOpen`).
///
/// This is a synchronous call to the actor — it blocks briefly until the actor
/// responds.
pub fn state(breaker: CircuitBreaker) -> CircuitState {
  process.call(breaker.subject, 100, GetState)
}

/// Manually resets the breaker to `Closed` and clears the sliding window.
///
/// Useful in tests or admin tooling. In normal operation the breaker manages
/// its own state — you should rarely need to call this directly.
pub fn reset(breaker: CircuitBreaker) -> Nil {
  process.send(breaker.subject, Reset)
}

/// Records a `CallResult` against the breaker without running a function.
///
/// Use this when you are managing the call yourself and just want to inform
/// the breaker of the outcome. For the common case of wrapping a function,
/// prefer `call/2` instead.
pub fn record_result(breaker: CircuitBreaker, result: CallResult) -> Nil {
  process.send(breaker.subject, RecordResult(result))
}

/// Runs `f` through the circuit breaker and records its result.
///
/// - If the circuit is `Open`, `f` is **not called** and `Error(CircuitOpen)` is
///   returned immediately.
/// - If the circuit is `Closed` or `HalfOpen`, `f` is called. A `Success` result
///   returns `Ok(Nil)`. A `Failure(reason)` result returns `Error(CallFailed(reason))`.
///   Either way, the result is automatically recorded against the sliding window.
///
/// ## Example
///
/// ```gleam
/// case circuit.call(breaker, fn() {
///   case fetch_user(id) {
///     Ok(_) -> circuit.Success
///     Error(_) -> circuit.Failure("fetch failed")
///   }
/// }) {
///   Ok(Nil) -> // call succeeded
///   Error(circuit.CircuitOpen) -> // blocked — try a fallback
///   Error(circuit.CallFailed(reason)) -> // call ran but failed
/// }
/// ```
pub fn call(
  breaker: CircuitBreaker,
  f: fn() -> CallResult,
) -> Result(Nil, CallError) {
  case state(breaker) {
    Open -> Error(CircuitOpen)
    _ -> {
      let result = f()
      record_result(breaker, result)
      case result {
        Success -> Ok(Nil)
        Failure(reason) -> Error(CallFailed(reason))
      }
    }
  }
}
