import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

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

pub fn start(config: Config) -> Result(Subject(Message), actor.StartError) {
  let initial_state =
    ActorState(circuit_state: Closed, window: [], config: config)
  case
    actor.new(initial_state) |> actor.on_message(handle_message) |> actor.start
  {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}
