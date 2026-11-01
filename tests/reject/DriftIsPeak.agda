{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
module DriftIsPeak where
open import ResourceAlgebra.Prelude
open import ResourceAlgebra.Instances.HWM

-- Must fail: what is live at the cut is not the peak reached before it;
-- identifying them is exactly "nothing is ever reclaimed".
invalid : ∀ (a : Grade) → drift a ≡ peak a
invalid (hwm p n b) = refl
