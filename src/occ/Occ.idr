-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
-- Occ — occupancy-indexed state monad spike (ULTRAPLAN R0-B, Piece 2).
--
--   Occ : (pre, post, peak : Nat) -> Type -> Type
--
--   pre/post : live cells before/after the action
--   peak     : high-water mark of live cells during the action (absolute)
--
-- Composition (LBind): peaks compose by max (absolute occupancy indices);
-- occupancy in sequence chains via pre/post.  Four expected-rejection
-- controls live in Reject*.idr beside this file: double free, dropped handle
-- (leak), alloc over capacity, use-after-free — all fail to typecheck.
--
-- UNVERIFIED in this work environment (no idris2 on PATH): see README.adoc
-- for exact check commands.  %default total is on; no holes.

module Occ

import Data.Nat
import Data.Fin

%default total

-- ── Handles ────────────────────────────────────────────────────────────────

||| A handle to one live cell of a fixed pool.  Multiplicity 1: handles are
||| linear values (see WithAlloc's continuation binder and Free/Peek).
public export
data Handle : Type where
  MkH : (cellId : Nat) -> Handle

-- ── Bounded buffer ─────────────────────────────────────────────────────────

||| Bounded buffer of capacity k holding n messages (static n <= k).
||| FIFO: index 0 is the oldest message.  Storage is a Fin-indexed cell
||| function; the occupancy indices are layout-independent (ring-buffer
||| layout is orthogonal to occupancy indexing and is deferred).
public export
data Queue : (k, n : Nat) -> Type where
  MkQ : (get : Fin n -> Nat) -> Queue k n

-- ── The monad ──────────────────────────────────────────────────────────────

||| Indexed state monad for occupancy.  Static indices only: every grade here
||| is a literal or a static parameter (ULTRAPLAN §1.4).  Data-dependent
||| grades are a kill signal, not a feature.
public export
data Occ : (pre, post, peak : Nat) -> Type -> Type where
  ||| Return a value; no occupancy change.  The value is linear.
  LPure : (1 x : a) -> Occ n n n a

  ||| Sequential composition.  Peaks compose by max (absolute indices).
  ||| The continuation receives its argument at multiplicity 1: values that
  ||| flow out of an action (notably handles) must be consumed exactly once.
  LBind : (1 act : Occ p q m a)
       -> (1 k : (1 _ : a) -> Occ q r m' b)
       -> Occ p r (max m m') b

  ||| Allocate one cell of a pool of capacity C: allowed exactly when
  ||| S n <= C (static proof; over-capacity has no such term).
  Alloc : (C : Nat) -> (0 ok : LTE (S n) C) -> Occ n (S n) (S n) Handle

  ||| Free consumes its handle linearly (multiplicity 1).
  Free : (1 h : Handle) -> Occ (S n) n (S n) Unit

  ||| Read a cell id, consuming the handle (use-after-free is a second use of
  ||| one handle, which quantity checking rejects).
  Peek : (1 h : Handle) -> Occ n n n Nat

  ||| Bounded-buffer actions.  Occupancy counts in-flight messages.
  NewQ : Occ n n n (Queue k 0)
  QPush : (0 ok : LTE (S n) k) -> (msg : Nat) -> (1 q : Queue k n)
       -> Occ n (S n) (S n) (Queue k (S n))
  QPop : (1 q : Queue k (S n)) -> Occ (S n) n (S n) (Queue k n, Nat)

-- ── Derived combinators ────────────────────────────────────────────────────

||| Allocate and hand the handle to a linear continuation: the binder h has
||| multiplicity 1, so dropping it (0 uses), duplicating it, or freeing twice
||| (2 uses) are all type errors.
public export
WithAlloc : (C : Nat) -> (0 ok : LTE (S n) C)
         -> (1 k : (1 h : Handle) -> Occ (S n) post peak b)
         -> Occ n post (max (S n) peak) b
WithAlloc C ok k = LBind (Alloc C ok) k

||| Sequence a Unit-producing action with a continuation, consuming the unit.
public export
seqU : (1 act : Occ p q m Unit) -> (1 next : Occ q r m' b) -> Occ p r (max m m') b
seqU act next = LBind act (\u => case u of MkUnit => next)

-- ── Push/pop on the bounded buffer as pure total functions ─────────────────
-- (The Occ-level QPush/QPop above are the graded actions; these helpers show
--  the underlying FIFO discipline total-function style.)

||| FIFO push: message goes to the back (new index S n is the newest slot).
public export
qpush : (0 ok : LTE (S n) k) -> (msg : Nat) -> (1 q : Queue k n) -> Queue k (S n)
qpush ok msg (MkQ get) = MkQ (\i => case i of
                                       FZ => msg
                                       FS j => get j)

||| FIFO pop: oldest message (slot 0) leaves; the rest shift down.
public export
qpop : (1 q : Queue k (S n)) -> (Queue k n, Nat)
qpop (MkQ get) = (MkQ (\j => get (FS j)), get FZ)
