{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
--
-- Reclamation at a cut — the occupancy reading of "protocol cut = reclaim"
-- (ULTRAPLAN Phase 2), made a theorem over the high-water-mark algebra.
--
-- Cut a linear protocol into a prefix and a suffix.  The suffix starts from
-- the prefix's DRIFT (what is still live at the cut), not its PEAK: the
-- difference, peak − drift, is reclaimed at the frontier.  Consequences:
--   occupancy ≤ cost           peak (xs ++ ys) ≤ peak xs + peak ys
--   equality iff nothing is reclaimed (drift = peak) or the suffix is empty
--   strict reclamation         drift < peak and 0 < peak ys  ⇒  strictly less
-- A cost algebra (max-plus) has no such slack: cost (xs ++ ys) = cost xs +
-- cost ys always.  Tropical types cannot state any line of this file.
module OccupancyTypes.Reclaim where

open import ResourceAlgebra.Prelude
open import ResourceAlgebra.Core
open import ResourceAlgebra.Instances.HWM
open import OccupancyTypes.Order
open import OccupancyTypes.Timeline HWM

-- The reclamation law itself is the definition of sequencing: the suffix
-- sees the drift.  Stated so it can be cited.
reclaim-law : ∀ a b → peak (a ⊗h b) ≡ max (peak a) (drift a + peak b)
reclaim-law (hwm _ _ _) (hwm _ _ _) = refl

-- Occupancy never exceeds cost.
occupancy≤cost : ∀ a b → peak (a ⊗h b) ≤ peak a + peak b
occupancy≤cost (hwm p₁ n₁ b₁) (hwm p₂ n₂ b₂) =
  max-lub (≤-+ʳ p₁ p₂) (+-monoˡ-≤ p₂ b₁)

-- Nothing reclaimed (drift = peak): occupancy IS cost.
no-reclaim : ∀ (a : Grade) → peak a ≡ drift a → ∀ (c : Grade)
           → peak (a ⊗h c) ≡ peak a + peak c
no-reclaim (hwm p .p b) refl (hwm p₂ n₂ b₂) = max-absorb' p p₂
  where
  max-absorb' : ∀ p q → max p (p + q) ≡ p + q
  max-absorb' p q = trans (max-comm p (p + q)) (max-absorb-≤ (≤-+ʳ p q))

-- Strict reclamation: something is released at the cut and the suffix does
-- something, so occupancy is strictly below cost.
reclaimed : ∀ (a c : Grade) → drift a < peak a → 0 < peak c
          → peak (a ⊗h c) < peak a + peak c
reclaimed (hwm p₁ n₁ b₁) (hwm p₂ n₂ b₂) lt pos =
  max-lub (<-+ʳ p₁ pos) (+-monoˡ-≤ p₂ lt)

-- At the level of protocols: the cut factorisation plus the law.
occupancy-at-cut : ∀ xs ys
                 → peak (grade (xs ++ ys)) ≡ max (peak (grade xs)) (drift (grade xs) + peak (grade ys))
occupancy-at-cut xs ys = trans (cong peak (cut-factor xs ys)) (reclaim-law (grade xs) (grade ys))

protocol-occupancy≤cost : ∀ xs ys → peak (grade (xs ++ ys)) ≤ peak (grade xs) + peak (grade ys)
protocol-occupancy≤cost xs ys =
  subst (_≤ peak (grade xs) + peak (grade ys)) (sym (cong peak (cut-factor xs ys)))
        (occupancy≤cost (grade xs) (grade ys))
