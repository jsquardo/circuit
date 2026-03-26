import circuit.{
  type Config, Closed, Config, Failure, HalfOpen, Open, Success, transition,
  start, state, record_result, call, CircuitOpen, CallFailed,
}
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

fn default_config() -> Config {
  Config(failure_threshold: 3, window_size: 10, reset_timeout: 5000)
}

// Closed + failure below threshold stays Closed
pub fn closed_stays_closed_on_failure_below_threshold_test() {
  let result = transition(Closed, Failure("timeout"), 1, default_config())
  assert result == Closed
}

// Closed + failure at threshold trips to Open
pub fn closed_trips_to_open_at_threshold_test() {
  let result = transition(Closed, Failure("timeout"), 3, default_config())
  assert result == Open
}

// Closed + success stays Closed
pub fn closed_stays_closed_on_success_test() {
  let result = transition(Closed, Success, 0, default_config())
  assert result == Closed
}

// Open ignores everything and stays Open
pub fn open_stays_open_test() {
  let result = transition(Open, Success, 0, default_config())
  assert result == Open
}

// HalfOpen + success recovers to Closed
pub fn half_open_recovers_on_success_test() {
  let result = transition(HalfOpen, Success, 0, default_config())
  assert result == Closed
}

// HalfOpen + failure trips back to Open
pub fn half_open_trips_back_on_failure_test() {
  let result = transition(HalfOpen, Failure("timeout"), 1, default_config())
  assert result == Open
}

// Actor starts in Closed state
pub fn actor_starts_in_closed_state_test() {
  let assert Ok(breaker) = start(default_config())
  assert state(breaker) == Closed
}

// Actor trips to Open after enough failures
pub fn actor_trips_to_open_test() {
  let assert Ok(breaker) = start(default_config())
  record_result(breaker, Failure("err"))
  record_result(breaker, Failure("err"))
  record_result(breaker, Failure("err"))
  assert state(breaker) == Open
}

// call returns Ok on success
pub fn call_returns_ok_on_success_test() {
  let assert Ok(breaker) = start(default_config())
  let result = call(breaker, fn() { Success })
  assert result == Ok(Nil)
}

// call returns CallFailed on failure
pub fn call_returns_error_on_failure_test() {
  let assert Ok(breaker) = start(default_config())
  let result = call(breaker, fn() { Failure("timeout") })
  assert result == Error(CallFailed("timeout"))
}

// call returns CircuitOpen when breaker is open
pub fn call_blocked_when_open_test() {
  let assert Ok(breaker) = start(default_config())
  record_result(breaker, Failure("err"))
  record_result(breaker, Failure("err"))
  record_result(breaker, Failure("err"))
  let result = call(breaker, fn() { Success })
  assert result == Error(CircuitOpen)
}
