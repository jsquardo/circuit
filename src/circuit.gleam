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
