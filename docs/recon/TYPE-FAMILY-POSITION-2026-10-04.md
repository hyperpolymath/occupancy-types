# Type-family position — deep recon

**Date of recon:** 2026-10-04 · **Prepared in:** `occupancy-types` @ `arena/01a1087c-occupancy-types`
**Scope:** `echo-types`, `epistemic-types`, `residual-evidence-types`, `choreographic-types`,
`tropical-types`, `occupancy-types`, `absolute-zero`, plus the coordination hub
`nextgen-typing` and the satellite repos.

---

## 0. How to read this, and how much to trust it

The estate is unusually well instrumented for honesty — AFFIRMATIONs, PROOF-STATUS
receipts, retraction ledgers, kill criteria, blocked-item registers. This document tries
to hold to that same standard, so every claim below is tagged with **how we know it**:

| Tag | Meaning |
|---|---|
| **[RAN]** | I ran the command in this session and saw the result. First-hand. |
| **[CI]** | A hosted CI job on the recorded commit passed; run id/URL given. |
| **[DOC]** | The claim is the repo's own recorded status (PROOF-STATUS / AFFIRMATION / STATE / README), reproduced by an author in a stated environment, **not** re-run by me and not covered by a CI receipt in this recon. |
| **[ISSUE]** | The claim comes from a filed issue (i.e. a known, acknowledged defect or task). |
| **[INFER]** | My inference from file evidence; stated plainly as such. |

**Calibration — what this session could and could not do.** This sandbox has
`python3` and `git` only. It has **no** `agda`, `lean`/`lake`, `idris2`, `coqc`,
`isabelle`, `mizar`, `z3`, `just`, `bun`, or Rust toolchain. Therefore:

* Every Agda / Lean / Isabelle / Coq result is **[DOC]** or **[CI]** — I did **not**
  re-typecheck any proof. Where a hosted run exists, I cite the run id.
* The one proof-adjacent thing I could re-run was `occupancy-types`' Session IR gate — it
  passed 14/14 **[RAN]**.
* Repo trees, docs, roadmap text, ledger entries, workflow contents, CI conclusions,
  issue text and commit signatures were all read directly from clones and the GitHub API.
* CI conclusions were read from the API, not inferred from READMEs or badges.

**Anchor pins** (HEAD at recon time; all commits GPG-verified **[API]**):

| Repo | HEAD | Date |
|---|---|---|
| echo-types | `da140cc26f` | 2026-10-03 |
| epistemic-types | `eb810d4ee7` | 2026-10-04 |
| residual-evidence-types | `62d7490754` | 2026-10-02 |
| choreographic-types | `71ba51d3b8` | 2026-10-03 |
| tropical-types | `ad7bfdfd56` | 2026-10-03 |
| occupancy-types | `2e276c365f` | 2026-10-04 |
| absolute-zero | `5f27136835` | 2026-10-02 |
| nextgen-typing | `70df154951` | 2026-10-01 |
| EchoTypes.jl | `a0ac9131f7` | 2026-10-01 |
| EpistemicTypes.jl | `6ab3fb4a01` | 2026-10-01 |
| ResidualEvidenceTypes.jl | `abe97d5c99` | 2026-10-01 |
| secret-types | `aed3f1cc2d` | 2026-10-04 |

### The three-tier vocabulary used throughout

* **There (established)** — a machine-checked artefact exists *and* it is either
  receipted by a current CI run or reproducible by a named local command; the claim is
  fenced by an explicit written boundary.
* **Nearly there** — the artefact exists in the tree but one link is missing: no CI lane,
  no toolchain run, an unwired module, a stale state file, or a theorem that is true but
  degenerate relative to the claim it is cited for.
* **Within reach** — the repo's own next step, already specified in a roadmap, ledger
  entry, or open issue, needing no new research — only work. Everything beyond this line
  is named as **open research** rather than aspiration.

---

## 1. The estate map (as it stands)

The five research families and their owning repos, with questions and boundaries exactly
as `nextgen-typing`'s shared guide states them **[DOC: TYPE-CONNECTIONS.adoc]**:

| Family | Question | Fence (what it is *not*) |
|---|---|---|
| **echo-types** | Which possible origins lie over an output after a transformation? `Echo f y = Σ (x : A), f x ≡ y` | An output need not identify its origin; a numeric residue measure does not determine residue structure |
| **epistemic-types** | From which standpoint is a claim available, with what evidence? `E κ A` | Having evidence ≠ proof of the claim; belief/knowledge/sound warrant have different interfaces |
| **tropical-types** | How do declared resource bounds compose? | The algebra must be stated; a bound is neither a probability nor an Echo residue identity |
| **residual-evidence-types** | Which worlds satisfy an observation *and* its evidence constraints? | Constructing a candidate does not recover the world; real-world soundness needs the actual-world premise |
| **choreographic-types** | What happens to distinctions, bounds and warrants under projection to participants? | A causal-order cut is not Gentzen cut-elimination, nor causal identification; the general K-CUT is open |

Neighbours in the same map but **out of the type family proper**:

* **occupancy-types** (this repo) — *state* resource grades (HWM monoid, non-commutative),
  deliberately separated from tropical *cost* grades; session/protocol frontier reclamation.
* **absolute-zero** — CNO (certified null *effect*) and OND (certified null *disclosure*);
  a multi-prover effort with an Echo bridge module. Not one of the five families; connected
  to them (and proposed for a map row in absolute-zero#175 **[ISSUE]**).
* **secret-types** — new (created 2026-09-27), specification-stage only. Owner ruling
  2026-10-04: this is the home for secret types; `epistemic-types` adds no Secret API;
  epistemic-types#29 closed, #32 transfer pending GitHub issue-write access **[DOC: STATE.a2ml]**.
* **nextgen-typing** — the coordination hub: shared glossary, ownership routing, the
  cross-project proof. It hosts no family code.

**Vocabulary fences that are load-bearing and currently holding** (worth stating because
they are the estate's main defence against concept collapse):

> cost grade ≠ occupancy (HWM) grade ≠ echo index ≠ residue measure ≠ warrant ≠ residual

The guide is explicit that the five families are **complementary questions, not ranks of
type-system strength**, and that dashed arrows in the map assert *conceptual use or a
proposed research task* — not dependency, equivalence, or a checked bridge
**[DOC: TYPE-CONNECTIONS.adoc]**.

---

## 2. Per-repo deep recon

### 2.1 `echo-types` — the most developed family member

**What it is.** Constructive Agda formalisation of proof-relevant fibres as witnesses of
structured (non-total) information loss. 209 `.agda` files under `proofs/` **[RAN: file count]**;
the verified closure (`proofs/agda/All.agda`) is described as ≈200 modules and
**postulate-free**.

**There (established).**
* The Agda suite typechecks under `--safe --without-K`, and the **hosted Agda job is green**
  on current main: run `37152181722` @ `da140cc2`, 2026-10-03 **[CI]**.
* A canonical-identity spine landed 2026-05-27: `EchoTotalCompletion` (`A ≃ Σ B (Echo f)`),
  the (equivalence, projection) factorisation, no-section results, four-axis loss/residue
  taxonomies, and audience modules **[DOC: PROOF-STATUS, README]**.
* **Matched-negative separation proofs** — where the identity claim does its real work:
  Echo is not distinguished by Shannon entropy; the LL `!A := 1` shallow-encoding gap;
  equal measure ⇏ equal Echo (`Echo.Separation.NotResourceInstance`) **[DOC]**.
* An ordinal/Buchholz track with a sound carrier: doubled-ladder well-foundedness,
  Brouwer `ω^^_`/`ε₀`, and a real Buchholz notation order with well-foundedness **[DOC]**.
* Retraction discipline: R-2026-05-18 narrowed four headline claims (graded comonad →
  thin-poset reindexing modality; universal property → funext-relative pointwise mediator;
  model-independence → carrier-parametricity; conservativity metatheorem → postulate-free
  build that is *evidence for*, not proof of) **[DOC: AFFIRMATION, roadmap]**.
* A cross-project proof `EchoTyping.agda` (XP-1: pipeline information-loss = echo fibres,
  spanning echo-types ↔ affinescript ↔ typed-wasm) lives in `nextgen-typing` **[DOC]**.

**Nearly there.**
* **Identity gates are at PROVISIONAL / PASSED-narrowed, none STABLE-ESTABLISHED**
  (Gate 1 PROVISIONAL, Gate 2 PASSED (narrowed), Gate 3 PROVISIONAL) **[DOC: roadmap]**.
* **WFS, not OFS**: diagonal lifts and uniqueness-up-to-iso exist, but unique diagonal
  fills are unproved; the module name `EchoOrthogonalFactorizationSystem` overstates the
  target (renaming pending) **[DOC: README caution block]**.
* **Lane 1 (type-theoretic standing) is IN-REPO CLOSED, EXTERNALLY OPEN** — the paper is a
  living draft; the offline half (submission, DOI, packaging) is author-driven **[DOC]**.
* `experimental/echo-additive` (7 modules incl. the `Grade` dioid) is **in no CI lane**
  **[ISSUE #321]**; 4 bit-narrowing modules are similarly unlaned **[ISSUE #320]**.
* Doc/toolchain debts: `README.adoc` still carries RSR `{{PLACEHOLDER}}` template material
  while `README.md` is canonical **[RAN: file read]**; `agda.yml` installs an unpinned
  `apt-get agda` **[ISSUE #322]**; governance red on `CONTRIBUTING`/gitleaks
  **[ISSUE #323]**; CodeQL startup-failure **[ISSUE #269]**.

**Within reach.** Rename to honesty (`EchoWeakFactorizationSystem`); wire the unlaned
experimental modules into CI; clear the packaging/DOI half of Pillar E; refresh
`README.adoc` out of template state.

**Open research (not reachable by wiring).** Bachmann–Howard `ψ₀(Ω_ω)` order-type fidelity
(D-2026-06-14, *OPEN* — `ε₀ ≪ Γ₀ ≪ …`); the two quarantined postulates in
`Ordinal/Buchholz/Fidelity.agda`; the `∥_∥` image truncation (cannot be built under
`--safe --without-K` without HITs — present only in a `--cubical` island); the unbudgeted
global `wf-<ᵇʳᶠ` (walled: the native order is ordinally unsound, with a documented
counterexample).

---

### 2.2 `epistemic-types` — small, self-contained, genuinely green

**What it is.** A minimal-of-design Agda prototype for standpoint-indexed modalities,
separating knowledge (factive) from belief (non-factive) and warrant from sound proof.
The base modality is deliberately **not** a monad or comonad.

**There (established).**
* The **whole library type-checks under `--safe` with zero postulates and no standard
  library** (`--no-libraries`, only `Agda.Builtin.*`), and the **hosted `Proof Safety` job
  is green on the current HEAD**: run `37187387026` @ `eb810d4e`, 2026-10-04 **[CI]**.
* Module inventory is concrete: 17 modules listed in STATE, including `Base`, `Warrant`,
  `Access`, `ProofTransport`, `ReadConsistency`, `EchoBridge`, `SurrealBridge`, and an
  Applications layer **[DOC]**.
* The **Applications layer (2026-09-27)** is a real worked result, not a demo:
  `QCriterion.qBound-≤-Q` over an arbitrary `OrderedGroup`; `RapidNJSkip` generating a
  warrant from a skip certificate with `skip-known` proved; `IntegerModel` discharging the
  arithmetic budget; a rejection fixture for an unchecked check **[DOC: PROOF-STATUS]**.
* Explicit non-claims are recorded: no ℚ instance, no rescaling transport, no row-insertion
  update, no cross-iteration bound reuse **[DOC]**.
* Concrete Echo adapter: `SurrealBridge` relaxes a proved upper bound on a residue measure
  along the access order while preserving the retained value; the `daySurrealAccess`
  instance is explicitly a set-sized fragment, *not* the Conway proper class **[DOC]**.
* `ReadConsistency` was corrected so `ReadView` entails equality with indexed store
  contents; the older version-only relabelling and free `Sync` witness were **removed**
  **[DOC]**.

**Nearly there.**
* STATE calls it `prototype` / `experimental` at **35% completion**, last-updated
  2026-10-04 — i.e. the repo itself does not claim maturity **[DOC: STATE.a2ml]**.
* The Applications obligations are named but unmet (rational instance, rescaling
  transport, row-insertion invariants).
* The proof-transport soundness story is qualified ("holder-dependent transfer is
  explicitly qualified") **[DOC]**.

**Within reach.** Close the named Applications obligations; settle the secret-types
handover (epistemic-types#32 transfer is blocked on GitHub issue-write access — an
**administrative** blocker, not a technical one) **[DOC/ISSUE]**.

**Open research.** Whether `bind`/`extract` structure is wanted at all (currently a
deliberate "future commitment, not a hidden assumption"); the soundness map from evidence
to claim meaning under a standpoint index.

---

### 2.3 `residual-evidence-types` — newest, fastest-moving, and the only family with a machine-checked *correspondence*

**What it is.** Evidence-indexed residual types: which worlds are compatible with an
observation *and* its declared evidence constraints, and what holds for all of them.
Founded 2026-09-09 from imported Windows-Downloads material (assessment + a standalone
HTML/JS explorer), with **all core work newly written in-repo**.

**There (established).**
* **Milestone 1** — presence without identification (`u+n=2`, `n≤1` establishes `u≠0`
  while `(1,1)` and `(2,0)` still disagree), evidence-refined fibre round trips,
  conditional actual-world soundness, claim transport under refinement; three invalid
  modules must be rejected by Agda **[DOC]**.
* **Milestone 2** — contexts of assumptions with thinnings, dependency-preserving
  composition and coarsening, constructive revision and retraction, **a certified finite
  checker proved equivalent to the explorer by `refl` over all 546 configurations**
  (`Correspondence.checker-matches-explorer`), and nine expected-rejection controls
  **[DOC]**.
* **Both sibling interfaces are actually imported** — Echo's fibre packaging round-trips,
  and Epistemic's `SoundWarrant` requiring explicit actual-world premises — pinned to
  sibling heads (`echo-types` `9c4b72b5`, `epistemic-types` `dd948fbd` for M1) **[DOC]**.
* Hosted **`Agda proofs` job green** on the current HEAD: run `36949121242` @ `62d74907`,
  2026-10-02, and a prior receipt run `36740394802` @ `befdf964` **[CI/DOC]**.
* The repo is scrupulous about the limit: the correspondence certifies the *finite checker
  against the explorer*, **not** the ℕ core against the explorer **[DOC]**.

**Nearly there.**
* `STATE.a2ml` (last-updated 2026-09-09) is **stale**: it still lists composition,
  revision/retraction, the certified checker and the explorer correspondence as *pending*
  — all of which Milestone 2 landed **[RAN: file read vs PROOF-STATUS]**.
* The two sibling comparisons cover **Milestone 1 only**; whether composition/revision need
  an interface beyond `Echo.Echo` and `SoundWarrant` is the explicitly open question
  **[DOC]**.
* A separate "starter archive" named in the imported assessment has **not been recovered**
  and the repo does not pretend otherwise **[DOC]**.
* Codeac status has been pending on main since 2026-09-24 **[ISSUE #11]**.

**Within reach.** Refresh STATE; run comparisons 2.0 (post-M1 interfaces); the explorer's
signed −6..6 model is already the certified finite object, so further finite-model checks
are cheap.

**Open research.** Causal specialisation and probability adapters — both explicitly require
models and obligations of their own **[DOC]**.

---

### 2.4 `choreographic-types` — a pre-registration, and it says so

**What it is.** The assembly hypothesis: grade a global choreography with echo *loss-grades*
and epistemic *standpoint-warrants*, project to participants, and ask whether grading and
transport commute with projection across a consistent frontier (a *cut*). The keystone is
**K-CUT**, split into K-CUT-LOSS (equality) and K-CUT-WARRANT (bound, under a `SoundWarrant`
side-condition).

**There (established).**
* **The specification and its fences.** The pre-registration (2026-10-03) states that
  K-CUT-LOSS and K-CUT-WARRANT remain **OPEN**, that `SoundWarrant` is an *assumed
  receiver-local side-condition*, and that the application Agda file **"contains postulates,
  not proofs"** and is not imported by any build **[DOC: docs/pre-registration.adoc]**.
* `CITATION.cff` no longer claims a completed Agda formalisation; integrity checks now fail
  such claims on description-mirroring surfaces **[DOC]**. Issue #15 records that the
  README/description still overstate **[ISSUE]**.
* CI's two substantive checks — `Secret Scanner` and `Documentation Integrity` — are both
  green **[CI]**. There is **no prover workflow at all**, by design at this stage.

**Nearly there.**
* The **degenerate base case exists and is real**, but it is a sibling's theorem:
  `characteristic/RoleGraded.choreo-grade-commute` in `echo-types` — two actions (role
  transport × grade degradation) commuting on one Echo-indexed family, satisfying the
  "same data" test that struck down the earlier N3 nominee **[DOC/RAN: file read]**.
  It is a *single-static-edge integration theorem*, not K-CUT. echo-types' own audit
  **declined to adopt it as nominee N5** on the grounds that its only non-trivial cell is
  already credited elsewhere (adoption would be cosmetic) **[DOC: N5Falsifier, IntegrationAudit]**.
* The smallest concrete target is specified: a two-event K-CUT-LOSS commuting square under
  an `Independent₂` witness, with the witness required to carry disjoint read/write
  footprints, phase safety and a deterministic tie policy **[DOC]**.
* A vocabulary obligation is open: the choreographic README's phrase "echo loss-grade"
  conflicts with the estate's separation of echo index / residue measure / resource grade;
  reconciling it is a **coordination task** in the hub roadmap **[DOC: TYPE-CONNECTIONS]**.

**Within reach.** Wire the existing `rapidnj-two-thread.agda` postulates into a real
minimal proof of the two-event square; land the `Independent₂` witness; reconcile the
vocabulary with the shared glossary. None of that requires solving K-CUT.

**Open research.** K-CUT in general (both fragments) — the repo's own honest position is
that the general result is open and only degenerate single-static-edge cases exist.

---

### 2.5 `tropical-types` — dual-formalised, one half verified, one half CI-gated-by-claim

**What it is.** Max-plus / min-max algebra applied to resource-aware typing: compositional
worst-case bounds for latency, stack use and adversarial round counts, plus a reusable
resource-grade axis for downstream languages. **Note the prover split**: this family is
**Lean 4 + Isabelle/HOL**, not Agda.

**There (established).**
* **Lean 4 — verified and CI-gated.** `lake build` green, no Mathlib, toolchain pinned in
  `lean-toolchain` (`v4.13.0`); hosted **`Lean` job green** on current main: run
  `37116071270` @ `ad7bfdfd`, 2026-10-03 **[CI]**. PROOF-STATUS records a clean rebuild of
  **20/20 targets** including `TropicalSessionTypes.lean` (max-plus session grading),
  `TropicalAdapterPath.lean` (min-max bottleneck transport + the `hub_ceiling` no-go),
  the `Resource/Algebra` interface with a **parametric transport theorem**, and concrete
  instances (MaxPlus, MinPlus, MinMax, Linear, Affine) **[DOC]**.
* The two twins are related by an order-reversing involution proved as a **lattice
  anti-isomorphism** and explicitly *not* a semiring homomorphism — a structural fact,
  stated as such **[DOC]**.
* `Resource/EchoBridge.lean` is an **echo-free residue-measure bridge** (no dependency on
  the echo-types Agda kernel; the relationship is at design level) **[DOC]**.

**Nearly there.**
* **The Isabelle half is not verified in the recon sense.** Nine `.thy` theories exist and
  the session is meant to be CI-gated by `just isabelle-build` + `just check-sorry`, but
  **no workflow mentions Isabelle**; `ROOT` lists **5 of 9** theories; PROOF-STATUS itself
  says the Isabelle side was *"NOT re-verified in this environment"* **[DOC]**.
* Issue #57 states the contradictions directly: the claim is CI-gated but nothing gates it,
  ROOT covers 5 of 9, and STATE says GREEN and RED for the same theory **[ISSUE]**.
* The `CI context contract` job is red on recent commits (required-status-check drift);
  it is the repo's own guard for `docs/CI-CONTEXTS.adoc` and it fails for that documented
  reason — a CI-hygiene red, not a proof red **[CI]**.
* The no-go theorem `hub_ceiling` refutes Protocol Squisher's universal-interoperability
  claim — real, but it is a *no-go*, not a capability **[DOC]**.

**Within reach.** Extend `ROOT` to all nine theories; add the Isabelle job; delete the
residual Deno test files (Deno is banned estate-wide **[ISSUE #58]**); SHA-pin the two
tagged `actions/checkout` uses **[ISSUE #59]**.

**Open research.** The Buchholz-collapsing ladder (Rungs 2–N, 0% per STATE); tropical time
series (Diehl–Ebrahimi-Fard–Tapia); a probabilistic extension; a Lean tactic for automated
grade calculation.

---

### 2.6 `occupancy-types` (this repo) — pre-registered, locally reproducible, CI-disarmed

**What it is.** Stepwise resource-bounding types: deterministic memory first, network
second. The organising claim is that **cost and state are different axes**: cost composes
with `+` in sequence and `max` across alternatives (tropical), while *state* resources
(pools, buffers, credits, FDs) compose by the **non-commutative high-water-mark monoid**
`(p₁,n₁)·(p₂,n₂) = (max(p₁, n₁+p₂), n₁+n₂)`. Buffer = memory, and the **protocol frontier
is the reclamation point**. The whole thing is pre-registered in `ULTRAPLAN.md` with
per-rung kill criteria and a decision log (D1–D7).

**There (established).**
* **R0-B, Phase 1 — Session IR checker: TESTED. I re-ran it in this session:**
  `PYTHONPATH=src python3 -m session_ir test examples/session_ir/manifest.json` →
  **14/14 PASS**, exit 0 **[RAN]**. Seven accept cases with measured steps ≤ certified
  bound (including a strict case: certify 5 / measure 4, and a tight case: 6/6) and seven
  expected-rejection controls each pinning an error class (double-send, use-after-drop,
  protocol mismatch, close-before-End, double-free, leak, alias) **[RAN]**.
* The operational model exists and its Phase-0 kill test is **mechanically audited**
  (four sentences, banned word absent) **[DOC: EXPLAINME C3]**.
* The honesty apparatus is real and already in use: `docs/EXPLAINME.adoc` classifies every
  claim as TESTED / UNVERIFIED / CONJECTURE, and `docs/retraction-ledger.adoc` records
  blocked rungs (with exact unblocking commands) separately from retractions — with **zero
  retractions so far** and three blocked items **[RAN: file read]**.
* The estate placement is correct and deliberate: registered against the cost/state
  vocabulary split, with "not echo, not warrant, not residue" written into the plan
  **[DOC: ULTRAPLAN §5]**.

**Nearly there (blocked, not disproved).**
* **Idris 2 Occupancy spike — UNVERIFIED.** `src/occ/Occ.idr`, `Demo.idr` (static peak = K
  = 2 producer/consumer) and four rejection controls exist; no `idris2` on the work
  environment's PATH **[DOC/RAN: toolchain check]**. The kill question (are constant grades
  tolerable *and tight*?) is answered only provisionally, and the repo labels the answer
  CONJECTURE.
* **R1 stackcert — UNVERIFIED.** `src/stackcert/StackcertCore.lean` with the target theorem
  `cert_sound`, plus fixtures generated by real `gcc -fcallgraph-info=su -fstack-usage`
  **[DOC]**, but no `lean` locally and no `#print axioms` footprint pasted. The expected
  empty axiom list is **explicitly marked CONJECTURE until pasted** **[DOC: EXPLAINME C5]**.
* **Ground truth — BLOCKED.** Zephyr painted-stack HWM on `qemu_cortex_m3` is a **fixture
  request**; nothing is measured until it runs. The plan's own rule is "measured ≤ certified
  on every run, violation = stop" — so R1 cannot be *closed* without this **[DOC]**.
* **CI is comprehensively non-functional.** 96 of the last 100 workflow runs on this repo
  concluded `startup_failure`, including on `main` pushes by the owner actor; **every**
  gate — Rust CI, Dogfood, Static Analysis, Invisible Character Detection, K9, Secret
  Scanner — dies before starting a job **[CI/API]**. The estate has two *documented*
  mechanisms that produce exactly this signature: (a) an Actions allow-list posture of
  `selected` with **0 patterns**, which kills any workflow whose step references a
  non-allow-listed action, `jobs=0` (choreographic-types#16, with a produced mutant
  proof); (b) an actor gate refusing workflow triggering for a given actor
  (echo-types#330). The precise gate for *this* repo is **not established** from here, and
  unlike its siblings this repo carries **no open issue** about it (it has no open issues
  at all). Consequence: **none of this repo's checks are currently machine-enforced**;
  the local gates are the only source of truth.
* `README.adoc` is still RSR template material (self-declared in-file) **[RAN]**.

**Within reach (needs a toolchain or a settings change, not research).** Install
`idris2` → run the spike and its four controls; install `lean`/`lake` → run stackcert and
paste `#print axioms cert_sound`; obtain the Zephyr fixture; fix the Actions settings
(owner-only PUT) and file the missing issue for this repo; refresh `README.adoc` from the
template.

**Open research (the actual rungs).** R2 static pools + affine/linear handles with the T1
coherence theorem (project gate after R2); R3 binary session channels with HWM buffer
grades; R4 network-calculus curves over ℕ/ℤ without reals; R5 multiparty projection and the
projection/grade commutation question; Phase 5 host-tool contract. The pre-written kill
criteria are, correctly, part of the design: R2 archives the project if there is no external
consumer for certificates and no theorem beyond restatement.

---

### 2.7 `absolute-zero` — the most *concretely* verified repo in the estate

**What it is.** Two co-equal pillars — **CNO** (a program that provably does nothing to the
world) and **OND** (a program whose observable trace is constant over its secret input,
relative to a declared observation model `O`). The pillars are logically independent (a
proved theorem) and joined by a *coupling dial* that is explicitly **framing, not theorem**.

**There (established).**
* **A single gate reproduces everything locally**: `proofs/verify-all-provers.sh` →
  `ALL-PROVERS-GREEN` across **Coq, Agda, Lean 4 (+Mathlib), Z3, Isabelle/HOL, Mizar**, plus
  the **Idris 2 ABI**, with an absent prover treated as *failure, never skip* (since
  2026-09-23), Z3 verdicts checked against `; expect sat|unsat`, and a Coq
  `Print Assumptions` audit with its own control **[DOC: PROOF-STATUS]**. A gate self-test
  proves the gate turns red for each absent/failing prover and each verdict/audit mutant
  (16 cases, run in CI) **[DOC]**.
* **CI Proofs job green** on current main: run `37077637092` @ `5f271368`, 2026-10-02
  **[CI]**. The workflow runs the lightweight provers (Coq 14/14 theories, Agda CNO+OND,
  Z3 CNO+OND, Mathlib-free Lean core with an `AxiomAudit`); the heavy provers are covered
  only by the local container gate — and the workflow says so in its own header **[RAN:
  workflow read]**.
* **OND-1..5 and OND-7 are landed** — proved in Coq with **zero axioms** (every theorem
  `Closed under the global context`), mirrored in Lean 4, Agda and Z3 **[DOC]**.
* **CNO axiom discharge 98 → a small classified remainder**, with the pathological cases
  found and fixed rather than hidden: `no_cloning` and `Cconj_Cexp` were **provably false**
  and removed; `eta_equivalence` was **false as stated** (counterexample `f = LVar 5`) and
  replaced by an honestly guarded theorem **[DOC]**. Remaining axioms are tagged either
  `METAL-BOUNDARY` (genuine physics: `kB>0`, `temperature>0`, Second Law, Landauer) or
  *class-A* (true, provable in principle, listed with blockers — 4 items) **[DOC]**.
* An **Echo bridge exists in Agda** (`EchoBridgeCNO.agda`): `EchoRel` instantiated
  against real `CNO.Program`/`CNO.eval` with `CNO.state-eq` **[RAN: file read]**.
* Roadmap restraint is explicit: the long-horizon "universal CNO standard" is quarantined
  in an appendix as **aspirational and unfunded**, "a direction of travel, not a
  commitment with a date" **[DOC]**.

**Nearly there.**
* **OND-6** (conditional composition) is **open by design** — the research capstone. The
  roadmap warns, correctly, that if composition appears to hold as cleanly as for CNOs the
  result has almost certainly dropped a term **[DOC]**.
* **CI is weaker than the local gate** and the repo knows it: for a time Isabelle and Mizar
  printed "skipped" while the gate said GREEN; that is fixed in the local gate, but
  absolute-zero#161 records that the `Proofs` workflow still has a `paths:` filter,
  `z3 … || true`, and no assumption check **[ISSUE]**.
* **Documentation drift**: `ROADMAP.adoc` (last updated 2026-07-07) still lists as pending
  the Idris ABI repair and "make CI truthful: run Coq+Agda+Rust", both since superseded by
  `PROOF-STATUS` and the current workflow **[RAN: file comparison]**.
* 73 of 182 Coq theorems rest on axioms and 38 `Axiom`/`Parameter` declarations use four
  tag forms (unify grammar, generate census) **[ISSUE #171]**; 2 Idris2 postulates in
  `src/abi/Layout.idr` remain **[ISSUE #27]**; Scorecard has 5 high alerts **[ISSUE #170]**.

**Within reach.** Make CI mirror the local all-provers gate (fix #161); unify the axiom tag
grammar and publish the census (#171); port the Coq filesystem model to Lean so the
`FilesystemCNO` law axioms become theorems (#167); refresh the roadmap against PROOF-STATUS;
the artifact-evaluation one-command container.

**Open research.** OND-6 conditional composition; the 4 class-A Coq items
(`CNOT_gate_unitary`, `unitary_inverse_property`, `fidelity_bound` need a finite-dim/tensor
model; `y_not_cno` needs a coinductive/step-indexed β non-termination argument); the paper.

---

## 3. The hub, the satellites, and the name-collisions

### 3.1 `nextgen-typing` (coordination) — the map is the artefact

* Hosts the shared glossary, ownership routing and the **XP-1 cross-project proof**
  (`verification/proofs/agda/EchoTyping.agda`, `--safe --without-K`, spanning echo-types ↔
  affinescript ↔ typed-wasm) **[DOC]**.
* **But nothing runs it**: nextgen-typing#57 records that no CI job runs
  `just proof-check-all` **[ISSUE]**. The estate's only cross-project proof is therefore
  unenforced.
* Open coordination tasks relevant to the family: **#118** register `occupancy-types` in
  the type map + cost/state vocabulary split + boundary notes (**this repo is not yet
  registered**); **#115** re-cite the residual receipt and give the Echo→Residual /
  Epistemic→Residual obligations acceptance criteria; **#69** verify and GPG-sign the
  per-repo AFFIRMATIONs in-env; **#117/#121** two pre-existing CI reds.
* The hub's own readiness self-assessment is **Grade C** ("dogfooded, CI passing"), and its
  stated path to Grade B is *external adoption* — 6+ diverse external targets **[DOC]**.
  That is the estate's own statement that the gap between "internally coherent" and
  "externally established" is a **consumption** gap, not a proof gap.

### 3.2 Satellites

| Repo | Role | Position |
|---|---|---|
| **EchoTypes.jl** | Executable finite-domain shadow of Echo's Tier-1/2 spine | Explicitly *not a proof*; can falsify, cannot prove; honestly scoped under R-2026-05-18 — does **not** replay the retracted surface or the funext-qualified clauses **[DOC]** |
| **EpistemicTypes.jl** | The strongest **consumer story** in the estate: per-row receipts (standpoint, warrant, projection, SHA-256 seal) and an epistemic status per taxonomy call | README-level claim; not re-verified here **[DOC]** |
| **ResidualEvidenceTypes.jl** | Julia companion to the residual work | Young (created 2026-09-30), 4 commits since 2026-09-01 **[API]** |
| **secret-types** | New home for confidentiality-labelled flow + audited declassification | Specification-stage; no checker or runtime **[DOC]** |

**Name-collision warning (worth keeping straight):** `ZeroProb.jl` (measure-zero events) and
`zerostep` (a VAE dataset normaliser) are **not** members of this family; they are adjacent
by name only. Likewise `katagoria` (historical name) resolves to `ideas-to-alphas` and is
**not** `kategoria`; `tropical-resource-typing` resolves to `tropical-types` **[DOC:
nextgen-typing naming note 2026-09-09]**.

### 3.3 The consumer chain (the "near zone beyond" that matters)

```
katagoria → typell (kernel) → typed-wasm (target) → PanLL (environment) → affinescript / ephapax / phronesis
```

The estate's own fence is firm: **a conceptual arrow in the map does not establish that any
family is integrated into these projects** **[DOC: TYPE-CONNECTIONS]**. Integration that
*has* happened is recorded in echo-types' bridge ledger: `EchoTyping.agda` in
nextgen-typing, `PhronesisEcho.agda` in phronesis, a machine-checked `EchoBridge.agda` in
nextgen-languages/kitchenspeak, and a Rust application example in invariant-path **[DOC]**.

---

## 4. The cross-cutting position — what is safe to say

### 4.1 What the estate can claim today, without hedging

1. **Five of the seven repos have a green proof job on their current main**:
   echo-types (Agda, `37152181722`), epistemic-types (Proof Safety, `37187387026`),
   residual-evidence-types (Agda proofs, `36949121242`), absolute-zero (Proofs,
   `37077637092`), and tropical-types' **Lean** half (`37116071270`) — with tropical's
   Isabelle half unverified by its own admission. The two without one are
   choreographic-types (deliberately: no prover workflow exists yet) and occupancy-types
   (whose CI is disarmed, below).
2. **The honesty apparatus is real, not decorative.** Retractions actually happened and are
   load-bearing (echo-types R-2026-05-18); false axioms were actually found and removed
   (absolute-zero: 3 latent-unsound axioms); stale claims are actually corrected
   (epistemic-types removed the free `Sync` witness; choreographic-types retired its
   CITATION claim). Ledger entries separate *blocked* from *retracted*.
3. **The separations are the substance.** Each family earns its identity by
   matched-negatives (Echo vs entropy/LL/resource-instance), by conditionality (Epistemic:
   warrant ≠ sound proof), by no-go (Tropical: `hub_ceiling`), or by proved *non-*
   composition (absolute-zero OND-5).
4. **The estate's own claims are unusually well fenced.** Where something is degenerate,
   provisional, gated, or unverified, there is usually a document saying so — frequently
   more conservative than the README.

### 4.2 What the estate must not claim today

* **No external validation yet.** echo-types' Lane 1 is *in-repo closed, externally open*;
  nextgen-typing's path to Grade B is external adoption; nothing here is submitted,
  accepted, or DOI-minted.
* **No general K-CUT.** Only degenerate single-static-edge base cases exist, and the
  strongest of those has been declined as a gate nominee *by its own repo*, for good reason.
* **No established cross-prover equivalence.** tropical-types says the Lean and Isabelle
  developments intend to agree but equivalence is not mechanically established; each
  prover checks its own development.
* **No established bridge by arrow.** The five family connections in the map are
  obligations, not results (Echo→Choreographic and Epistemic→Choreographic have *no* proof;
  Echo→Residual and Epistemic→Residual cover Milestone 1 only; Tropical→Choreographic needs
  a grading semantics + projection theorem).
* **No "six provers in CI" for absolute-zero.** Six provers are green *via the local gate*;
  CI covers the lightweight subset, and the local gate has not been run here.

### 4.3 The one systemic blocker with the highest leverage

**The CI estate is partially disarmed, and the pattern is already diagnosed.**

* **occupancy-types**: 96/100 recent runs `startup_failure`; every gate dead; no issue filed
  for this repo **[CI/API]**.
* **choreographic-types#16** documents mechanism (a): Actions allow-list `selected` with
  **0 patterns** → any third-party action dies at startup, `jobs=0`, with a produced mutant
  proof on residual-evidence-types (same head, one `uses:` step toggled, `startup_failure`
  ⇄ green). Fix is an **owner-only PUT** of the canon payload. The repo explicitly notes
  this is *silent* until the first third-party action.
* **echo-types#330** documents mechanism (b): an actor gate refusing workflow triggering for
  `arena-ai-coding-agent`, so PRs can merge with **zero** CI signal. Its recommended
  mitigation — treat `STARTUP_FAILURE` as failure for required checks — is generally
  applicable.
* **echo-types#324** / **tropical-types#59** record allow-list/count and pinning drift.

Practical consequence for planning: **for these repos, a green badge is not evidence until
the underlying workflow actually started.** The recon above therefore cites run ids, not
badges.

### 4.4 Planned already (named, in-tree, not speculation)

| Where | Named next step |
|---|---|
| nextgen-typing | register `occupancy-types` in the type map (#118); reconcile the choreographic "echo loss-grade" vocabulary; re-cite residual receipts (#115); sign AFFIRMATIONs (#69); build `verification/proofs` in CI (#57) |
| echo-types | Gate re-assessment at each tag; rename the WFS module; land unlaned experimental modules (#320/#321); Pillar E offline half |
| epistemic-types | Applications obligations (ℚ/rescaling/row-insertion); secret-types #32 transfer |
| residual-evidence-types | Comparisons 2.0 beyond M1 interfaces; refresh STATE; causal specialisation as its own model |
| choreographic-types | Two-event K-CUT-LOSS square under `Independent₂`; vocabulary reconciliation |
| tropical-types | ROOT → 9 theories + Isabelle job (#57); Deno removal (#58); SHA pins (#59) |
| occupancy-types | Idris spike run; stackcert run + `#print axioms`; Zephyr fixture; Actions settings; then the R2 project gate |
| absolute-zero | CI mirrors the local gate (#161); axiom tag census (#171); filesystem model → Lean (#167); the paper |

### 4.5 The near zone beyond (what the estate is one or two steps from)

1. **Interfaces, not just imports.** residual-evidence-types already *imports*
   `Echo.Echo` and `SoundWarrant` and proved round trips. The question it asks itself — does
   composition/revision need a richer interface than `Echo.Echo`/`SoundWarrant`? — is
   answerable now, and its answer would settle three of the five map obligations.
2. **Turn proofs on.** Wiring the existing proofs into CI (nextgen #57, tropical #57,
   occupancy's settings) converts several [DOC] claims into [CI] claims at near-zero
   research cost.
3. **Two K-CUT-LOSS squares.** The two-event square is specified at the level where it can
   be proved today; a second, non-degenerate pattern would test whether the
   single-static-edge degeneracy is essential or incidental — the cheapest experiment that
   could falsify the assembly hypothesis early.
4. **Cost vs state as a testable separation.** `occupancy-types` claims the HWM monoid is a
   *different* axis from tropical cost, with witnesses; the estate already has both halves
   in place (tropical-types' algebra; occupancy's session IR). A small composition whose
   HWM grade and cost grade cannot be identified would be the cleanest possible
   cross-family result — and it is a *separation*, so it is falsifiable cheaply.
5. **A consumer.** Every family's honest bottleneck is the same one the hub names: nobody
   outside the estate is consuming this yet. `EpistemicTypes.jl` (per-row classifier
   receipts) and occupancy's session IR (certificates over measured bounds) are the two
   most consumer-shaped artefacts in the estate.

---

## 5. One-table position summary

| Repo | Established (receipt) | Nearly there | Within reach | Open research |
|---|---|---|---|---|
| **echo-types** | Agda suite green under `--safe --without-K` (`37152181722`); 209 `.agda` files; separations; retraction-disciplined | Gates provisional; WFS-not-OFS naming; unlaned modules; `README.adoc` template drift | Rename; lane the modules; packaging/DOI | Buchholz `ψ₀(Ω_ω)`; 2 Fidelity postulates; truncation under −K |
| **epistemic-types** | Whole library green, zero postulates, no stdlib (`37187387026`); RapidNJ Q-criterion warrants | 35% prototype; applications obligations unmet | Close named obligations; secret-types transfer | Monad/comonad structure; evidence→claim soundness |
| **residual-evidence-types** | M1+M2 checked; 9 rejections; 546-config correspondence by `refl`; both sibling interfaces imported (`36949121242`) | STATE stale; comparisons cover M1 only | Refresh STATE; comparisons 2.0 | Causal specialisation; probability adapters |
| **choreographic-types** | Specification + fences; docs integrity green; the *reason* it exists is one theorem | Degenerate base case (real, sibling-side, declined as a gate nominee) | Two-event square; `Independent₂`; vocabulary fix | K-CUT-LOSS / K-CUT-WARRANT general case |
| **tropical-types** | Lean green, 20/20, no Mathlib (`37116071270`); `hub_ceiling` no-go; parametric transport | Isabelle 9 theories, ROOT 5/9, **no CI job**; `CI context contract` red | ROOT→9; Isabelle job; Deno removal; SHA pins | Buchholz ladder; time series; probabilistic extension |
| **occupancy-types** | Session IR 14/14 **[RAN]**; operational model; ledger with blocked ≠ retracted | Idris spike + stackcert + Zephyr fixture all UNVERIFIED; **CI 96/100 startup_failure** | Install toolchains; run; paste `#print axioms`; fix Actions; file the issue | R2–R5 rungs; cost/state separation as a theorem |
| **absolute-zero** | Six provers + Idris green *locally*; CI Proofs green (`37077637092`); OND-1..5,7 zero-axiom; 98→classified axioms; 3 unsound axioms fixed | OND-6 open by design; CI narrower than the local gate; roadmap drift | #161, #171, #167; roadmap refresh; artifact package | OND-6; 4 class-A Coq items; the paper |

---

## 6. Method and limits of this recon

* Read: full repo trees (shallow clones at the pins above), all top-level status documents
  (README, PROOF-STATUS, AFFIRMATION, ROADMAP, ULTRAPLAN, EXPLAINME, STATE.a2ml,
  pre-registration, retraction ledger), the hub's TYPE-CONNECTIONS guide and roadmap, and
  the workflow files.
* Queried: GitHub Actions run history and conclusions per repo (not badges), open issues
  and key issue bodies, commit dates, signatures and HEAD SHAs, toolchain availability
  locally.
* Ran: the only proof-adjacent gate runnable without a prover toolchain —
  `occupancy-types`' Session IR manifest (14/14). Everything else in this document that is
  not marked **[RAN]** rests on **[CI]**, **[DOC]** or **[ISSUE]** evidence as tagged.
* Not done: no Agda/Lean/Isabelle/Coq/Mizar/Z3 re-run; no `just check` anywhere; no
  evaluation of proof *quality* beyond what the repos' own guardrails (postulate/escape
  greps, kernel certificates, axiom audits) enforce; no attempt to resolve the
  occupancy-types Actions gate (owner-only API surface).
* Everything above is dated 2026-10-04 and pinned by the SHAs in §0. Move the SHAs and it
  becomes a draft until re-run — which is exactly the estate's own rule for AFFIRMATIONs,
  and a good rule for this document too.
