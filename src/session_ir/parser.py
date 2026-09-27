# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""Lexer + recursive-descent parser for the Session IR concrete syntax.

Concrete syntax (comments are (* ... *), non-nested):

    e ::= unit | alloc INT | drop e | pair e e
        | letpair x y = e in e
        | new t | send x e | recv x | close x | select l x
        | case x { l: y. e , ... }
        | let x [: t] [@ INT] = e in e
        | ( e ) | x

    t ::= Unit | Buf INT | t * t | s | ( t )
    s ::= End | ! t . s | ? t . s | + { l: t, ... } | & { l: t, ... }

The channel operand of send/recv/close/select/case must be a name (the linear
typing of endpoints is name-based).
"""

from __future__ import annotations

from typing import List, Optional, Tuple

from .syntax import (
    Alloc, BufT, Case, Close, Drop, End, ExtChoice, IntChoice, Let, LetPair,
    New, Pair, PairT, Recv, RecvT, Sess, SessT, SIRError, Send, SendT, Select,
    Term, Ty, UNIT, UnitLit, UnitT, Var, E_SYNTAX,
)

KEYWORDS = {
    "unit", "alloc", "drop", "pair", "letpair", "in", "new", "send", "recv",
    "close", "select", "case", "let",
}

# token kinds: NAME, INT, SYM, EOF
_TOK = Tuple[str, str, int, int]  # (kind, text, line, col)


class Lexer:
    def __init__(self, src: str):
        self.src = src
        self.i = 0
        self.line = 1
        self.col = 1

    def _peek(self) -> str:
        return self.src[self.i] if self.i < len(self.src) else ""

    def _bump(self) -> str:
        ch = self.src[self.i]
        self.i += 1
        if ch == "\n":
            self.line += 1
            self.col = 1
        else:
            self.col += 1
        return ch

    def tokens(self) -> List[_TOK]:
        out: List[_TOK] = []
        while True:
            self._skip_ws()
            line, col = self.line, self.col
            ch = self._peek()
            if ch == "":
                out.append(("EOF", "", line, col))
                return out
            if ch == "(" and self.src[self.i:self.i + 2] == "(*":
                self._comment(line, col)
                continue
            if ch.isdigit():
                n = ""
                while self._peek().isdigit():
                    n += self._bump()
                out.append(("INT", n, line, col))
                continue
            if ch.isalpha() or ch == "_":
                n = ""
                while True:
                    c = self._peek()
                    if c.isalnum() or c in "_'":
                        n += self._bump()
                    else:
                        break
                out.append(("NAME", n, line, col))
                continue
            if ch in "!?+&*.,{}()=:@[":
                out.append(("SYM", self._bump(), line, col))
                continue
            raise SIRError(E_SYNTAX, f"unexpected character {ch!r}", (line, col))

    def _skip_ws(self) -> None:
        while self._peek() and self._peek() in " \t\r\n":
            self._bump()

    def _comment(self, line: int, col: int) -> None:
        self._bump()  # (
        self._bump()  # *
        while True:
            if self._peek() == "":
                raise SIRError(E_SYNTAX, "unterminated comment", (line, col))
            if self.src[self.i:self.i + 2] == "*)":
                self._bump()
                self._bump()
                return
            self._bump()


class Parser:
    def __init__(self, src: str):
        self.toks: List[_TOK] = Lexer(src).tokens()
        self.p = 0

    # -- token helpers ------------------------------------------------------
    def _tok(self) -> _TOK:
        return self.toks[self.p]

    def _pos(self) -> Tuple[int, int]:
        t = self._tok()
        return (t[2], t[3])

    def _at(self, kind: str, text: Optional[str] = None) -> bool:
        t = self._tok()
        return t[0] == kind and (text is None or t[1] == text)

    def _eat(self, kind: str, text: Optional[str] = None) -> _TOK:
        if not self._at(kind, text):
            t = self._tok()
            want = text if text is not None else kind
            got = t[1] if t[1] else t[0]
            raise SIRError(E_SYNTAX, f"expected {want!r}, found {got!r}", (t[2], t[3]))
        t = self._tok()
        self.p += 1
        return t

    def _at_name(self, kw: str) -> bool:
        return self._at("NAME", kw)

    # -- entry --------------------------------------------------------------
    def parse_program(self) -> Term:
        e = self.parse_term()
        self._eat("EOF")
        return e

    # -- types & sessions ---------------------------------------------------
    def parse_type(self) -> Ty:
        t = self.parse_type_atom()
        while self._at("SYM", "*"):
            self._eat("SYM", "*")
            t = PairT(t, self.parse_type_atom())
        return t

    def parse_type_atom(self) -> Ty:
        tk = self._tok()
        if self._at("NAME", "Unit"):
            self._eat("NAME", "Unit")
            return UNIT
        if self._at("NAME", "Buf"):
            self._eat("NAME", "Buf")
            n = int(self._eat("INT")[1])
            return BufT(n)
        if self._at("NAME", "End"):
            return SessT(self.parse_session_atom())
        if self._at("SYM", "!") or self._at("SYM", "?") \
                or self._at("SYM", "+") or self._at("SYM", "&"):
            return SessT(self.parse_session_atom())
        if self._at("SYM", "("):
            self._eat("SYM", "(")
            t = self.parse_type()
            self._eat("SYM", ")")
            return t
        raise SIRError(E_SYNTAX, f"expected a type, found {tk[1] or tk[0]!r}",
                       (tk[2], tk[3]))

    def parse_session_atom(self) -> Sess:
        tk = self._tok()
        if self._at("NAME", "End"):
            self._eat("NAME", "End")
            return End()
        if self._at("SYM", "!") or self._at("SYM", "?"):
            is_send = self._eat("SYM")[1] == "!"
            msg = self.parse_type()
            self._eat("SYM", ".")
            cont = self.parse_type()
            if not isinstance(cont, SessT):
                raise SIRError(E_SYNTAX,
                               "session continuation after '.' must be a session type",
                               self._pos())
            return Send(msg, cont.s) if is_send else Recv(msg, cont.s)
        if self._at("SYM", "+") or self._at("SYM", "&"):
            is_int = self._eat("SYM")[1] == "+"
            self._eat("SYM", "{")
            brs = []
            seen = set()
            while not self._at("SYM", "}"):
                lab = self._eat("NAME")[1]
                if lab in seen:
                    raise SIRError(E_SYNTAX, f"duplicate branch label {lab!r}", self._pos())
                seen.add(lab)
                self._eat("SYM", ":")
                s = self.parse_type()
                if not isinstance(s, SessT):
                    raise SIRError(E_SYNTAX,
                                   f"branch {lab!r} continuation must be a session type",
                                   self._pos())
                brs.append((lab, s.s))
                if self._at("SYM", ","):
                    self._eat("SYM", ",")
            self._eat("SYM", "}")
            if not brs:
                raise SIRError(E_SYNTAX, "choice must have at least one branch", self._pos())
            return IntChoice(tuple(brs)) if is_int else ExtChoice(tuple(brs))
        raise SIRError(E_SYNTAX, f"expected a session type, found {tk[1] or tk[0]!r}",
                       (tk[2], tk[3]))

    # -- terms --------------------------------------------------------------
    def parse_term(self) -> Term:
        tk = self._tok()
        pos = (tk[2], tk[3])

        if self._at("SYM", "("):
            self._eat("SYM", "(")
            e = self.parse_term()
            self._eat("SYM", ")")
            return e

        if self._at("NAME", "unit"):
            self._eat("NAME", "unit")
            return UnitLit(pos)

        if self._at("NAME", "alloc"):
            self._eat("NAME", "alloc")
            return Alloc(int(self._eat("INT")[1]), pos)

        if self._at("NAME", "drop"):
            self._eat("NAME", "drop")
            return Drop(self.parse_term(), pos)

        if self._at("NAME", "pair"):
            self._eat("NAME", "pair")
            return Pair(self.parse_term(), self.parse_term(), pos)

        if self._at("NAME", "letpair"):
            self._eat("NAME", "letpair")
            x = self._eat("NAME")[1]
            y = self._eat("NAME")[1]
            self._eat("SYM", "=")
            e1 = self.parse_term()
            self._eat("NAME", "in")
            return LetPair(x, y, e1, self.parse_term(), pos)

        if self._at("NAME", "new"):
            self._eat("NAME", "new")
            t = self.parse_type()
            if not isinstance(t, SessT):
                raise SIRError(E_SYNTAX, "new expects a session type", self._pos())
            return New(t.s, pos)

        if self._at("NAME", "send"):
            self._eat("NAME", "send")
            ep = self._eat("NAME")[1]
            return SendT(ep, self.parse_term(), pos)

        if self._at("NAME", "recv"):
            self._eat("NAME", "recv")
            return RecvT(self._eat("NAME")[1], pos)

        if self._at("NAME", "close"):
            self._eat("NAME", "close")
            return Close(self._eat("NAME")[1], pos)

        if self._at("NAME", "select"):
            self._eat("NAME", "select")
            lab = self._eat("NAME")[1]
            return Select(lab, self._eat("NAME")[1], pos)

        if self._at("NAME", "case"):
            self._eat("NAME", "case")
            ep = self._eat("NAME")[1]
            self._eat("SYM", "{")
            brs = []
            seen = set()
            while not self._at("SYM", "}"):
                lab = self._eat("NAME")[1]
                if lab in seen:
                    raise SIRError(E_SYNTAX, f"duplicate branch label {lab!r}", self._pos())
                seen.add(lab)
                self._eat("SYM", ":")
                x = self._eat("NAME")[1]
                self._eat("SYM", ".")
                brs.append((lab, x, self.parse_term()))
                if self._at("SYM", ","):
                    self._eat("SYM", ",")
            self._eat("SYM", "}")
            if not brs:
                raise SIRError(E_SYNTAX, "case must have at least one branch", self._pos())
            return Case(ep, tuple(brs), pos)

        if self._at("NAME", "let"):
            self._eat("NAME", "let")
            x = self._eat("NAME")[1]
            ann: Optional[Ty] = None
            bound: Optional[int] = None
            if self._at("SYM", ":"):
                self._eat("SYM", ":")
                ann = self.parse_type()
            if self._at("SYM", "@"):
                self._eat("SYM", "@")
                bound = int(self._eat("INT")[1])
            self._eat("SYM", "=")
            e1 = self.parse_term()
            self._eat("NAME", "in")
            return Let(x, ann, bound, e1, self.parse_term(), pos)

        if self._at("NAME"):
            name = self._eat("NAME")[1]
            if name in KEYWORDS:
                raise SIRError(E_SYNTAX, f"keyword {name!r} used as a variable", pos)
            return Var(name, pos)

        raise SIRError(E_SYNTAX, f"expected a term, found {tk[1] or tk[0]!r}", pos)


def parse(src: str) -> Term:
    return Parser(src).parse_program()
