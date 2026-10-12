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

≤-+ˡ : ∀ n k → k ≤ n + k
≤-+ˡ zero    k = ≤-refl k
≤-+ˡ (suc n) k = ≤-step (≤-+ˡ n k)

≤-+ʳ : ∀ m n → m ≤ m + n
≤-+ʳ zero    n = z≤n
≤-+ʳ (suc m) n = s≤s (≤-+ʳ m n)

+-monoˡ-≤ : ∀ {m n} k → m ≤ n → m + k ≤ n + k
+-monoˡ-≤ k (z≤n {n}) = ≤-+ˡ n k
+-monoˡ-≤ k (s≤s p)   = s≤s (+-monoˡ-≤ k p)

max-lub : ∀ {a b c} → a ≤ c → b ≤ c → max a b ≤ c
max-lub z≤n     q       = q
max-lub (s≤s p) z≤n     = s≤s p
max-lub (s≤s p) (s≤s q) = s≤s (max-lub p q)

<-+ʳ : ∀ m {n} → 0 < n → m < m + n
<-+ʳ m {suc n} _ = subst (suc m ≤_) (sym (+-suc m n)) (s≤s (≤-+ʳ m n))
