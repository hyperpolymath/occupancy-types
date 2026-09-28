-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- Demo — canonical examples for the Occ spike (ULTRAPLAN R0-B, Piece 2).
-- UNVERIFIED without idris2 on PATH; see README.adoc.  %default total.

module Demo

import Occ
import Data.Nat

%default total

||| Fixed pool of capacity 4: allocate two cells, free them in any order,
||| peak 2.  The capacity proof (LTE (S n) C) is a static argument to every
||| alloc; over-capacity has no term (see RejectOverCapacity.idr).
export
poolDemo : Occ 0 0 2 Unit
poolDemo =
  WithAlloc 4 (LTESucc LTEZero) (\h0 =>
  WithAlloc 4 (LTESucc (LTESucc LTEZero)) (\h1 =>
    seqU (Free h0) (seqU (Free h1) (LPure ()))))

||| Bounded buffer of capacity K = 2, producer/consumer sequence:
|||   push 10        0 -> 1   peak 1
|||   push 20        1 -> 2   peak 2   (buffer FULL: K = 2)
|||   pop            2 -> 1   peak 2   (consumer takes 10)
|||   push (popped)  1 -> 2   peak 2   (producer refills)
||| Static peak = 2 = K: TIGHT, and constant — no data-dependent grade is
||| needed anywhere in the file.  This is the kill-question evidence.
export
producerConsumer : Occ 0 2 2 (Queue 2 2)
producerConsumer =
  LBind (NewQ {k = 2}) (\q0 =>
  LBind (QPush (LTESucc LTEZero) 10 q0) (\q1 =>
  LBind (QPush (LTESucc (LTESucc LTEZero)) 20 q1) (\q2 =>
  LBind (QPop q2) (\pr =>
    case pr of
      (q3, got) =>
        LBind (QPush (LTESucc (LTESucc LTEZero)) got q3) (\q4 =>
        LPure q4)))))

||| The same producer/consumer with the empty-first-starve check: popping an
||| empty buffer is not merely wrong at runtime — `QPop : Queue k (S n) -> ...`
||| has no instance at n = 0, so the program does not typecheck.  (Compile
||| this comment's shape on demand; the accepted path is producerConsumer.)
export
neverPopEmpty : Occ 0 1 1 (Queue 2 1)
neverPopEmpty =
  LBind (NewQ {k = 2}) (\q0 =>
  LBind (QPush (LTESucc LTEZero) 7 q0) (\q1 =>
  LPure q1))
