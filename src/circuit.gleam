pub type CircuitState {
  Closed
  Open
  HalfOpen
}

pub type Config {
  Config(failure_threshold: Int, window_size: Int, reset_timeout: Int)
}

pub type CallResult {
  Success
  Failure(reason: String)
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
