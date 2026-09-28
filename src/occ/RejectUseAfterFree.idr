-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- EXPECTED-REJECTION CONTROL — use-after-free.
--
--   bad = WithAlloc 4 ok (\h => seqU (Free h) (Peek h))
--
-- Free consumes h at multiplicity 1; Peek then uses the same handle again —
-- a second use of a linear name.  Quantity checking rejects it.  (The state
-- indices would accept this shape — pre = post = 0 throughout — so this
-- control isolates the multiplicity discipline.)
-- This file MUST FAIL to typecheck.  Checked by ../check-rejections.sh.

module RejectUseAfterFree

import Occ
import Data.Nat

%default total

export
bad : Occ 0 0 1 Nat
bad = WithAlloc 4 (LTESucc LTEZero) (\h => seqU (Free h) (Peek h))
