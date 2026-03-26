import circuit.{
  type Config, Closed, Config, Failure, HalfOpen, Open, Success, transition,
  start, GetState, RecordResult,
}
import gleam/erlang/process
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
  let assert Ok(subject) = start(default_config())
  let state = process.call(subject, 100, GetState)
  assert state == Closed
}

// Actor trips to Open after enough failures
pub fn actor_trips_to_open_test() {
  let assert Ok(subject) = start(default_config())
  process.send(subject, RecordResult(Failure("err")))
  process.send(subject, RecordResult(Failure("err")))
  process.send(subject, RecordResult(Failure("err")))
  let state = process.call(subject, 100, GetState)
  assert state == Open
}
