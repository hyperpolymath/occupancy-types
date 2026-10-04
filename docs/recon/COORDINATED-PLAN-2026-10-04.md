# Coordinated plan — the seven repos, 2026-10-04

**Companion to:** `docs/recon/TYPE-FAMILY-POSITION-2026-10-04.md` (the position) and
`docs/recon/FOLLOWER-NOTES-2026-10-04.md` (consumer outreach).
**Scope:** `echo-types`, `epistemic-types`, `residual-evidence-types`, `choreographic-types`,
`tropical-types`, `occupancy-types`, `absolute-zero`, the `nextgen-typing` hub and the satellites.

---

## 1. The governing idea

The recon found one asymmetry that should drive the whole plan:

> **Most of the estate's claims are already true and already fenced — but a large fraction are
> not *machine-enforced*.** Proof work that exists on disk is unreceipted (no CI lane, no
> toolchain run, no issue), while several workflows that appear to gate it die at startup.

So the plan is not "do more research". It is, in order: **(W1) make what exists checkable**,
**(W2) convert the five cross-family arrows from proposed to checked**, **(W3) time-box the two
open keystones**, **(W4) run the occupancy rungs through their own kill gates**, **(W5) build
consumers so the work has external standing**. Research ambition is capped deliberately: the
plan's job is to make the boundary between *established* and *open* impossible to misread.

### Principles (non-negotiable, because they are the estate's credibility)

1. **Receipts over claims.** A result is [RAN] (command + output), [CI] (run id + commit), [DOC]
   (dated author run), or it is *not established*. Upgrading [DOC]→[CI] is the cheapest work in
   the estate and the highest value.
2. **Blocked ≠ retracted.** Blocked items carry the exact command that would unblock them.
   Retractions are recorded with the counterexample. Both ledgers already exist — keep using them.
3. **Separation before capability.** Every family's identity rests on matched-negatives or
   no-go results. A new capability claim without a separation is a naming exercise.
4. **Kill criteria are pre-written and honoured.** occupancy-types §3 has them per rung;
   absolute-zero warns that a too-clean composition result is probably wrong. Obey the ledgers,
   not the momentum.
5. **No arrow as dependency.** The type-family map's dashed arrows are obligations, not imports.
   The one deliberate exception (occupancy's "no cross-kernel imports") stays.

---

## 2. Workstreams

### W1 — Make the receipts real (highest leverage, mostly mechanical)

| # | Task | Repo | Owner | Closes with |
|---|---|---|---|---|
| W1.1 | Read the Actions posture; if `selected`/short, PUT the canon allow-list; re-run the gates | occupancy-types | **owner-only** | a push where Secret Scanner + Governance + a checker job *start and pass* (issue #6) |
| W1.2 | Wire the Session IR manifest as a CI job (`PYTHONPATH=src python3 -m session_ir test …`, 14/14 today) | occupancy-types | automatable | green job on `main`; regression visible |
| W1.3 | Build `verification/proofs/` in CI (XP‑1 currently unenforced) | nextgen-typing | automatable | green job; issue #57 |
| W1.4 | Extend Isabelle `ROOT` to all 9 theories + add the Isabelle job | tropical-types | needs Isabelle | PROOF-STATUS's "CI-gated" claim becomes true; issue #57 |
| W1.5 | Lane `experimental/echo-additive` + the 4 bit-narrowing modules | echo-types | automatable | modules in `All.agda`/a lane or archived; issues #320/#321 |
| W1.6 | Pin the Agda toolchain (drop unpinned `apt-get agda`) | echo-types | automatable | pinned version in workflow; issue #322 |
| W1.7 | Make CI mirror the local all-provers gate (or say so loudly in CI + README) | absolute-zero | author | issue #161 closed or scoped honestly |
| W1.8 | **Estate-wide: treat `STARTUP_FAILURE` as failure for required checks** (§6.2) | all | owner (settings) | no PR can merge with zero CI signal; echo-types#330 |
| W1.9 | File the missing issue(s) for repos with dead CI and no tracker entry | occupancy-types | done (issue #6) | — |
| W1.10 | Remove tracked `__pycache__` (7 files) + ignore rule | occupancy-types | **done this session** | clean tree |

**Why first:** W1 costs days, converts a large body of [DOC] into [CI], and — critically —
W1.8 and W1.1 also *unblock* every future automated check. Right now a green badge in this
estate is not evidence that anything ran.

### W2 — Mature the interfaces (the five arrows)

The hub's `TYPE-CONNECTIONS.adoc` lists what each connection needs. Current state, from the
recon: Echo→Residual and Epistemic→Residual cover **Milestone 1 only**; Echo→Choreographic and
Epistemic→Choreographic have **no proof**; Tropical→Choreographic needs a grading semantics.

| # | Task | Repo | Closes with |
|---|---|---|---|
| W2.1 | Comparisons 2.0: do composition (`compose-claims`) and revision (`survives-retraction`, `revise`) transport beyond `Echo.Echo` / `SoundWarrant`? | residual-evidence-types | a checked answer either way — *"no, a richer interface is needed"* is a publishable result |
| W2.2 | **Cost vs state as a separation**: exhibit a composition where the HWM grade and the cost grade cannot be identified | occupancy + tropical | a witness pair + a no-identification theorem (cheap, falsifiable, cross-family) |
| W2.3 | Projection model + correspondence theorem for the echo loss-grade on a projection | echo ↔ choreographic | a stated projection with a proved commuting square (two-event case first) |
| W2.4 | `K-CUT-WARRANT` statement with side conditions (`SoundWarrant` receiver-local) — *state it precisely before proving it* | epistemic ↔ choreographic | a written statement + its side conditions, reviewed |
| W2.5 | Grading semantics for bounds under interaction (declared algebra, not a port) | tropical ↔ choreographic | a semantics + a projection theorem, or a documented negative |
| W2.6 | Reconcile the choreographic "echo loss-grade" vocabulary with the shared glossary (index ≠ measure ≠ grade) | choreographic + hub | README/glossary agreement; hub roadmap item closed |
| W2.7 | Refresh stale STATE files against their own PROOF-STATUS | residual-evidence, tropical, absolute-zero | a state file that does not contradict the receipts |

**W2.2 is the sleeper.** The estate's central architectural claim is that cost and state are
different axes; both halves already exist in separate repos; and the claim is a *separation*,
which means it is cheap to make and cheap to falsify. If it fails, that is important news for
occupancy's thesis. It should be done early.

### W3 — Keystones, time-boxed and pre-falsified

| # | Task | Repo | Time box | Kill / honest outcome |
|---|---|---|---|---|
| W3.1 | Two-event K-CUT-LOSS square under `Independent₂` | choreographic | 1–2 sessions | if `Independent₂` needs hypotheses that trivialise it, record that |
| W3.2 | A **second, non-degenerate** projection pattern | choreographic | after W3.1 | if degeneracy is incidental, K-CUT gains standing; if essential, the assembly hypothesis narrows honestly |
| W3.3 | Bachmann–Howard `ψ₀(Ω_ω)` fidelity (Lane 3, retired from echo-types) | echo-types | multi-session frontier | remains OPEN by D-2026-06-14; the 2 Fidelity postulates are the only ones in the tree |
| W3.4 | OND-6 conditional composition | absolute-zero | research-grade, last | the roadmap already warns a too-clean positive result has dropped a term |
| W3.5 | Kernel-certificate / guardrail re-check after any W3.3 movement | echo-types | per change | `Smoke.agda` + `All.agda` + guardrails green |

**Rule for W3:** nothing here is allowed to block W1/W2, and every item ships a written negative
outcome. Lane 3 was already retired once from echo-types for outgrowing the project — that
precedent is the model.

### W4 — Run the occupancy rungs through their own gates

| # | Task | Blocked on | Then |
|---|---|---|---|
| W4.1 | Idris 2 Occupancy spike: `idris2 --check Occ.idr` + `Demo.idr` + 4 rejection controls; answer the kill question (constant grades tolerable **and tight**?) | `idris2` installed | R0‑B Piece 2 closes or the kill criterion fires |
| W4.2 | stackcert: `lean StackcertCore.lean`, `#print axioms cert_sound`, fixture run + 4 negative controls | `lean`/`lake` installed | replaces the CONJECTURE with a pasted axiom footprint |
| W4.3 | Zephyr painted-stack HWM fixture on `qemu_cortex_m3` | `west` + QEMU + Zephyr SDK | R1's ground-truth protocol can run: measured ≤ certified |
| W4.4 | R2 static pools + affine/linear handles, T1 coherence theorem | W4.1–W4.3 | **project gate**: no external consumer + no theorem beyond restatement ⇒ archive with a ledger entry |
| W4.5 | Phase‑2 "protocol cut = reclaim" (live memory = f(protocol shape)) | R2 | compositional advantage demonstrated, or kill |

**This is the only workstream with a project-level stop written into it.** Treat W4.4 as the
real decision point and do not let it drift into R3/R4/R5 by inertia.

### W5 — Consumers and external standing

| # | Task | Closes with |
|---|---|---|
| W5.1 | Sign + re-anchor the per-repo AFFIRMATIONs at main (nextgen-typing#69) | dated, GPG-signed receipts at current SHAs |
| W5.2 | Register occupancy-types in the hub's type map (question, boundary, connections) — hub#118 | map row + vocabulary fence |
| W5.3 | Re-cite the residual receipts and give Echo→Residual / Epistemic→Residual acceptance criteria (hub#115) | guide updated with acceptance criteria |
| W5.4 | Mirror the general `EchoAggregation` into EchoTypes.jl (echo-types#280) | finite-domain falsifier covers the general law |
| W5.5 | Clear the Pillar E offline half: packaging, DOI, submission | paper submitted (author-driven) |
| W5.6 | absolute-zero artifact-evaluation package (one-command container) | reviewer can reproduce `ALL-PROVERS-GREEN` |
| W5.7 | Follower outreach (see the companion notes file) | replies → real consumers; keeps the estate honest about who actually uses this |
| W5.8 | A public artefact over the outreach: "what a projection/receipt/bound problem looks like, four worked examples" | citable, reaches the same audience without 269 DMs |

---

## 3. Dependencies

```
W1.8 (treat STARTUP_FAILURE as failure)  ──►  makes every other gate trustworthy
W1.1 (occupancy Actions posture)         ──►  W1.2, W4.* receipts
toolchains (idris2 / lean / zephyr)      ──►  W4.1 ─► W4.2/W4.3 ─► W4.4 (project gate)
W2.1 (interfaces beyond M1)              ──►  W2.3, W2.4, W2.5  (three of five arrows)
W2.2 (cost vs state separation)          ──►  independent; strengthens or breaks occupancy's thesis
W3.* (keystones)                         ──►  must NOT block anything in W1/W2
W5.1/W5.2 (receipts + registration)      ──►  prerequisite for W5.5, W5.7 credibility
```

Two structural notes: **(a)** W1.8 is a single settings decision with estate-wide leverage —
it belongs in the first hour. **(b)** The three arrows that depend on W2.1 mean the residual
repo's next question is worth more than its apparent size: it is the hinge for half the map.

---

## 4. Sequence

**Horizon 1 — this week (all mechanical, no research):** W1.8, W1.1, W1.2, W1.3, W1.10 (done),
W1.4, W1.6, W1.7; W2.7 (state files); W5.1, W5.2.
*Outcome: every existing proof claim that can be receipted is receipted; no green badge is
false.*

**Horizon 2 — the quarter (interfaces + the rungs that can run now):** W2.1, W2.2, W2.6;
W4.1, W4.2, W4.3; W3.1, W3.2; W1.5.
*Outcome: the five arrows either checked or honestly narrowed; occupancy past R1 with ground
truth; K-CUT either advanced one non-degenerate step or falsified at the two-event scale.*

**Horizon 3 — beyond (research + external):** W3.3, W3.4; W4.4 decision, then R3–R5; W2.3–W2.5;
W5.4–W5.6; W5.7/W5.8.
*Outcome: external standing, or an honest narrowing — the estate's own decision policy on the
identity claim (echo-types' roadmap: *"if it is refuted, narrow honestly… or stop the identity
claim and retain the suite as Agda exposition"*).*

---

## 5. What this plan refuses to do

* **No cross-kernel imports.** occupancy's ULTRAPLAN §1.2 is permanent: not dependent on K-CUT,
  Echo, epistemic or secret types. The map is vocabulary, not a build graph.
* **No new surface language before a certificate checker has a user** (occupancy non-goal).
* **No capability claim without a separation** (echo-types' gate discipline).
* **No "one more prover" for absolute-zero before CI mirrors the gate it already has.**
* **No 269-message outreach.** Narrow, falsifiable, per-person hints only — the alternative is
  noise with a reputational bill.
* **No treating a conceptual arrow as a dependency, an equivalence, or a theorem.**

---

## 6. Measurement discipline — how to read a pass rate

*Added 2026-10-04, after the recon. Every figure below was measured that day from the Actions
API — never from a badge.*

### 6.1 Two ratios, never one

A single "pass rate" is ambiguous in a way that flatters a broken pipeline: a run that never
executed is still a run, so 96 non-executions read as "96% failing" — and when the gate that
never starts is the one that would have failed, a disarmed repo can read **green**. Split it:

| Ratio | Definition | Measured 2026-10-04 | Target |
|---|---|---|---|
| **R1 · executed / required** | required checks that produced at least one job | **~0/100** in occupancy-types; **≈100%** in the five repos whose proof jobs run | **100%** |
| **R2 · passed / executed** | executed checks ending in success | **≈100%** in every proof lane measured — epistemic 21/21, residual 39/39, tropical Lean 13/13, absolute-zero Proofs 5/5, echo-types green at HEAD | **100%** for proof lanes; **no threshold** for tightness (6.4) |

The occupancy-types figure in full: of the last 100 runs, 96 `startup_failure`, 3 `failure`,
1 `success` — and **exactly 4 runs had any job at all**, all four being dependency-graph
"Update" workflows (pip, hex, npm_and_yarn, github_actions). No gate in that repository has
ever executed a single job.

**Rule: report R1 before R2.** A pass rate quoted without its execution rate is not a
measurement — and a "100% pass" over 0 executed checks is precisely what a dead pipeline looks
like.

### 6.2 Green must mean executed

A green tick is evidence only if a job ran. Enforce three things:

* **`STARTUP_FAILURE` counts as failure** for every required context, and so does a required
  context that reports no jobs (W1.8; the recommendation in echo-types#330).
* **Every receipt names a run id and a commit.** `[CI]` in the estate's tagging means "a job
  started and passed", never "a workflow is listed".
* **Prefer a revoked badge to a stale one.** A repo whose gates cannot run should say so in the
  README rather than display workflow badges that no longer execute — the badge is the single
  most misleading artefact in a disarmed pipeline.

### 6.3 Proof lanes carry zero flake tolerance

Proof checking is deterministic: same toolchain, same inputs, same verdict. There is no
legitimate "sometimes" for `agda All.agda`. A proof lane's expectation is **100%**, and any
deviation is a bug in the pipeline or the environment — never noise to budget for.

What the estate's own record shows (last 100 runs per repo, 2026-10-04): every prover red in the
window had a cause —

* **real breakage** — echo-types' Agda lane on 2026-09-27 (`39a7a99c`) and 2026-09-30
  (`f11031f2`), the "Typecheck full suite" step failing: main was genuinely broken, then fixed.
  The cold-check step (`--ignore-interfaces`, no cache) failed in the same runs;
* **supersede** — a concurrency `cancel` (absolute-zero `Proofs` `27d879f5`; echo-types Agda
  `36919959218`);
* **infrastructure** — the `startup_failure` family.

**No case of the same commit passing and failing at random was found.** That distinction is the
point: *flakiness* trains a team to re-run until green and is the thing to hunt; a
red-with-a-cause is a bug report carrying a file and a line number, and it is the system working.

The one real drift risk is the environment, and it is documented: echo-types#322 —
`agda.yml` performs an unpinned `apt-get install -y agda`, so *the prover under the proofs can
change without a commit*. Pin the toolchain (W1.6) and keep the guardrails already in place:
`--safe --without-K`, the postulate/escape greps, the `Smoke.agda` pins, the kernel certificate.

### 6.4 Tightness is a distribution, not a gate

Keep the asymmetry ULTRAPLAN §6 already states:

* **Soundness** — *"measured ≤ certified on every run. Violation = stop + ledger entry"* →
  **100%, zero tolerance**. This is a correctness property, not a benchmark.
* **Tightness** — *"certified/measured per unit; report distribution"* → **not pass/fail**.

Do not turn tightness into a threshold. A limit loose enough never to fire is decoration; one
tight enough to fire on measurement noise teaches everyone to ignore red — exactly the failure
mode 6.3 exists to prevent. Report the distribution, watch it move, and act on trends with a
named cause.

Also note the current state: **nothing has been measured yet.** The Zephyr painted-stack fixture
(W4.3) is still a fixture request, so R1 ground truth does not exist. "Benchmarks occasionally
drift" is not the situation; "no benchmark has ever run" is.

Retries are permitted for genuinely non-deterministic infrastructure — package/action downloads,
superseded runs, cancelled fuzz batches — and are **never** permitted to produce a green verdict
on a claim that was not checked. Blocked ≠ retracted; blocked ≠ passed.

### 6.5 Three kinds of red, three responses

| Kind | Signature | Response |
|---|---|---|
| **Real breakage** | job ran; a named step failed | Fix or revert; the run id goes in the ledger entry |
| **Environment / infrastructure** | job never started, or a dependency fetch failed | Fix the cause (pin, allow-list, retry policy) and file it; never re-run to green |
| **Supersede / cancel** | `cancelled`; a newer run exists on the same ref | Nothing — but confirm a later run executed |

### 6.6 Recompute it

```bash
# R1/R2 inputs for a repo — conclusions, from the API, not badges
gh api "repos/hyperpolymath/occupancy-types/actions/runs?per_page=100" \
  --jq '[.workflow_runs[].conclusion] | group_by(.) | map({(.[0]): length}) | add'

# R1 precisely: did a run actually execute any job?
gh api "repos/hyperpolymath/occupancy-types/actions/runs/<run-id>/jobs" --jq '.total_count'
```

---

## 7. How to tell whether the plan worked

*Measure everything below with §6's ratios: **R1 before R2**, and green-means-executed.*

Falsifiable, in order of cheapness:

1. **`STARTUP_FAILURE` cannot masquerade as green** in any estate repo (W1.8). Check: force a
   failing workflow and confirm it blocks; check that a required context that never starts
   reports failure.
2. **Every "[DOC] verified" line in PROOF-STATUS has a corresponding green run id**, or is
   explicitly marked as not CI-covered. Check: grep the PROOF-STATUS files against the Actions
   API.
3. **The cost/state separation is settled either way** (W2.2) — a witness + no-identification
   theorem, or a documented collision that narrows occupancy's thesis.
4. **K-CUT is either non-degenerate-advancing or honestly narrowed** to what a two-event square
   can support (W3.1/W3.2), with the degenerate case's status written down.
5. **At least one external consumer** exists for one artefact (W5.5–W5.8), or the R2 project
   gate fires and occupancy is archived with a ledger entry — which is a *success* under its
   own rules.
6. **No state file contradicts its repo's receipts** (W2.7). This is the cheapest measure of
   estate coherence, and today three fail it.
