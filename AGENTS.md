# circuit — Gleam Learning Project

## Purpose
This is a learning project. Johnny is learning how to build a real-world Gleam
library by implementing a circuit breaker from scratch. This is not a code dump
project — it is a tutoring session that persists across breaks.

---

## Tutor Rules (always follow these)
- Before writing any code, explain what we're about to do in plain English and why
- Write no more than 10–15 lines at a time
- After each chunk, explain: what Gleam concept did we just use? What should Johnny
  understand before continuing?
- If something could have been written differently, show the tradeoff
- Ask Johnny a question before moving to the next step
- When resuming a session, read this file and summarize where we left off before
  doing anything else

---

## Project: circuit
A type-safe, actor-backed circuit breaker library for Gleam, to be published on
hex.pm. Targets both Erlang and JavaScript runtimes.

### What a circuit breaker is (context for the tutor)
A circuit breaker wraps calls to external services (APIs, databases, etc.) and
monitors for failures. After enough failures it "trips" — stopping calls entirely
and returning an error immediately. After a cooldown it lets a few probe calls
through to test recovery. Three states: Closed (normal), Open (tripped), HalfOpen
(testing recovery). State lives in a Gleam OTP actor so it is isolated, supervised,
and concurrent-safe.

### Phase overview
- [ ] Phase 1 — Project setup and core types (CircuitState, Config, CallResult)
- [ ] Phase 2 — The state machine (transitions between Closed/Open/HalfOpen)
- [ ] Phase 3 — The actor (wrapping state machine in an OTP process)
- [ ] Phase 4 — The sliding window (tracking failures over time, not just a counter)
- [ ] Phase 5 — The public API (start, call, record_failure, reset, state)
- [ ] Phase 6 — Tests
- [ ] Phase 7 — Polish and publish to hex.pm

---

## Current status

**Active phase:** Phase 1 — Not started yet

**Last session:** N/A

**What we've built so far:**
- Nothing yet — fresh project

**Next step:** Run `gleam new circuit` to initialize the project, then open
AGENTS.md and start Phase 1.

---

## Key design decisions (established before coding began)
- **Algorithm:** Sliding window — tracks failure rate over last N calls, not a
  simple total counter. More useful in production, avoids the "4 failures after
  reset" blind spot.
- **State storage:** Gleam OTP actor — each circuit breaker is a supervised
  process with isolated state. No global ETS tables. Idiomatic Gleam.
- **Targets:** Erlang and JavaScript both. Design the actor abstraction with this
  in mind from the start.
- **API surface:** Small and intentional — inspired by Erlang's `fuse` library.
  Five core functions: `start`, `call`, `record_failure`, `reset`, `state`.
- **Builder pattern for config:** Pipeline-style setup like glimit uses, which is
  idiomatic in the Gleam ecosystem.

---

## Johnny's understanding

### Solid on (from Queuey project)
- Libraries vs programs (no `main`, just types and functions)
- `pub` keyword for visibility
- Type parameters (`Queue(a)` — `a` is whatever the caller decides)
- Immutability — functions produce new values, don't modify old ones
- Variable shadowing with `let q =` multiple times
- `Option` — `Some(value)` vs `None`
- Tuples with `#()`
- `case` as pattern matching (not just switch — destructures data simultaneously)
- Spread operator `[item, ..rest]`
- Tail recursion and accumulator pattern
- Higher-order functions (`map`, `filter`, `fold`)
- Internal vs external representation
- Functions as arguments (`fn(a) -> b` type syntax)
- `@external` for Erlang interop (used in benchmark)

### New concepts this project will introduce
- OTP actors (`gleam/otp/actor`) — supervised stateful processes
- `Subject` — how you talk to an actor
- Message types for actor communication
- `Result` type (vs `Option` — errors with info, not just None)
- Custom error types
- Ring buffer / circular data structure (for sliding window)
- `gleam_erlang` process primitives
- Publishing a library with multiple modules

### Needs more time (carried over from Queuey)
- Writing recursive functions from scratch independently
- O(n) vs O(1) intuition — still developing

### Open questions from last session
(none — fresh project)

---

## Session log

### Session template (copy this when updating)
**Date:** YYYY-MM-DD
**Covered:**
**Concepts introduced:**
**Johnny seemed solid on:**
**Needs reinforcement:**
**Stopped at:**
**Next step:**

---

## How to resume
At the start of each new session, tell Claude Code:

> "Read AGENTS.md to get context on where we left off, then summarize
> what we've done and ask if I'm ready to continue."

At the end of each session, tell Claude Code:

> "Update AGENTS.md — fill in today's session log entry, update the
> current status section, and note anything I struggled with or asked
> about."
