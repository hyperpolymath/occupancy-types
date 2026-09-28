-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- EXPECTED-REJECTION CONTROL — dropped handle (leak).
--
--   bad = WithAlloc 4 ok (\h => LPure ())
--
-- The continuation binder h has multiplicity 1 but is used 0 times: the cell
-- is allocated and never freed.  Quantity checking rejects the leak.
-- (Note the occupancy indices alone would NOT catch this: LPure unifies at
-- post = 1.  This control is exactly what the multiplicity is for.)
-- This file MUST FAIL to typecheck.  Checked by ../check-rejections.sh.

module RejectLeak

import Occ
import Data.Nat

%default total

export
bad : Occ 0 1 1 Unit
bad = WithAlloc 4 (LTESucc LTEZero) (\h => LPure ())
