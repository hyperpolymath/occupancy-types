-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- EXPECTED-REJECTION CONTROL — double free.
--
--   bad = WithAlloc 4 ok (\h => seqU (Free h) (Free h))
--
-- h is used twice: Free consumes its handle at multiplicity 1, so the second
-- Free is a quantity error (and independently the state indices cannot line
-- up: the second Free wants pre = 1 while the first left pre = 0).
-- This file MUST FAIL to typecheck.  Checked by ../check-rejections.sh.

module RejectDoubleFree

import Occ
import Data.Nat

%default total

export
bad : Occ 0 0 2 Unit
bad = WithAlloc 4 (LTESucc LTEZero) (\h => seqU (Free h) (Free h))
