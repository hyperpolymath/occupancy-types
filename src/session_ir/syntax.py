# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""Abstract syntax for the occupancy-types Session IR (v0).

Types:     Unit | Buf n | A * B | S
Sessions:  End | !A.S | ?A.S | +{li: Si} | &{li: Si}
Terms:     unit | drop e | alloc n | pair e1 e2 | letpair x y = e1 in e2
           new S | send ep val | recv ep | close ep
           select l ep | case ep {li: xi. ei} | let x [: A] [@ r] = e1 in e2

Judgment:  Gamma |- e : A | r   (r = communication-step count, max-plus)

Design notes (see docs/OPERATIONAL-MODEL.md):
  * Comm actions thread the endpoint name (send/recv/select update its session
    type in the residual context); `case` is a destructor: it consumes its
    endpoint and binds the per-branch continuation as `xi : Si`.
  * All types except Unit are linear (Buf, session endpoints, pairs containing
    them).  Unit names are unrestricted.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Union

# ── Grade semiring: max-plus (N, max, +, 0) ──────────────────────────────────
#
# The one grade of v0 is the communication-step count.  Sequential composition
# adds (both actions happen); alternative branches take max (we cannot rule out
# the expensive branch).  This tiny object is the importable constraint: six
# typing rules in checker.py are expressed solely in terms of it.

GRADE_ZERO = 0          # cost of doing nothing; identity of max on N
GRADE_ONE = 1           # cost of one communication action


class MaxPlus:
    """Semiring (N u {inf}, max, +, 0): op_add is choice, op_mul is sequence."""

    zero = GRADE_ZERO
    one = GRADE_ONE

    @staticmethod
    def op_add(x: int, y: int) -> int:
        """Choice: max.  Worst-case guarantee is the most expensive branch."""
        return x if x >= y else y

    @staticmethod
    def op_mul(x: int, y: int) -> int:
        """Sequence: +.  Both actions definitely happen."""
        return x + y

    @staticmethod
    def op_sum(xs: List[int]) -> int:
        out = GRADE_ZERO
        for x in xs:
            out = MaxPlus.op_add(out, x)
        return out

    @staticmethod
    def op_seq(xs: List[int]) -> int:
        out = GRADE_ZERO
        for x in xs:
            out = MaxPlus.op_mul(out, x)
        return out


# ── Errors ───────────────────────────────────────────────────────────────────

class SIRError(Exception):
    """Structured checker/machine error with a stable code."""

    def __init__(self, code: str, msg: str, pos: Optional[Tuple[int, int]] = None):
        self.code = code
        self.msg = msg
        self.pos = pos
        super().__init__(f"{code}: {msg}" + (f" (at {pos[0]}:{pos[1]})" if pos else ""))


E_UNKNOWN = "E_UNKNOWN"                  # unbound name
E_ALIAS = "E_ALIAS"                      # linear name used twice
E_USE_AFTER_DROP = "E_USE_AFTER_DROP"    # use of dropped buf / closed endpoint
E_DOUBLE_FREE = "E_DOUBLE_FREE"          # drop of already-consumed buffer
E_LEAK = "E_LEAK"                        # linear resource left unconsumed
E_PROTOCOL = "E_PROTOCOL"                # session/message mismatch
E_CLOSE_NOT_END = "E_CLOSE_NOT_END"      # close before End
E_DROP_TYPE = "E_DROP_TYPE"              # drop of a non-Buf (e.g. endpoint)
E_BOUND = "E_BOUND"                      # annotated @r smaller than computed grade
E_CASE_LINEAR = "E_CASE_LINEAR"          # branches leave different live linear state
E_CASE_TYPE = "E_CASE_TYPE"              # branches return different types
E_LET_TYPE = "E_LET_TYPE"                # let type-annotation mismatch
E_SYNTAX = "E_SYNTAX"                    # parse error
# Machine-level (should not fire on well-typed programs):
R_DEADLOCK = "R_DEADLOCK"                # recv/select with nothing in flight
R_CLOSE_PENDING = "R_CLOSE_PENDING"      # close with unconsumed messages
R_UNSOUND = "R_UNSOUND"                  # measured steps exceeded certified grade
R_INTERNAL = "R_INTERNAL"                # machine/checker disagreement


# ── Types and sessions ───────────────────────────────────────────────────────

@dataclass(frozen=True)
class UnitT:
    pass


@dataclass(frozen=True)
class BufT:
    n: int


@dataclass(frozen=True)
class PairT:
    a: "Ty"
    b: "Ty"


@dataclass(frozen=True)
class End:
    pass


@dataclass(frozen=True)
class Send:            # !A.S
    msg: "Ty"
    cont: "Sess"


@dataclass(frozen=True)
class Recv:            # ?A.S
    msg: "Ty"
    cont: "Sess"


@dataclass(frozen=True)
class IntChoice:       # +{li: Si}  internal choice (offer)
    branches: Tuple[Tuple[str, "Sess"], ...]


@dataclass(frozen=True)
class ExtChoice:       # &{li: Si}  external choice (accept)
    branches: Tuple[Tuple[str, "Sess"], ...]


@dataclass(frozen=True)
class SessT:
    s: "Sess"


Sess = Union[End, Send, Recv, IntChoice, ExtChoice]
Ty = Union[UnitT, BufT, PairT, SessT]

UNIT = UnitT()


def is_linear(t: Ty) -> bool:
    """Unit is unrestricted; Buf, endpoints and pairs holding them are linear."""
    if isinstance(t, UnitT):
        return False
    if isinstance(t, BufT):
        return True
    if isinstance(t, SessT):
        return True
    if isinstance(t, PairT):
        return is_linear(t.a) or is_linear(t.b)
    raise AssertionError(f"unreachable type {t!r}")


def dual(s: Sess) -> Sess:
    if isinstance(s, End):
        return End()
    if isinstance(s, Send):
        return Recv(s.msg, dual(s.cont))
    if isinstance(s, Recv):
        return Send(s.msg, dual(s.cont))
    if isinstance(s, IntChoice):
        return ExtChoice(tuple((l, dual(c)) for l, c in s.branches))
    if isinstance(s, ExtChoice):
        return IntChoice(tuple((l, dual(c)) for l, c in s.branches))
    raise AssertionError(f"unreachable session {s!r}")


# ── Pretty printing ──────────────────────────────────────────────────────────

def pp_ty(t: Ty) -> str:
    if isinstance(t, UnitT):
        return "Unit"
    if isinstance(t, BufT):
        return f"Buf {t.n}"
    if isinstance(t, PairT):
        left = pp_ty(t.a)
        if isinstance(t.a, PairT):
            left = f"({left})"
        return f"{left} * {pp_ty(t.b)}"
    if isinstance(t, SessT):
        return pp_sess(t.s)
    raise AssertionError(f"unreachable type {t!r}")


def pp_sess(s: Sess) -> str:
    if isinstance(s, End):
        return "End"
    if isinstance(s, Send):
        return f"!{pp_ty(s.msg)}.{pp_sess(s.cont)}"
    if isinstance(s, Recv):
        return f"?{pp_ty(s.msg)}.{pp_sess(s.cont)}"
    if isinstance(s, (IntChoice, ExtChoice)):
        op = "+" if isinstance(s, IntChoice) else "&"
        inner = ", ".join(f"{l}: {pp_sess(c)}" for l, c in s.branches)
        return f"{op}{{{inner}}}"
    raise AssertionError(f"unreachable session {s!r}")


def ty_eq(a: Ty, b: Ty) -> bool:
    return a == b


# ── Terms ────────────────────────────────────────────────────────────────────

@dataclass(frozen=True)
class Var:
    name: str
    pos: Tuple[int, int] = field(default=(0, 0))


@dataclass(frozen=True)
class UnitLit:
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Alloc:
    n: int
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Drop:
    e: "Term"
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Pair:
    e1: "Term"
    e2: "Term"
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class LetPair:
    x: str
    y: str
    e1: "Term"
    e2: "Term"
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class New:
    s: Sess
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class SendT:           # send ep val
    ep: str
    val: "Term"
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class RecvT:           # recv ep
    ep: str
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Close:
    ep: str
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Select:
    label: str
    ep: str
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Case:
    ep: str
    branches: Tuple[Tuple[str, str, "Term"], ...]  # (label, binder, body)
    pos: Tuple[int, int] = (0, 0)


@dataclass(frozen=True)
class Let:
    x: str
    ann: Optional[Ty]      # optional type annotation
    bound: Optional[int]   # optional claimed grade bound @r
    e1: "Term"
    e2: "Term"
    pos: Tuple[int, int] = (0, 0)


Term = Union[Var, UnitLit, Alloc, Drop, Pair, LetPair, New,
             SendT, RecvT, Close, Select, Case, Let]
