/-
SPDX-License-Identifier: MPL-2.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)

StackcertCore — verified core of the stack-depth certificate checker
(ULTRAPLAN R1).  Zero imports (no Mathlib), no admitted lemmas, no classical
axioms.  Verify with: `lean StackcertCore.lean` and read the `#print axioms`
output at the bottom of this file.

Model (mission statement, made precise):

  frame   : Fn -> Nat        -- stack bytes of the function's own frame
  callees : Fn -> List Fn    -- direct callees, treated as a set
  cert    : Fn -> Nat        -- claimed bound per function

Rule (per function v):

  cert v >= frame' v + max_{u in callees v, u != v} cert u

where frame' v is the frame inflated by an annotated direct self-recursion
depth d (frame' v = (d+1) * frame v).  A self-call edge without an annotation
is rejected (selfOk).  Any other cycle makes the rule unsatisfiable for
finite certificates (summing inequalities around the cycle gives 0 > 0), so
"reject all other cycles" holds semantically; the CLI additionally reports
them explicitly.

cert_sound: if `check` accepts, then for every call path starting at an
enrolled function, the sum of inflated frames along the path (its stack cost)
is <= the certificate of the start function.  Real stack usage with self-
recursion bounded by the annotation is bounded by this inflated cost, since
each visit to v contributes at most (d+1) frames of size frame v.

Nothing here is reported as verified until the toolchain command above has
run; see README.adoc for status.
-/

namespace StackcertCore

/-! ## Boolean/list helpers (local, so the proof owns its plumbing) -/

def allb {α : Type} (p : α → Bool) : List α → Bool
  | []      => true
  | x :: xs => p x && allb p xs

def memB [DecidableEq Fn] (x : Fn) (l : List Fn) : Bool :=
  l.any (fun y => decide (y = x))

theorem and_true : ∀ {a b : Bool}, a && b = true → a = true ∧ b = true := by
  intro a b h
  cases a with
  | false => cases h
  | true =>
    cases b with
    | false => cases h
    | true  => exact ⟨rfl, rfl⟩

theorem allb_mem {α : Type} (p : α → Bool) :
    ∀ (l : List α) (x : α), allb p l = true → x ∈ l → p x = true := by
  intro l
  induction l with
  | nil => intro x hx hm; cases hm
  | cons y ys ih =>
    intro x hx hm
    have hp : p y = true ∧ allb p ys = true := and_true hx
    cases hm with
    | head _ => exact hp.1
    | tail _ _ hm' => exact ih x hp.2 hm'

theorem memB_sound [DecidableEq Fn] :
    ∀ (l : List Fn) (x : Fn), memB x l = true → x ∈ l := by
  intro l
  induction l with
  | nil => intro x hx; simp [memB] at hx
  | cons y ys ih =>
    intro x hx
    have hy : (decide (y = x) || memB x ys) = true := by
      simpa [memB] using hx
    cases hyx : decide (y = x) with
    | true =>
      have heq : y = x := of_decide_eq_true hyx
      rw [← heq]
      exact List.Mem.head ys
    | false =>
      have hrest : memB x ys = true := by
        simp [hyx] at hy
        exact hy
      exact List.Mem.tail y ys (ih x hrest)

/-! ## Model -/

/-- Call graph over function names.  `callees` is a Finset in the mission
statement; lists-as-sets suffice here (duplicates are harmless). -/
structure CallGraph (Fn : Type) where
  fns     : List Fn
  frame   : Fn → Nat
  callees : Fn → List Fn

/-- Annotations.  `selfDepth v = some d` declares direct self-recursion of
depth d at v.  The rest of the annotation file (indirect targets, ISR levels,
threads) is CLI-level input and does not enter the theorem. -/
structure Annot (Fn : Type) where
  selfDepth : Fn → Option Nat

variable {Fn : Type} [DecidableEq Fn]

/-- Self-edges are legal only under an explicit depth annotation. -/
def selfOk (g : CallGraph Fn) (a : Annot Fn) (v : Fn) : Bool :=
  if (g.callees v).any (fun u => decide (u = v)) then (a.selfDepth v).isSome
  else true

/-- Frame inflated by annotated self-recursion depth. -/
def iframe (g : CallGraph Fn) (a : Annot Fn) (v : Fn) : Nat :=
  match a.selfDepth v with
  | some d => (d + 1) * g.frame v
  | none   => g.frame v

/-- max of `cert u` over callees of `v` other than `v` itself (0 if none). -/
def maxExcept (cert : Fn → Nat) (v : Fn) : List Fn → Nat
  | []      => 0
  | u :: us => if u = v then maxExcept cert v us
               else max (cert u) (maxExcept cert v us)

theorem cert_le_maxExcept (cert : Fn → Nat) (v : Fn) :
    ∀ (l : List Fn) (u : Fn), u ≠ v → u ∈ l → cert u ≤ maxExcept cert v l := by
  intro l
  induction l with
  | nil => intro u hne hm; cases hm
  | cons y ys ih =>
    intro u hne hm
    cases hm with
    | head _ =>
      -- u is y, and y ≠ v, so the fold head is max (cert y) (...)
      show cert y ≤ (if y = v then maxExcept cert v ys
                     else max (cert y) (maxExcept cert v ys))
      if hyv : y = v then
        rw [if_pos hyv]
        exact absurd hyv hne
      else
        rw [if_neg hyv]
        exact Nat.le_max_left _ _
    | tail _ _ hm' =>
      show cert u ≤ (if y = v then maxExcept cert v ys
                     else max (cert y) (maxExcept cert v ys))
      if hyv : y = v then
        rw [if_pos hyv]
        exact ih u hne hm'
      else
        rw [if_neg hyv]
        exact Nat.le_trans (ih u hne hm') (Nat.le_max_right _ _)

/-- The certificate rule at v: inflated frame plus the worst certificate of a
non-self callee is covered by cert v.  (Mission rule exactly when there is no
self-recursion and no annotation: iframe = frame, and max over all callees.) -/
def rule (g : CallGraph Fn) (a : Annot Fn) (cert : Fn → Nat) (v : Fn) : Bool :=
  decide (iframe g a v + maxExcept cert v (g.callees v) ≤ cert v)

/-- Every callee of an enrolled function is itself enrolled (resolution). -/
def closed (g : CallGraph Fn) (v : Fn) : Bool :=
  allb (fun u => memB u g.fns) (g.callees v)

/-- The checker.  Accepts exactly when every enrolled function is
self-recursion-annotated where needed, satisfies the rule, and has resolved
callees. -/
def check (g : CallGraph Fn) (a : Annot Fn) (cert : Fn → Nat) : Bool :=
  allb (selfOk g a) g.fns
  && allb (rule g a cert) g.fns
  && allb (closed g) g.fns

/-! ## Paths and stack cost -/

/-- A call path is a nonempty chain of direct calls starting at `v`, never
traversing a self-edge (self-recursion is folded into `iframe`). -/
inductive Path (g : CallGraph Fn) : Fn → Type where
  | leaf (v : Fn) : Path g v
  | step (v u : Fn) (hne : u ≠ v) (hu : u ∈ g.callees v)
         (p : Path g u) : Path g v

/-- Stack cost of a path: sum of inflated frames along the way. -/
def cost (g : CallGraph Fn) (a : Annot Fn) : {v : Fn} → Path g v → Nat
  | v, Path.leaf _       => iframe g a v
  | v, Path.step _ u _ _ p => iframe g a v + cost g a p

/-! ## Soundness -/

theorem cert_sound (g : CallGraph Fn) (a : Annot Fn) (cert : Fn → Nat)
    (h : check g a cert = true) :
    ∀ (v : Fn), v ∈ g.fns → ∀ (p : Path g v), cost g a v p ≤ cert v := by
  have hsplit :
      allb (selfOk g a) g.fns = true
      ∧ allb (rule g a cert) g.fns = true
      ∧ allb (closed g) g.fns = true := by
    have h1 := and_true h
    have h2 := and_true h1.1
    exact ⟨h2.1, h2.2, h1.2⟩
  have hrule : ∀ w ∈ g.fns, rule g a cert w = true :=
    fun w hw => allb_mem (rule g a cert) g.fns w hsplit.2.1 hw
  have hcl : ∀ w ∈ g.fns, closed g w = true :=
    fun w hw => allb_mem (closed g) g.fns w hsplit.2.2 hw
  intro v hv p
  revert hv
  induction p with
  | leaf w =>
    intro hw
    have hr : rule g a cert w = true := hrule w hw
    have hle : iframe g a w + maxExcept cert w (g.callees w) ≤ cert w :=
      of_decide_eq_true hr
    exact Nat.le_trans (Nat.le_add_right _ _) hle
  | step w u hne hu p ih =>
    intro hw
    have hr : rule g a cert w = true := hrule w hw
    have hle : iframe g a w + maxExcept cert w (g.callees w) ≤ cert w :=
      of_decide_eq_true hr
    have hall : allb (fun x => memB x g.fns) (g.callees w) = true := by
      exact hcl w hw
    have hmem : memB u g.fns = true := allb_mem _ (g.callees w) u hall hu
    have hufn : u ∈ g.fns := memB_sound g.fns u hmem
    have hcu : cert u ≤ maxExcept cert w (g.callees w) :=
      cert_le_maxExcept cert w (g.callees w) u hne hu
    have hbody : cost g a p ≤ cert u := ih hufn
    have hsum : iframe g a w + cost g a p
                ≤ iframe g a w + maxExcept cert w (g.callees w) :=
      Nat.add_le_add (Nat.le_refl (iframe g a w)) (Nat.le_trans hbody hcu)
    exact Nat.le_trans hsum hle

end StackcertCore

#print axioms StackcertCore.cert_sound
