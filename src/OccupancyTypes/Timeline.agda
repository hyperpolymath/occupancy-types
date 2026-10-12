{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
-- A linear protocol as the sequence of its interaction grades; a cut is a
-- split.  The grade factors through every cut, in any resource algebra.
open import ResourceAlgebra.Core

module OccupancyTypes.Timeline (R : ResourceAlgebra) where

open import ResourceAlgebra.Prelude
open ResourceAlgebra R

infixr 5 _∷_ _++_
data Timeline : Set where
  []  : Timeline
  _∷_ : Grade → Timeline → Timeline

_++_ : Timeline → Timeline → Timeline
[]       ++ ys = ys
(g ∷ xs) ++ ys = g ∷ (xs ++ ys)

grade : Timeline → Grade
grade []       = 𝟙
grade (g ∷ xs) = g ⊗ grade xs

-- Cutting a timeline anywhere factors its grade.
cut-factor : ∀ xs ys → grade (xs ++ ys) ≡ grade xs ⊗ grade ys
cut-factor []       ys = sym (IsSeqMonoid.unitˡ seq (grade ys))
cut-factor (g ∷ xs) ys =
  trans (cong (g ⊗_) (cut-factor xs ys)) (sym (IsSeqMonoid.assoc seq g (grade xs) (grade ys)))
