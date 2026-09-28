-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- EXPECTED-REJECTION CONTROL — alloc over capacity.
--
--   bad = Alloc 4 (witness that pretends 5 <= 4)
--
-- Alloc at occupancy n = 4 of a pool of capacity C = 4 needs a proof of
-- LTE (S 4) 4, i.e. 5 <= 4.  No such proof exists; the bogus witness
-- (LTESucc x4 LTEZero : LTE 4 _) mismatches LTE 5 4 and the file is
-- rejected.  Capacity is a static parameter, never a runtime check.
-- This file MUST FAIL to typecheck.  Checked by ../check-rejections.sh.

module RejectOverCapacity

import Occ
import Data.Nat

%default total

export
bad : Occ 4 5 5 Handle
bad = Alloc 4 (LTESucc (LTESucc (LTESucc (LTESucc LTEZero))))
