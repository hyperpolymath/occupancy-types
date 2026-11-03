<!--
SPDX-License-Identifier: CC-BY-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-->
# OPERATIONAL-MODEL — occupancy-types Session IR (v0)

Status: ULTRAPLAN R0-B, Phase 0. Paired with Phase 1 artefacts in
`src/julia/` and examples in `examples/session_ir/`. The current v0 stepper is
the Julia implementation. Plan of record: `ULTRAPLAN.md` at the repo root.

This document fixes what the grade *means*, what memory *means*, and what the
model deliberately does **not** read. If a claim about the checker cannot be
reduced to this document plus the code, it is not a claim of this project.

## 1. Machine configuration

A closed program runs on a deterministic machine with four components:

| Component | Contents | Discipline |
|-----------|----------|------------|
| Heap | linear buffers `Buf n` (n bytes) | explicit `drop` only; no GC, no implicit copy |
| Channels | pairs of endpoints created by `new S`, each side with a FIFO queue of events (`msg v`, `sel l`) | events drain in order; `close` requires the endpoint at `End` |
| Threads | one thread of control (a single term; `let` sequences everything) | binary sessions only — two endpoints of `new`, used by one program |
| Clock | communication steps: `send`, `recv`, `select`, `case` each count 1 | the only cost axis in v0 |

The machine is deterministic: closed programs reduce along exactly one path.
A stepper (`src/julia/src/Machine.jl`) reduces a checked program, counts
communication steps, and records operational statistics (peak live bytes,
peak in-flight channel events). Machine-level faults (`R_*` codes) are
self-checks: they fire loudly if the checker and the machine ever disagree,
and are unreachable for accepted programs except the deliberate deadlock
detector (`R_DEADLOCK` when a `recv`/`case` runs with nothing in flight —
possible in principle for ill-ordered single-threaded code, never in the
shipped examples).

## 2. Grade meaning — communication steps in max-plus

The judgment is `Γ ⊢ e : A | r` where `r` is the **communication-step count**:
an upper bound on the number of `send`/`recv`/`select`/`case` actions any run
of `e` can perform. The grade carrier is ℕ (v0 has no recursion, so no ∞ is
needed; `∞` remains the designated value for unbounded protocols if recursion
is ever admitted — currently a rejection, per ULTRAPLAN D6).

Grades form the max-plus semiring (ℕ, max, +, 0), exposed as the
`MaxPlus` module in `src/julia/src/Syntax.jl`: `op_add = max` (choice),
`op_mul = +` (sequence), `zero = one = 0`. The six typing-rule shapes are
expressed only in terms of it:

| Term former | Grade rule |
|-------------|------------|
| `unit`, `alloc n`, `new S` | 0 |
| `drop e`, `close ep` | 0 + r(sub) |
| `pair e1 e2`, `letpair …`, `let … = e1 in e2` | r₁ + r₂ (sequence) |
| `send ep v`, `recv ep`, `select l ep` | 1 + r(subterms) |
| `case ep {li: xi. ei}` | 1 + maxᵢ r(eᵢ) (alternatives) |

Soundness obligation (checked on every accepted example by the stepper):
**measured steps ≤ certified r**. A violation is a stop-and-ledger event
(ULTRAPLAN §6.2). The reported `certified/measured` ratio is the tightness
reading; it is 1.00 when the expensive path is taken and > 1 when the program
takes a cheaper branch than the worst case — worst-case-by-construction.

### 2.1 Kill test: why choice is max and sequence is +

The Phase 0 kill test: explain ⊕ = max, ⊗ = + in four sentences without the
word "tropical". This block is machine-audited by
`julia scripts/kill-test-audit.jl` (also run by `scripts/check.sh`; exactly
four sentences, with the banned word absent):

<!-- KILL-TEST-BEGIN -->
When a program may take any one of several branches, the number we can honestly promise is the number from the most expensive branch, because we cannot rule that branch out.
When one action must finish before the next begins, both costs definitely happen and they accumulate, so sequencing combines grades with addition.
Doing nothing costs 0, the identity for both combinators on the grade carrier ℕ, while ∞ would mark the unbounded and is absorbing for addition.
Because every term former maps to only these two combinators, a checker computes the worst-case grade compositionally from the syntax alone, without running the program or solving equations.
<!-- KILL-TEST-END -->

## 3. Memory meaning — linear uniqueness, not GC

* `Buf n` has exactly one owner at every program point. Ownership moves
  (delegation via `send`), it is never duplicated. Aliasing (`pair ep ep`,
  double `let`-binding of one handle) is a type error (`E_ALIAS`).
* **Explicit drop for Buf, explicit close for endpoints; both consume**
  (ULTRAPLAN D5). Dropping twice is `E_DOUBLE_FREE`; using a dropped buffer or
  a closed endpoint is `E_USE_AFTER_DROP`; closing before `End` is
  `E_CLOSE_NOT_END`; ending the program with any linear name alive is
  `E_LEAK`.
* The invariant (ULTRAPLAN Phase 1): **each `Buf` and endpoint appears exactly
  once in the linear context or is consumed.** Unrestricted `Unit` names may be
  ignored or shadowed; linear names may not.
* Live memory is *counted*, not graded, in v0: the stepper reports peak live
  bytes (high-water mark of allocated-minus-dropped buffers) and peak in-flight
  channel events as operational readings. The occupancy/HWM grade algebra is
  R2–R3, and is deliberately **not** a second semiring here (mission
  constraint).

### 3.1 Endpoint threading and `case`

`send`/`recv`/`select` thread the endpoint name: the residual context carries
it forward at its continuation type. `case` is a destructor: it consumes its
endpoint name and binds the per-branch continuation `xi : Si` inside branch
`i`. Branches must agree on the result type (`E_CASE_TYPE`) and on the live
*linear* state after the merge (`E_CASE_LINEAR`); unrestricted names are
branch-local and do not escape. This is the one place the IR deviates from a
naive reading of the ULTRAPLAN grammar — the grammar's `case ep {ℓᵢ: x.eᵢ}`
binder is given its only useful reading (the continuation endpoint).
Revisitable; recorded in the decision log.

### 3.2 Single-threaded correlated choice

With one thread of control, the `select` determines which `case` branch runs;
the remaining branches are dead code but must still typecheck against the
post-select context. The grade still takes the max over all branches
(worst-case-by-construction). `examples/session_ir/accept_choice_max.sir`
(certificate 5, measured 4) and `accept_choice_expensive.sir` (6 = 6) pin both
sides of this.

## 4. Determinism and what the model does not read

* No GC, no implicit copy, no sharing of buffers or endpoints.
* The only annotation forms are types and constant grade bounds `@r`
  (ULTRAPLAN §1.4 grade constancy: literals/statics only). A bound annotation
  is *checked* (`computed ≤ claimed`, else `E_BOUND`), never trusted.

Non-readings — this model is **not**:

* **not echo** — no diagnostic indices, no trace annotation (R6+, maybe never);
* **not warrant** — no epistemic or evidence types; certificates are plain
  bounds with an operational reading;
* **not residue** — no residual-evidence measure; `resource grade ≠ echo index
  ≠ residue measure` (ULTRAPLAN §5).

No imports from echo-types, epistemic-types, residual-evidence-types,
secret-types, tropical-resource-typing, or choreographic-types. Everything
used here is defined here.

## 5. Running the artefact

```sh
julia --project=src/julia src/julia/bin/sessionir.jl check FILE        # prints A|r or error
julia --project=src/julia src/julia/bin/sessionir.jl run FILE --trace  # steps, HWM, trace
julia --project=src/julia src/julia/bin/sessionir.jl test examples/session_ir/manifest.json
```

Reproducible check for the whole rung: `scripts/check.sh` (also exposed as
`just check`). Julia 1.10; the Session IR package uses Base only.

## 6. Phase 1 kill-test verdict (pre-registered criteria)

Pre-registered kill test (ULTRAPLAN Phase 1): *if errors are inscrutable, or
grade can be smaller than a real run, or you needed Echo/K-CUT to explain it,
Phase 1 fails.*

| Criterion | Verdict | Receipt |
|-----------|---------|---------|
| Errors inscrutable | not fired in the prior run | the pre-port Python runner matched all 7 coded rejection controls; the current Julia lane rechecks the same manifest |
| Grade smaller than a real run | not fired in the prior run | the pre-port Python stepper checked `steps ≤ r` on all 9 accepts (2=2, 4=4, 4≤5, 6=6, 2=2, 0=0, 2=2, 0=0, 2=2); the current Julia lane rechecks them |
| Needed Echo/K-CUT to explain | not fired | this document explains the whole instrument without either |

Mission-level kill test (three-way): the rejects are real bug classes
(double-free, use-after-drop/close, protocol mismatch, close-before-End,
aliasing, leak) — not counting trivia. The pre-port Python runner demonstrated
`steps ≤ grade` on every accept and strict inequality on `accept_choice_max.sir`;
the current Julia lane rechecks the same 16-row manifest. The fixtures pin
certified bounds, operational readings, and explicit cost/state separation
witnesses. **Not fired in the prior run; current Julia CI receipt pending.**
