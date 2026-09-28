<!--
SPDX-License-Identifier: CC-BY-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-->
# ULTRAPLAN — occupancy-types
Stepwise resource-bounding types: deterministic memory first, network resources second.
Version 0.2 · Status: pre-registration · Doc licence CC-BY-4.0 · Code licence MPL-2.0

## 0. Thesis

Types can give checked, composable, worst-case evidence for resources that are currently
estimated by unverified tools plus a safety margin. The instrument is not a new allocator:
it is (a) eliminating dynamic allocation with types proving the bounds, or (b) certifying
trivial allocators (fixed pools, LIFO regions, bounded queues).

Two facts shape everything:

1. **Cost vs state.** Cost resources (time, rounds, stack depth) compose with + in sequence
   and max across alternatives — tropical. State resources (pool occupancy, buffers, FDs,
   credits) are acquired and released; their composition is the high-water-mark (HWM) monoid
   (p₁,n₁)·(p₂,n₂) = (max(p₁, n₁+p₂), n₁+n₂), unit (0,0), which is non-commutative.
   Both axes are needed; neither is the other.

2. **Buffer = memory.** Channel windows and arrival/service curves yield buffer grades;
   buffer grades are occupancy. This is what makes network and memory one tool rather than two.

3. **Protocol frontier = reclamation point.** When an endpoint reaches End and is closed,
   every buffer whose owner was that session epoch is dead. Live memory is a function of
   protocol shape, not of GC.

## 1. Scope, value, stopping rules

### 1.1 Where the value is real
Safety-critical / hard-real-time (DO-178C, ISO 26262, IEC 61508; MISRA, JSF, SPARK, ARINC 653)
and sandboxes (wasm pages/fuel, eBPF verifiers). There, constant grades cost nothing extra.

### 1.2 Non-goals (permanent)
Not an allocator. Not average-case or probabilistic. Not data-dependent grades. Not a surface
language before a certificate checker has a user. Not dependent on K-CUT, Echo, epistemic, or
secret types. No cross-kernel imports.

### 1.3 Contribution claim (falsifiable)
- Distinct phenomenon: state resources need a sequential, non-commutative grade axis beside
  tropical cost grades; certificates are preferable to analyses.
- Characteristic theorems: T1 effect/coeffect coherence; T2 buffer grade commutes with
  endpoint projection; T3 one program, two bounds; T4 worst-case-by-construction vs amortised.
- Canonical examples: stack, pool, queue, binary session.
- Project-level stop: if at the R2 gate there is no external consumer for certificates and no
  theorem beyond restatement, archive with a ledger entry.

### 1.4 Grade constancy rule
A grade is a literal or a static parameter fixed at check time. Parametric polymorphism over
grades is allowed if every instantiation is static. Needing anything else is a kill signal.

## 2. Decisions

| ID | Decision | Default |
|----|----------|---------|
| D1 | Where code lives | Algebra: tropical-resource-typing. Calculus, checker, spike: this repo |
| D2 | Kernels | Lean 4 for metatheory + verified checker; Idris 2 for QTT spike; Python/Rust for session IR checker |
| D3 | First real target | Session IR (fastest to fail), then Zephyr samples/synchronization on qemu_cortex_m3 |
| D4 | Session IR grade | Communication steps, max-plus (ℕ∪{∞}, max, +, 0) |
| D5 | Drop vs implicit free | Explicit drop for Buf, close for endpoints, both consuming |
| D6 | Recursion in session IR | Omitted in v0; finite unrolled protocols sufficient |
| D7 | Numeric carrier | ℕ/ℤ everywhere; no reals, no Mathlib |

## 3. Rung contract

A rung is complete only when all four hold:
1. **Theorem** — composition law + soundness, mechanised, axiom footprint printed
2. **Artefact** — a runnable library or checker, tiny
3. **Ground truth** — measured ≤ certified on every run; tightness ratio reported
4. **Consumer** — one external tool whose output it checks or one external artefact it sizes

Plus a pre-written kill criterion, a time box, and a ledger entry on failure.

## 4. The ladder

### R0-A — HWM Algebra (tropical-resource-typing, Lean 4, 1 week)

SequentialEffect typeclass + HWM instance + laws + non-commutativity witnesses +
bridge lemma + iteration lemmas. See sibling repo for full task list.

### R0-B — Session IR + Idris Spike (this repo, 1 week)

**Phase 0: Operational Model (half day)**
- docs/OPERATIONAL-MODEL.md: machine config (heap, channels, threads, clock), grade meaning
  (comm steps, max-plus), memory meaning (linear Buf, explicit drop/close), deterministic
  (no GC, no implicit copy), non-readings (not echo, not warrant, not residue)
- Kill test: explain ⊕ = max, ⊗ = + in four sentences without "tropical"

**Phase 1: Smallest Helpful Checker (2-3 days)**

IR grammar:
```
Types: Unit | Buf n | A ⊗ B | S
Sessions: End | !A.S | ?A.S | ⊕{ℓᵢ:Sᵢ} | &{ℓᵢ:Sᵢ}
Terms: unit | drop e | alloc n | pair e₁ e₂ | letpair |
       new S | send ep val | recv ep | close ep |
       select ℓ ep | case ep {ℓᵢ: x.eᵢ} | let x:A@r = e₁ in e₂
Judgment: Γ ⊢ e : A | r    (r = comm step count, max-plus)
```

Grade rules: send/recv/select = 1 + subterms; case = 1 + max branches; let = r₁ + r₂;
alloc/unit/drop/close/pair/letpair = 0 + subterms; new = 0.

Memory invariant: each Buf and endpoint appears exactly once in linear context or is consumed.

Examples (≥8): 3+ accept, 3+ reject (double-send, drop-then-send, protocol mismatch,
close-before-End), 2+ with expected bounds (choice max, sequential add).

Checker: Python or Rust. Parse, type-check syntax-directed, print A|r or specific error.
Stepper: reduce closed programs, count comm steps, assert steps ≤ r.

Kill test: if errors are inscrutable, or grade can be smaller than a real run, or you needed
Echo/K-CUT to explain it, Phase 1 fails.

**Idris 2 Spike (2-3 days)**
- Occ indexed state monad with static occupancy/peak indices, linear handles
- Bounded queue example with static peak
- Four expected-rejection controls
- Kill question answer: are constant grades tolerable and tight?

Kill: bounded-queue example non-trivial only with data-dependent grades → stop, ledger.

### R1 — stackcert (≤3 weeks)
Stack-depth certificate checker. Lean 4 verified core + parsers. GCC .ci/.su input.
Zephyr fixture with painted-stack ground truth. cert_sound theorem.
See task list T1-T9 in the kickoff prompt.

Kill: no true positive, no justified budget reduction, no consumer at time box.

### R2 — Static pools + affine/linear handles (6 weeks)
Calculus with pools, HWMI grades, QTT coeffects. T1 coherence theorem.
Kill: coherence needs useless side conditions, or every example violates grade constancy.
**Project gate after R2.**

### Phase 2 (within R2) — Protocol cut = reclaim
Session frontier as arena epoch. When endpoint reaches End and is closed, every buffer whose
owner was that session epoch is dead. Live memory = function of protocol shape.
Kill: live-memory bound is merely "max message × window" written in a comment with no
compositional advantage.

### R3 — Binary session channels with buffer grades (6 weeks)
Buffer occupancy grading composed by HWM. k-bounded async queues.
Kill: realistic protocols need unbounded windows or data-dependent payloads.

### R4 — Network-calculus curves as grades
Token bucket, rate-latency closed forms over ℕ/ℤ.
Kill: closed forms don't compose with R3 grades without reals.

### R5 — Multiparty projection
Project global type, grade locally. Does buffer grade commute with projection?
Kill: projection fails to preserve grades on a basic pattern.

### Phase 5 (any time after R1) — Sit under someone else's tool
Pick one host. Provide a 2-page contract. Kill: host can't take the idea without estate glossary.

### R6+ — Epistemic credits, echo diagnostics (post hoc only, maybe never)
Not memory management. Annotate traces, don't change drop/send.
Resource grade ≠ echo index ≠ residue measure.

## 5. Cross-cutting requirements
- Proof purity: Lean — no Mathlib, no sorry, no Classical.choice; Idris — %default total;
  Agda (R5+) — --safe --without-K
- Port-and-reprove; cross-reference by module.theorem
- Docs from day one: README.adoc, EXPLAINME.adoc, retraction-ledger.adoc, glossary.adoc
- just check = proofs + tests + expected-rejection controls + checker on fixtures
- Vocabulary discipline: cost grade ≠ occupancy grade ≠ echo index ≠ residue measure ≠ warrant

## 6. Ground-truth protocol
1. Record toolchain versions, flags, board/QEMU, workload duration, commit SHAs
2. Soundness: measured ≤ certified on every run. Violation = stop + ledger entry
3. Tightness: certified/measured per unit; report distribution
4. Reproducible from just measure; fixtures committed with README

## 7. Prior art and positioning
| Area | Works | We borrow | Ours |
|------|-------|-----------|------|
| Bounded-space types | Hofmann LFPL; RAML | framing | worst-case-by-construction, constant grades, no LP |
| Regions / ownership | Tofte-Talpin, Rust, WIT | affine handles | T1 coherence with occupancy index |
| Graded types | Granule, Atkey QTT, McBride, Katsumata, Gordon | coeffect + effect structure | HWM as first-class instance; cost/state separation with witnesses |
| Indexed monads | McBride, Atkey | spike encoding | absolute/relative bridge lemma |
| Stack bounding | Regehr et al., AbsInt, cargo-call-stack | the rule | certificate format + verified checker + ground-truth protocol |
| Session types | Honda-Yoshida, Wadler CP, Gay-Vasconcelos | linear binary sessions | comm-step grade + protocol-frontier reclamation |
| Costed sessions | Das-Hoffmann-Pfenning, Bocchi-Yang-Yoshida | latency grading | buffer occupancy grading composed by HWM |
| Network calculus | Cruz, Le Boudec-Thiran, ONERA Coq | closed forms | composition with pool/channel grades |

## 8. Session report format
Proved (theorem, file, #print axioms) · Tested (positive / expected-rejection) · Measured
(table + command) · Open / blocked · Kill dashboard (per rung) · Retractions · Next task ids

## 9. Decision log (fill as you go)
| Decision | Choice | Why | Revisit when |
|----------|--------|-----|--------------|
| Session IR grade | comm steps, max-plus | one operational reading | R2/Phase 4 |
| Drop vs implicit free | explicit drop + close | deterministic, checkable leaks | never if examples work |
| Recursion | omitted in v0 | demo first | after 8 examples |
| Multiparty | no | projection is a swamp | R5 |
| Second algebra | no | soup kills errors | R2/Phase 4 |
| Estate imports | none | kernel must stand | Phase 5 contract |
| Session IR checker language | Python 3 stdlib | D2 permits Python or Rust; only Python in the work environment; estate deny-list tension noted | Rust toolchain available |
| `case` binder reading | binder = continuation endpoint, scrutinee consumed | only reading that gives `x` a job; branches merge on linear part | R3 delegation |
| Unrestricted names at merge | Unit names branch-local, may differ | only linear state is a resource | if unrestricted types grow |
| Occ spike storage | `Fin n -> Nat` FIFO (ring layout deferred) | occupancy indices are layout-independent | if a consumer needs ring layout |
| stackcert callee model | lists-as-sets (no Mathlib) | D7 purity | port-and-reprove if Finset needed |
| stackcert dynamic frames | `[dynamic]` byte bound in annotations.toml | "reject without annotation" needs an annotation channel | R1 contract review |
| Proofs registration | spike/stackcert NOT in proofs MANIFEST until toolchains run | `gated` = "must compile"; unverified code must not claim it | T-P2-1 / T-P3-1 |
| docs/OPERATIONAL-MODEL.md stays .md | ULTRAPLAN names the path exactly | gate allowlisted instead (check-no-md-in-docs.sh) | if the plan renames it |
| Family registration | register in nextgen-typing TYPE-CONNECTIONS map (question + boundary + connections) | coherence without code coupling; the map's vocabulary fence IS §5 of this plan | map review |
| Naming errata | "tropical-resource-typing" (D1/R0-A) is the historical name; GitHub canonical is `tropical-types` (redirect); `katagoria`→`ideas-to-alphas` ≠ `kategoria` | name hygiene per nextgen-typing naming note 2026-09-09 | never |
