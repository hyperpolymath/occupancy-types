# SPDX-License-Identifier: MPL-2.0
# Lexer and recursive-descent parser for Session IR.  Port of parser.py.

const KEYWORDS = Set(["unit","alloc","drop","pair","letpair","in","new","send","recv","close","select","case","let"])
const Tok = Tuple{String,String,Int,Int}   # kind, text, line, col

mutable struct Lexer
    src::Vector{Char}; i::Int; line::Int; col::Int
end
Lexer(s::AbstractString) = Lexer(collect(s), 1, 1, 1)
peekc(L::Lexer) = L.i <= length(L.src) ? L.src[L.i] : '\0'
function bump!(L::Lexer)
    ch = L.src[L.i]; L.i += 1
    if ch == '\n'; L.line += 1; L.col = 1 else L.col += 1 end
    ch
end
function skipws!(L::Lexer)
    while L.i <= length(L.src) && L.src[L.i] in (' ', '\t', '\r', '\n'); bump!(L) end
end
function comment!(L::Lexer, line, col)
    bump!(L); bump!(L)
    while true
        L.i > length(L.src) && throw(SIRError(E_SYNTAX, "unterminated comment", (line, col)))
        if L.i + 1 <= length(L.src) && L.src[L.i] == '*' && L.src[L.i+1] == ')'
            bump!(L); bump!(L); return
        end
        bump!(L)
    end
end
"""
Consume the remaining source and return tokens with one-based line and character
column positions, ending with an EOF token. Skip whitespace and non-nested
`(* ... *)` comments; a NUL character also ends input. Throw `SIRError(E_SYNTAX, ...)`
for an unexpected character or unterminated comment.
"""
function tokens(L::Lexer)
    out = Tok[]
    while true
        skipws!(L)
        line, col = L.line, L.col
        ch = peekc(L)
        if ch == '\0'; push!(out, ("EOF", "", line, col)); return out end
        if ch == '(' && L.i + 1 <= length(L.src) && L.src[L.i+1] == '*'
            comment!(L, line, col); continue
        end
        if isdigit(ch)
            n = ""; while isdigit(peekc(L)); n *= bump!(L) end
            push!(out, ("INT", n, line, col)); continue
        end
        if isletter(ch) || ch == '_'
            n = ""
            while true
                c = peekc(L)
                if isletter(c) || isdigit(c) || c == '_' || c == '\''; n *= bump!(L) else break end
            end
            push!(out, ("NAME", n, line, col)); continue
        end
        if ch in "!?+&*.,{}()=:@["
            push!(out, ("SYM", string(bump!(L)), line, col)); continue
        end
        throw(SIRError(E_SYNTAX, "unexpected character '$ch'", (line, col)))
    end
end

mutable struct Parser
    toks::Vector{Tok}; p::Int
end
Parser(src::AbstractString) = Parser(tokens(Lexer(src)), 1)
tok(P::Parser) = P.toks[P.p]
pos(P::Parser) = (tok(P)[3], tok(P)[4])
at(P::Parser, kind, text=nothing) = (t = tok(P); t[1] == kind && (text === nothing || t[2] == text))
"""
Return and consume the current token if its kind and optional text match.
Throw `SIRError(E_SYNTAX, ...)` without advancing on a mismatch.
"""
function eat!(P::Parser, kind, text=nothing)
    if !at(P, kind, text)
        t = tok(P); want = text === nothing ? kind : text; got = t[2] == "" ? t[1] : t[2]
        throw(SIRError(E_SYNTAX, "expected '$want', found '$got'", (t[3], t[4])))
    end
    t = tok(P); P.p += 1; t
end
parse_program(P::Parser) = (e = parse_term(P); eat!(P, "EOF"); e)

"""
Consume a type, grouping successive products to the left, and return its type node.
Syntax errors propagate as `SIRError(E_SYNTAX, ...)`; integer parsing errors for
buffer sizes also propagate.
"""
function parse_type(P::Parser)
    t = parse_type_atom(P)
    while at(P, "SYM", "*"); eat!(P, "SYM", "*"); t = PairT(t, parse_type_atom(P)) end
    t
end
function parse_type_atom(P::Parser)
    tk = tok(P)
    if at(P, "NAME", "Unit"); eat!(P, "NAME", "Unit"); return UNIT end
    if at(P, "NAME", "Buf"); eat!(P, "NAME", "Buf"); return BufT(parse(Int, eat!(P, "INT")[2])) end
    if at(P, "NAME", "End"); return SessT(parse_session_atom(P)) end
    if at(P, "SYM", "!") || at(P, "SYM", "?") || at(P, "SYM", "+") || at(P, "SYM", "&")
        return SessT(parse_session_atom(P))
    end
    if at(P, "SYM", "("); eat!(P, "SYM", "("); t = parse_type(P); eat!(P, "SYM", ")"); return t end
    throw(SIRError(E_SYNTAX, "expected a type, found '$(tk[2] == "" ? tk[1] : tk[2])'", (tk[3], tk[4])))
end
function parse_session_atom(P::Parser)
    tk = tok(P)
    if at(P, "NAME", "End"); eat!(P, "NAME", "End"); return End() end
    if at(P, "SYM", "!") || at(P, "SYM", "?")
        is_send = eat!(P, "SYM")[2] == "!"
        msg = parse_type(P); eat!(P, "SYM", ".")
        cont = parse_type(P)
        cont isa SessT || throw(SIRError(E_SYNTAX, "session continuation after '.' must be a session type", pos(P)))
        return is_send ? Send(msg, cont.s) : Recv(msg, cont.s)
    end
    if at(P, "SYM", "+") || at(P, "SYM", "&")
        is_int = eat!(P, "SYM")[2] == "+"
        eat!(P, "SYM", "{")
        brs = Tuple{String,Sess}[]; seen = Set{String}()
        while !at(P, "SYM", "}")
            lab = eat!(P, "NAME")[2]
            lab in seen && throw(SIRError(E_SYNTAX, "duplicate branch label '$lab'", pos(P)))
            push!(seen, lab); eat!(P, "SYM", ":")
            s = parse_type(P)
            s isa SessT || throw(SIRError(E_SYNTAX, "branch '$lab' continuation must be a session type", pos(P)))
            push!(brs, (lab, s.s))
            at(P, "SYM", ",") && eat!(P, "SYM", ",")
        end
        eat!(P, "SYM", "}")
        isempty(brs) && throw(SIRError(E_SYNTAX, "choice must have at least one branch", pos(P)))
        return is_int ? IntChoice(brs) : ExtChoice(brs)
    end
    throw(SIRError(E_SYNTAX, "expected a session type, found '$(tk[2] == "" ? tk[1] : tk[2])'", (tk[3], tk[4])))
end
function parse_term(P::Parser)
    tk = tok(P); ps = (tk[3], tk[4])
    if at(P, "SYM", "("); eat!(P, "SYM", "("); e = parse_term(P); eat!(P, "SYM", ")"); return e end
    if at(P, "NAME", "unit"); eat!(P, "NAME", "unit"); return UnitLit(ps) end
    if at(P, "NAME", "alloc"); eat!(P, "NAME", "alloc"); return Alloc(parse(Int, eat!(P, "INT")[2]), ps) end
    if at(P, "NAME", "drop"); eat!(P, "NAME", "drop"); return Drop(parse_term(P), ps) end
    if at(P, "NAME", "pair"); eat!(P, "NAME", "pair"); e1 = parse_term(P); return Pair(e1, parse_term(P), ps) end
    if at(P, "NAME", "letpair")
        eat!(P, "NAME", "letpair"); x = eat!(P, "NAME")[2]; y = eat!(P, "NAME")[2]; eat!(P, "SYM", "=")
        e1 = parse_term(P); eat!(P, "NAME", "in"); return LetPair(x, y, e1, parse_term(P), ps)
    end
    if at(P, "NAME", "new")
        eat!(P, "NAME", "new"); t = parse_type(P)
        t isa SessT || throw(SIRError(E_SYNTAX, "new expects a session type", pos(P)))
        return New(t.s, ps)
    end
    if at(P, "NAME", "send"); eat!(P, "NAME", "send"); ep = eat!(P, "NAME")[2]; return SendT(ep, parse_term(P), ps) end
    if at(P, "NAME", "recv"); eat!(P, "NAME", "recv"); return RecvT(eat!(P, "NAME")[2], ps) end
    if at(P, "NAME", "close"); eat!(P, "NAME", "close"); return Close(eat!(P, "NAME")[2], ps) end
    if at(P, "NAME", "select"); eat!(P, "NAME", "select"); lab = eat!(P, "NAME")[2]; return Select(lab, eat!(P, "NAME")[2], ps) end
    if at(P, "NAME", "case")
        eat!(P, "NAME", "case"); ep = eat!(P, "NAME")[2]; eat!(P, "SYM", "{")
        brs = Tuple{String,String,Term}[]; seen = Set{String}()
        while !at(P, "SYM", "}")
            lab = eat!(P, "NAME")[2]
            lab in seen && throw(SIRError(E_SYNTAX, "duplicate branch label '$lab'", pos(P)))
            push!(seen, lab); eat!(P, "SYM", ":"); x = eat!(P, "NAME")[2]; eat!(P, "SYM", ".")
            push!(brs, (lab, x, parse_term(P)))
            at(P, "SYM", ",") && eat!(P, "SYM", ",")
        end
        eat!(P, "SYM", "}")
        isempty(brs) && throw(SIRError(E_SYNTAX, "case must have at least one branch", pos(P)))
        return Case(ep, brs, ps)
    end
    if at(P, "NAME", "let")
        eat!(P, "NAME", "let"); x = eat!(P, "NAME")[2]
        ann = nothing; bound = nothing
        if at(P, "SYM", ":"); eat!(P, "SYM", ":"); ann = parse_type(P) end
        if at(P, "SYM", "@"); eat!(P, "SYM", "@"); bound = parse(Int, eat!(P, "INT")[2]) end
        eat!(P, "SYM", "="); e1 = parse_term(P); eat!(P, "NAME", "in")
        return Let(x, ann, bound, e1, parse_term(P), ps)
    end
    if at(P, "NAME")
        name = eat!(P, "NAME")[2]
        name in KEYWORDS && throw(SIRError(E_SYNTAX, "keyword '$name' used as a variable", ps))
        return Var(name, ps)
    end
    throw(SIRError(E_SYNTAX, "expected a term, found '$(tk[2] == "" ? tk[1] : tk[2])'", ps))
end
"""
    parse_sir(src::AbstractString)

Parse Session IR source into a term with one-based source positions. Require an
EOF token after the term; lexing treats NUL as end of input. Throw
`SIRError(E_SYNTAX, ...)` for lexical or grammatical errors. Integer parsing errors
for sizes and grade bounds propagate unchanged. Type and ownership checks are
performed separately by `check_program`.
"""
parse_sir(src::AbstractString) = parse_program(Parser(src))
