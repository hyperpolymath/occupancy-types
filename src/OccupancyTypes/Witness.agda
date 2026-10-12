{-# OPTIONS --safe --without-K #-}
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
-- Computed witnesses (TESTED): the same two-interaction protocol under the
-- occupancy and the cost reading.  Interaction 1 allocates 4 and releases
-- 3 (drift 1); interaction 2 allocates 3 and holds it.
module OccupancyTypes.Witness where

open import ResourceAlgebra.Prelude
open import ResourceAlgebra.Core
open import ResourceAlgebra.Instances.HWM
open import ResourceAlgebra.Instances.MaxPlus
open import OccupancyTypes.Order
open import OccupancyTypes.Reclaim

import OccupancyTypes.Timeline
module TH = OccupancyTypes.Timeline HWM
module TM = OccupancyTypes.Timeline MaxPlus

a b : Grade
a = hwm 4 1 (s≤s z≤n)
b = hwm 3 3 (s≤s (s≤s (s≤s z≤n)))

-- Occupancy of the protocol: 4, because 3 are reclaimed at the cut before b.
occupancy : peak (TH.grade (a TH.∷ b TH.∷ TH.[])) ≡ 4
occupancy = refl

-- Cost of the same protocol: 7, nothing is ever reclaimed.
cost : TM.grade (val 4 TM.∷ val 3 TM.∷ TM.[]) ≡ val 7
cost = refl

-- The reclamation is strict here, as the theorem predicts.
strict : peak (a ⊗h b) < peak a + peak b
strict = reclaimed a b (s≤s (s≤s z≤n)) (s≤s z≤n)

4≢7 : 4 ≢ 7
4≢7 ()
