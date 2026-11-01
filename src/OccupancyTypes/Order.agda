{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
-- Order lemmas on ℕ beyond resource-algebra's Prelude.  Builtins only.
module OccupancyTypes.Order where

open import ResourceAlgebra.Prelude

infix 4 _<_
_<_ : Nat → Nat → Set
m < n = suc m ≤ n

≤-step : ∀ {m n} → m ≤ n → m ≤ suc n
≤-step z≤n     = z≤n
≤-step (s≤s p) = s≤s (≤-step p)

-- ≤-+ˡ, ≤-+ʳ, +-monoˡ-≤ and max-lub were defined here until resource-algebra
-- 0b338c9 added the same four lemmas to its Prelude (with Instances/MinMax);
-- they now come from there, through the open import above.

<-+ʳ : ∀ m {n} → 0 < n → m < m + n
<-+ʳ m {suc n} _ = subst (suc m ≤_) (sym (+-suc m n)) (s≤s (≤-+ʳ m n))
