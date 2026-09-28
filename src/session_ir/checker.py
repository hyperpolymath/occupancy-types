# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""Syntax-directed checker for the Session IR: judgment Gamma |- e : A | r.

r is the communication-step count in the max-plus semiring (N, max, +, 0):
sequential composition adds; alternative branches take max.  The only grade
in v0.  Memory is enforced by linear uniqueness (no second grade): every Buf
and endpoint name appears exactly once in the context or is consumed.

Rules (ULTRAPLAN Phase 1, in MaxPlus notation; op_seq = +, op_add = max):

  unit/alloc/new              Gamma |- e : A | 0
  drop/close                  0 + r(sub)            (drop/close themselves cost 0)
  pair/letpair/let            r1 + r2               (sequence)
  send/recv/select            1 + r(subterms)
  case                        1 + max_i r(branch i)

Endpoint threading: send/recv/select update the endpoint's session type in the
residual context.  `case` is a destructor: it consumes its endpoint and binds
the per-branch continuation xi : Si inside branch i.  Branches must agree on
result type and on the residual linear state.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from .syntax import (
    Alloc, BufT, Case, Close, Drop, E_ALIAS, E_BOUND, E_CASE_LINEAR, E_CASE_TYPE,
    E_CLOSE_NOT_END, E_DOUBLE_FREE, E_DROP_TYPE, E_LEAK, E_LET_TYPE, E_PROTOCOL,
    E_UNKNOWN, E_USE_AFTER_DROP, End, ExtChoice, IntChoice, Let, LetPair, MaxPlus, New,
    Pair, PairT, Recv, RecvT, SIRError, Send, SendT, Select, SessT, Term, Ty, UNIT,
    UnitLit, UnitT, Var, is_linear, pp_ty, dual, ty_eq,
)

Ctx = Dict[str, Ty]


class CheckResult:
    def __init__(self, ty: Ty, grade: int):
        self.ty = ty
        self.grade = grade


class Checker:
    """Per-program checker.  Keeps a graveyard of consumed names for errors."""

    def __init__(self) -> None:
        # name -> reason it left the context ("used" | "dropped" | "closed")
        self.graveyard: Dict[str, str] = {}

    # -- name resolution with linear bookkeeping ----------------------------
    def _bind(self, ctx: Ctx, x: str, t: Ty, pos) -> Ctx:
        if x in ctx and is_linear(ctx[x]):
            raise SIRError(E_ALIAS, f"binder {x!r} shadows a live linear name", pos)
        self.graveyard.pop(x, None)  # fresh binding shadows a consumed name
        out = dict(ctx)
        out[x] = t
        return out

    def _use(self, ctx: Ctx, x: str, pos) -> Tuple[Ty, Ctx]:
        """Variable occurrence: consumes linear names (moves ownership)."""
        if x in ctx:
            t = ctx[x]
            out = dict(ctx)
            if is_linear(t):
                del out[x]
                self.graveyard[x] = "used"
            return t, out
        self._fail_consumed(x, pos, dropping=False)
        raise AssertionError("unreachable")

    def _fail_consumed(self, x: str, pos, dropping: bool) -> None:
        reason = self.graveyard.get(x)
        if reason is None:
            raise SIRError(E_UNKNOWN, f"unbound name {x!r}", pos)
        if dropping and reason == "dropped":
            raise SIRError(E_DOUBLE_FREE,
                           f"buffer {x!r} was already dropped", pos)
        if reason == "dropped":
            raise SIRError(E_USE_AFTER_DROP,
                           f"buffer {x!r} was dropped before this use", pos)
        if reason == "closed":
            raise SIRError(E_USE_AFTER_DROP,
                           f"endpoint {x!r} was closed before this use "
                           f"(use-after-close)", pos)
        raise SIRError(E_ALIAS,
                       f"linear name {x!r} already consumed at an earlier "
                       f"occurrence (aliasing)", pos)

    def _use_ep(self, ctx: Ctx, x: str, pos) -> Tuple[SessT, Ctx]:
        """Endpoint occurrence in channel position (send/recv/close/select/case)."""
        if x in ctx:
            t = ctx[x]
            if not isinstance(t, SessT):
                raise SIRError(E_PROTOCOL,
                               f"{x!r} : {pp_ty(t)} used where a session "
                               f"endpoint is required", pos)
            return t, ctx
        self._fail_consumed(x, pos, dropping=False)
        raise AssertionError("unreachable")

    def _consume_ep(self, ctx: Ctx, x: str, reason: str, pos) -> Ctx:
        out = dict(ctx)
        del out[x]
        self.graveyard[x] = reason
        return out

    # -- the judgment -------------------------------------------------------
    def check(self, ctx: Ctx, e: Term) -> Tuple[Ty, int, Ctx]:
        if isinstance(e, Var):
            t, out = self._use(ctx, e.name, e.pos)
            return t, MaxPlus.zero, out

        if isinstance(e, UnitLit):
            return UNIT, MaxPlus.zero, ctx

        if isinstance(e, Alloc):
            return BufT(e.n), MaxPlus.zero, ctx

        if isinstance(e, Drop):
            if isinstance(e.e, Var):
                x = e.e.name
                if x not in ctx:
                    self._fail_consumed(x, e.e.pos, dropping=True)
                t = ctx[x]
                if isinstance(t, SessT):
                    raise SIRError(
                        E_DROP_TYPE,
                        f"drop {x!r} : endpoint — endpoints are consumed by "
                        f"close, not drop (D5)", e.pos)
                if not isinstance(t, BufT):
                    raise SIRError(
                        E_DROP_TYPE,
                        f"drop {x!r} : {pp_ty(t)} — only Buf n can be dropped",
                        e.pos)
                out = self._consume_ep(ctx, x, "dropped", e.pos)
                return UNIT, MaxPlus.zero, out
            t, r, out = self.check(ctx, e.e)
            if isinstance(t, SessT):
                raise SIRError(E_DROP_TYPE,
                               "drop of an endpoint — use close (D5)", e.pos)
            if not isinstance(t, BufT):
                raise SIRError(E_DROP_TYPE,
                               f"drop of {pp_ty(t)} — only Buf n can be dropped",
                               e.pos)
            return UNIT, r, out

        if isinstance(e, Pair):
            t1, r1, c1 = self.check(ctx, e.e1)
            t2, r2, c2 = self.check(c1, e.e2)
            return PairT(t1, t2), MaxPlus.op_mul(r1, r2), c2

        if isinstance(e, LetPair):
            t1, r1, c1 = self.check(ctx, e.e1)
            if not isinstance(t1, PairT):
                raise SIRError(E_PROTOCOL,
                               f"letpair on {pp_ty(t1)} — expected a pair", e.pos)
            if e.x == e.y:
                raise SIRError(E_ALIAS,
                               f"letpair binds both components as {e.x!r}", e.pos)
            c1 = self._bind(c1, e.x, t1.a, e.pos)
            c1 = self._bind(c1, e.y, t1.b, e.pos)
            t2, r2, c2 = self.check(c1, e.e2)
            return t2, MaxPlus.op_mul(r1, r2), c2

        if isinstance(e, New):
            return PairT(SessT(e.s), SessT(dual(e.s))), MaxPlus.zero, ctx

        if isinstance(e, SendT):
            s_ep, c0 = self._use_ep(ctx, e.ep, e.pos)
            if not isinstance(s_ep.s, Send):
                raise SIRError(
                    E_PROTOCOL,
                    f"send on {e.ep!r} : {pp_ty(s_ep)} — endpoint does not "
                    f"offer !A.S", e.pos)
            # The endpoint is in channel position: not visible inside the value.
            c_pre = dict(c0)
            del c_pre[e.ep]
            tv, rv, c1 = self.check(c_pre, e.val)
            if not ty_eq(tv, s_ep.s.msg):
                raise SIRError(
                    E_PROTOCOL,
                    f"send on {e.ep!r}: message type {pp_ty(tv)} does not "
                    f"match declared {pp_ty(s_ep.s.msg)}", e.pos)
            c1[e.ep] = SessT(s_ep.s.cont)
            return UNIT, MaxPlus.op_mul(MaxPlus.one, rv), c1

        if isinstance(e, RecvT):
            s_ep, c0 = self._use_ep(ctx, e.ep, e.pos)
            if not isinstance(s_ep.s, Recv):
                raise SIRError(
                    E_PROTOCOL,
                    f"recv on {e.ep!r} : {pp_ty(s_ep)} — endpoint does not "
                    f"offer ?A.S", e.pos)
            c0[e.ep] = SessT(s_ep.s.cont)
            return s_ep.s.msg, MaxPlus.one, c0

        if isinstance(e, Close):
            s_ep, c0 = self._use_ep(ctx, e.ep, e.pos)
            if not isinstance(s_ep.s, End):
                raise SIRError(
                    E_CLOSE_NOT_END,
                    f"close {e.ep!r} : {pp_ty(s_ep)} — endpoint is not at End",
                    e.pos)
            out = self._consume_ep(c0, e.ep, "closed", e.pos)
            return UNIT, MaxPlus.zero, out

        if isinstance(e, Select):
            s_ep, c0 = self._use_ep(ctx, e.ep, e.pos)
            if not isinstance(s_ep.s, IntChoice):
                raise SIRError(
                    E_PROTOCOL,
                    f"select on {e.ep!r} : {pp_ty(s_ep)} — endpoint does not "
                    f"offer +{{...}}", e.pos)
            labels = dict(s_ep.s.branches)
            if e.label not in labels:
                raise SIRError(
                    E_PROTOCOL,
                    f"select {e.label!r} not offered by {e.ep!r} : "
                    f"{pp_ty(s_ep)}", e.pos)
            c0[e.ep] = SessT(labels[e.label])
            return UNIT, MaxPlus.one, c0

        if isinstance(e, Case):
            s_ep, c0 = self._use_ep(ctx, e.ep, e.pos)
            if not isinstance(s_ep.s, ExtChoice):
                hint = (" — endpoint offers +{...}; use select"
                        if isinstance(s_ep.s, IntChoice) else "")
                raise SIRError(
                    E_PROTOCOL,
                    f"case on {e.ep!r} : {pp_ty(s_ep)} — endpoint does not "
                    f"offer &{{...}}{hint}", e.pos)
            offered = dict(s_ep.s.branches)
            given = {lab for lab, _, _ in e.branches}
            if given != set(offered):
                missing = sorted(set(offered) - given)
                extra = sorted(given - set(offered))
                raise SIRError(
                    E_PROTOCOL,
                    f"case on {e.ep!r} must cover exactly the offered labels; "
                    f"missing={missing} extra={extra}", e.pos)
            # case is a destructor: the scrutinee name leaves the context and
            # each branch binds its continuation as xi : Si.
            base = dict(c0)
            del base[e.ep]
            self.graveyard[e.ep] = "used"
            res_ty: Optional[Ty] = None
            res_ctx: Optional[Ctx] = None  # linear part only: unrestricted
            grades: List[int] = []         # names may differ across branches

            def linear_part(c: Ctx) -> Ctx:
                return {n: t for n, t in c.items() if is_linear(t)}

            for lab, x, body in e.branches:
                bi = self._bind(base, x, SessT(offered[lab]), e.pos)
                t, r, c = self.check(bi, body)
                grades.append(r)
                last_ctx = c
                lin = linear_part(c)
                if res_ty is None:
                    res_ty, res_ctx = t, lin
                else:
                    if not ty_eq(t, res_ty):
                        raise SIRError(
                            E_CASE_TYPE,
                            f"branch {lab!r} returns {pp_ty(t)} but an "
                            f"earlier branch returns {pp_ty(res_ty)}", e.pos)
                    if lin != res_ctx:
                        raise SIRError(
                            E_CASE_LINEAR,
                            f"branch {lab!r} leaves a different live linear "
                            f"state than earlier branches "
                            f"({sorted(lin)} vs {sorted(res_ctx or {})}) "
                            f"— all branches must agree", e.pos)
            assert res_ty is not None and res_ctx is not None
            # Post-case context: the (branch-independent) linear part plus the
            # unrestricted names that were live before the case.  Branch-local
            # binders do not escape their branch.
            out_ctx: Ctx = dict(res_ctx)
            for n, t in base.items():
                if not is_linear(t):
                    out_ctx[n] = t
            return res_ty, MaxPlus.op_mul(MaxPlus.one, MaxPlus.op_sum(grades)), out_ctx

        if isinstance(e, Let):
            t1, r1, c1 = self.check(ctx, e.e1)
            if e.ann is not None and not ty_eq(t1, e.ann):
                raise SIRError(E_LET_TYPE,
                               f"let {e.x!r}: annotation says {pp_ty(e.ann)} "
                               f"but e1 has type {pp_ty(t1)}", e.pos)
            if e.bound is not None and r1 > e.bound:
                raise SIRError(E_BOUND,
                               f"let {e.x!r}: computed grade {r1} exceeds "
                               f"claimed bound @{e.bound}", e.pos)
            if e.x == "_":
                if is_linear(t1):
                    raise SIRError(E_LEAK,
                                   f"linear value of type {pp_ty(t1)} "
                                   f"discarded to _", e.pos)
            else:
                c1 = self._bind(c1, e.x, t1, e.pos)
            t2, r2, c2 = self.check(c1, e.e2)
            return t2, MaxPlus.op_mul(r1, r2), c2

        raise AssertionError(f"unreachable term {e!r}")


def check_program(e: Term) -> CheckResult:
    """Top level: result must be Unit and every linear name must be consumed."""
    ck = Checker()
    t, r, out = ck.check({}, e)
    if is_linear(t):
        raise SIRError(E_LEAK,
                       f"top-level result {pp_ty(t)} is linear and is not "
                       f"consumed", e.pos)
    leaked = sorted(n for n, ty in out.items() if is_linear(ty))
    if leaked:
        raise SIRError(E_LEAK,
                       f"linear resources never consumed: "
                       f"{', '.join(f'{n} : {pp_ty(out[n])}' for n in leaked)}",
                       e.pos)
    return CheckResult(t, r)
