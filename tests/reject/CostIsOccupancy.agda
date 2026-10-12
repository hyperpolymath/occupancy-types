{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
module CostIsOccupancy where
open import ResourceAlgebra.Prelude
open import ResourceAlgebra.Instances.HWM

-- Must fail: occupancy of a sequence is not the sum of the peaks.  Reading
-- it as cost would charge for memory the cut has already reclaimed.
invalid : ∀ (a c : Grade) → peak (a ⊗h c) ≡ peak a + peak c
invalid (hwm p n b) (hwm p' n' b') = refl
