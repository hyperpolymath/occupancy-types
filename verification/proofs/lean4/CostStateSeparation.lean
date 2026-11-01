-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- A small, kernel-checked witness for the sequential case of max-plus
-- communication cost and occupancy HWM. This is an algebraic finite-witness
-- result, not a soundness theorem for the Session IR checker or stepper.

namespace CostState

/-- HWM footprint: peak additional live state, and net live-state change. -/
structure HwmFootprint where
  peak : Nat
  net : Nat
  deriving DecidableEq, Repr

def hwmSeq (a b : HwmFootprint) : HwmFootprint :=
  ⟨max a.peak (a.net + b.peak), a.net + b.net⟩

/-- A two-axis trace footprint. Cost composes additively; state uses HWM. -/
structure Footprint where
  communicationCost : Nat
  hwm : HwmFootprint
  deriving DecidableEq, Repr

def seq (a b : Footprint) : Footprint :=
  ⟨a.communicationCost + b.communicationCost, hwmSeq a.hwm b.hwm⟩

-- Observation represented by `examples/session_ir/accept_unit.sir`.
def unitTrace : Footprint := ⟨0, ⟨0, 0⟩⟩

/-- The memory-only trace in `accept_pair_drop.sir`: zero net state change,
    with six allocated bytes recorded in the high-water mark. -/
def allocateDrop (bytes : Nat) : Footprint := ⟨0, ⟨bytes, 0⟩⟩

/-- One unit send and its matching receive: two communication steps, no bytes
    allocated by the Session IR machine (`accept_send_recv.sir`). -/
def sendRecv : Footprint := ⟨2, ⟨0, 0⟩⟩

/-- The fixture's two observations agree on cost (zero), but not on HWM. -/
theorem same_cost_different_hwm :
    unitTrace.communicationCost = (allocateDrop 6).communicationCost ∧
    unitTrace.hwm.peak ≠ (allocateDrop 6).hwm.peak := by
  decide

/-- The fixture's two observations agree on HWM (six bytes), but not on cost. -/
theorem same_hwm_different_cost :
    (allocateDrop 6).hwm.peak =
      (seq (allocateDrop 6) sendRecv).hwm.peak ∧
    (allocateDrop 6).communicationCost ≠
      (seq (allocateDrop 6) sendRecv).communicationCost := by
  decide

/-- No scalar function of communication cost recovers HWM on these traces. -/
theorem hwm_not_function_of_cost :
    ¬ ∃ f : Nat → Nat, ∀ x : Footprint,
      f x.communicationCost = x.hwm.peak := by
  rintro ⟨f, hf⟩
  have hUnit : f 0 = 0 := hf unitTrace
  have hAllocate : f 0 = 6 := hf (allocateDrop 6)
  have impossible : (0 : Nat) = 6 := hUnit.symm.trans hAllocate
  cases impossible

/-- No scalar function of HWM recovers communication cost on these traces. -/
theorem cost_not_function_of_hwm :
    ¬ ∃ f : Nat → Nat, ∀ x : Footprint,
      f x.hwm.peak = x.communicationCost := by
  rintro ⟨f, hf⟩
  have hAllocate : f 6 = 0 := hf (allocateDrop 6)
  have hWithComm : f 6 = 2 := hf (seq (allocateDrop 6) sendRecv)
  have impossible : (0 : Nat) = 2 := hAllocate.symm.trans hWithComm
  cases impossible

end CostState

#print axioms CostState.same_cost_different_hwm
#print axioms CostState.same_hwm_different_cost
#print axioms CostState.hwm_not_function_of_cost
#print axioms CostState.cost_not_function_of_hwm
