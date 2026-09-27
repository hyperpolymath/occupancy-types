# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""Deterministic stepper for closed Session IR programs.

Machine configuration (docs/OPERATIONAL-MODEL.md):
  * heap: linear buffers, explicit drop only (no GC, no implicit copy);
  * channels: two queues between paired endpoints (created by `new`);
  * one thread of control (single program term, lets sequence everything);
  * clock: communication steps (send / recv / select / case each count 1).

Statistics recorded (operational readings, NOT grades in v0):
  * comm_steps  — measured cost, asserted <= certified grade r;
  * peak_live   — high-water mark of live buffer bytes;
  * peak_inflight — high-water mark of queued channel events.

Machine-level errors (R_*) should be unreachable for well-typed programs;
they are machine self-checks, and fire loudly if the checker and the machine
ever disagree.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from .syntax import (
    Alloc, BufT, Case, Close, Drop, E_PROTOCOL, End, Let, LetPair, MaxPlus, New,
    Pair, PairT, R_CLOSE_PENDING, R_DEADLOCK, R_INTERNAL, RecvT, SIRError, SendT,
    Select, SessT, Term, UnitLit, Var, is_linear, pp_ty,
)


class BufVal:
    __slots__ = ("bid", "size", "dropped")

    def __init__(self, bid: int, size: int):
        self.bid = bid
        self.size = size
        self.dropped = False

    def __repr__(self) -> str:
        return f"<buf#{self.bid}:{self.size}>"


class EpVal:
    __slots__ = ("chan", "side")

    def __init__(self, chan: "Chan", side: str):
        self.chan = chan
        self.side = side  # "a" | "b"

    def __repr__(self) -> str:
        return f"<ep {self.chan.cid}.{self.side}>"


class Chan:
    __slots__ = ("cid", "queues", "closed")

    def __init__(self, cid: int):
        self.cid = cid
        self.queues: Dict[str, List[Tuple[str, Any]]] = {"a": [], "b": []}
        self.closed = {"a": False, "b": False}

    @staticmethod
    def other(side: str) -> str:
        return "b" if side == "a" else "a"


class PairVal:
    __slots__ = ("v1", "v2")

    def __init__(self, v1: Any, v2: Any):
        self.v1 = v1
        self.v2 = v2


class RunStats:
    def __init__(self) -> None:
        self.comm_steps = 0
        self.peak_live = 0
        self.peak_inflight = 0
        self.live_bytes = 0
        self.trace: List[str] = []

    def note(self, msg: str) -> None:
        self.trace.append(msg)


class Machine:
    def __init__(self) -> None:
        self.stats = RunStats()
        self.next_bid = 0
        self.next_cid = 0
        self.chans: List[Chan] = []

    # -- helpers ------------------------------------------------------------
    def _inflight(self) -> int:
        return sum(len(q) for c in self.chans for q in c.queues.values())

    def _touch_inflight(self) -> None:
        self.stats.peak_inflight = max(self.stats.peak_inflight, self._inflight())

    def _ep(self, env: Dict[str, Any], name: str, pos) -> EpVal:
        v = env.get(name)
        if not isinstance(v, EpVal):
            raise SIRError(R_INTERNAL,
                           f"{name!r} is not an endpoint at runtime", pos)
        return v

    # -- evaluation ---------------------------------------------------------
    def run(self, e: Term) -> Any:
        v = self.eval(e, {})
        # Self-check: well-typed programs drain every channel queue.
        pending = self._inflight()
        if pending:
            raise SIRError(R_CLOSE_PENDING,
                           f"{pending} channel event(s) still queued at end "
                           f"of program", e.pos)
        return v

    def eval(self, e: Term, env: Dict[str, Any]) -> Any:
        st = self.stats

        if isinstance(e, Var):
            return env[e.name]

        if isinstance(e, UnitLit):
            return None

        if isinstance(e, Alloc):
            b = BufVal(self.next_bid, e.n)
            self.next_bid += 1
            st.live_bytes += e.n
            st.peak_live = max(st.peak_live, st.live_bytes)
            st.note(f"alloc {e.n} -> {b!r} (live={st.live_bytes})")
            return b

        if isinstance(e, Drop):
            v = self.eval(e.e, env)
            if not isinstance(v, BufVal):
                raise SIRError(R_INTERNAL, "drop of a non-buffer at runtime", e.pos)
            if v.dropped:
                raise SIRError(R_INTERNAL, "double free at runtime", e.pos)
            v.dropped = True
            st.live_bytes -= v.size
            st.note(f"drop {v!r} (live={st.live_bytes})")
            return None

        if isinstance(e, Pair):
            return PairVal(self.eval(e.e1, env), self.eval(e.e2, env))

        if isinstance(e, LetPair):
            v = self.eval(e.e1, env)
            if not isinstance(v, PairVal):
                raise SIRError(R_INTERNAL, "letpair of a non-pair", e.pos)
            env2 = dict(env)
            env2[e.x] = v.v1
            env2[e.y] = v.v2
            return self.eval(e.e2, env2)

        if isinstance(e, New):
            c = Chan(self.next_cid)
            self.next_cid += 1
            self.chans.append(c)
            st.note(f"new channel {c.cid} ({pp_ty(SessT(e.s))} | dual)")
            return PairVal(EpVal(c, "a"), EpVal(c, "b"))

        if isinstance(e, SendT):
            ep = self._ep(env, e.ep, e.pos)
            v = self.eval(e.val, env)
            ep.chan.queues[Chan.other(ep.side)].append(("msg", v))
            st.comm_steps += 1
            self._touch_inflight()
            st.note(f"send {ep!r} (step {st.comm_steps})")
            return None

        if isinstance(e, RecvT):
            ep = self._ep(env, e.ep, e.pos)
            q = ep.chan.queues[ep.side]
            if not q:
                raise SIRError(R_DEADLOCK,
                               f"recv on {e.ep!r} with nothing in flight", e.pos)
            kind, v = q.pop(0)
            if kind != "msg":
                raise SIRError(R_INTERNAL, "recv found a selection, not a message",
                               e.pos)
            st.comm_steps += 1
            self._touch_inflight()
            st.note(f"recv {ep!r} (step {st.comm_steps})")
            return v

        if isinstance(e, Select):
            ep = self._ep(env, e.ep, e.pos)
            ep.chan.queues[Chan.other(ep.side)].append(("sel", e.label))
            st.comm_steps += 1
            self._touch_inflight()
            st.note(f"select {e.label!r} on {ep!r} (step {st.comm_steps})")
            return None

        if isinstance(e, Case):
            ep = self._ep(env, e.ep, e.pos)
            q = ep.chan.queues[ep.side]
            if not q:
                raise SIRError(R_DEADLOCK,
                               f"case on {e.ep!r} with nothing in flight", e.pos)
            kind, lab = q.pop(0)
            if kind != "sel":
                raise SIRError(R_INTERNAL, "case found a message, not a selection",
                               e.pos)
            st.comm_steps += 1
            self._touch_inflight()
            st.note(f"case {ep!r} -> {lab!r} (step {st.comm_steps})")
            for blab, x, body in e.branches:
                if blab == lab:
                    env2 = dict(env)
                    env2[x] = ep  # continuation is the same endpoint value
                    return self.eval(body, env2)
            raise SIRError(R_INTERNAL, f"selected label {lab!r} has no branch", e.pos)

        if isinstance(e, Close):
            ep = self._ep(env, e.ep, e.pos)
            if ep.chan.closed[ep.side]:
                raise SIRError(R_INTERNAL, "endpoint closed twice at runtime", e.pos)
            if ep.chan.queues[ep.side]:
                raise SIRError(R_CLOSE_PENDING,
                               f"close {e.ep!r} with unconsumed messages", e.pos)
            ep.chan.closed[ep.side] = True
            st.note(f"close {ep!r}")
            return None

        if isinstance(e, Let):
            v = self.eval(e.e1, env)
            if e.x != "_":
                env = dict(env)
                env[e.x] = v
            return self.eval(e.e2, env)

        raise AssertionError(f"unreachable term {e!r}")


def run_program(e: Term) -> RunStats:
    m = Machine()
    m.run(e)
    return m.stats
