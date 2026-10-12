# SPDX-License-Identifier: MPL-2.0
# Session IR: types, session types, terms, grades (max-plus), error codes.
# Port of src/session_ir/syntax.py (2026-10-12).

const GRADE_ZERO = 0
const GRADE_ONE  = 1

module MaxPlus
const zero = 0
const one  = 1
op_add(x::Int, y::Int) = x >= y ? x : y
op_mul(x::Int, y::Int) = x + y
op_sum(xs) = foldl(op_add, xs; init=zero)
op_seq(xs) = foldl(op_mul, xs; init=zero)
end

struct SIRError <: Exception
    code::String
    msg::String
    pos::Union{Nothing,Tuple{Int,Int}}
end
SIRError(code, msg) = SIRError(code, msg, nothing)
Base.showerror(io::IO, e::SIRError) =
    print(io, e.code, ": ", e.msg, e.pos === nothing ? "" : " (at $(e.pos[1]):$(e.pos[2]))")

const E_UNKNOWN = "E_UNKNOWN"; const E_ALIAS = "E_ALIAS"; const E_USE_AFTER_DROP = "E_USE_AFTER_DROP"
const E_DOUBLE_FREE = "E_DOUBLE_FREE"; const E_LEAK = "E_LEAK"; const E_PROTOCOL = "E_PROTOCOL"
const E_CLOSE_NOT_END = "E_CLOSE_NOT_END"; const E_DROP_TYPE = "E_DROP_TYPE"; const E_BOUND = "E_BOUND"
const E_CASE_LINEAR = "E_CASE_LINEAR"; const E_CASE_TYPE = "E_CASE_TYPE"; const E_LET_TYPE = "E_LET_TYPE"
const E_SYNTAX = "E_SYNTAX"
const R_DEADLOCK = "R_DEADLOCK"; const R_CLOSE_PENDING = "R_CLOSE_PENDING"; const R_UNSOUND = "R_UNSOUND"
const R_INTERNAL = "R_INTERNAL"

# ---- types and session types (structural equality via struct fields) ----
abstract type Ty end
abstract type Sess end
struct UnitT <: Ty end
struct BufT  <: Ty; n::Int end
struct PairT <: Ty; a::Ty; b::Ty end
struct SessT <: Ty; s::Sess end
struct End       <: Sess end
struct Send      <: Sess; msg::Ty; cont::Sess end
struct Recv      <: Sess; msg::Ty; cont::Sess end
struct IntChoice <: Sess; branches::Vector{Tuple{String,Sess}} end
struct ExtChoice <: Sess; branches::Vector{Tuple{String,Sess}} end
const UNIT = UnitT()

# Structural equality and hashing for all node types (dataclass semantics).
for T in (:BufT, :PairT, :SessT, :Send, :Recv, :IntChoice, :ExtChoice)
    @eval Base.:(==)(a::$T, b::$T) = all(getfield(a, f) == getfield(b, f) for f in fieldnames($T))
    @eval Base.hash(a::$T, h::UInt) = foldl((h, f) -> hash(getfield(a, f), h), fieldnames($T); init=hash($T, h))
end

is_linear(::UnitT) = false
is_linear(::BufT)  = true
is_linear(::SessT) = true
is_linear(t::PairT) = is_linear(t.a) || is_linear(t.b)

dual(::End) = End()
dual(s::Send) = Recv(s.msg, dual(s.cont))
dual(s::Recv) = Send(s.msg, dual(s.cont))
dual(s::IntChoice) = ExtChoice([(l, dual(c)) for (l, c) in s.branches])
dual(s::ExtChoice) = IntChoice([(l, dual(c)) for (l, c) in s.branches])

pp_ty(::UnitT) = "Unit"
pp_ty(t::BufT) = "Buf $(t.n)"
function pp_ty(t::PairT)
    left = pp_ty(t.a)
    t.a isa PairT && (left = "($left)")
    "$left * $(pp_ty(t.b))"
end
pp_ty(t::SessT) = pp_sess(t.s)
pp_sess(::End) = "End"
pp_sess(s::Send) = "!$(pp_ty(s.msg)).$(pp_sess(s.cont))"
pp_sess(s::Recv) = "?$(pp_ty(s.msg)).$(pp_sess(s.cont))"
function pp_sess(s::Union{IntChoice,ExtChoice})
    op = s isa IntChoice ? "+" : "&"
    inner = join(["$l: $(pp_sess(c))" for (l, c) in s.branches], ", ")
    "$op{$inner}"
end
ty_eq(a::Ty, b::Ty) = a == b

# ---- terms ----
abstract type Term end
const Pos = Tuple{Int,Int}
struct Var     <: Term; name::String; pos::Pos end
struct UnitLit <: Term; pos::Pos end
struct Alloc   <: Term; n::Int; pos::Pos end
struct Drop    <: Term; e::Term; pos::Pos end
struct Pair    <: Term; e1::Term; e2::Term; pos::Pos end
struct LetPair <: Term; x::String; y::String; e1::Term; e2::Term; pos::Pos end
struct New     <: Term; s::Sess; pos::Pos end
struct SendT   <: Term; ep::String; val::Term; pos::Pos end
struct RecvT   <: Term; ep::String; pos::Pos end
struct Close   <: Term; ep::String; pos::Pos end
struct Select  <: Term; label::String; ep::String; pos::Pos end
struct Case    <: Term; ep::String; branches::Vector{Tuple{String,String,Term}}; pos::Pos end
struct Let     <: Term; x::String; ann::Union{Nothing,Ty}; bound::Union{Nothing,Int}; e1::Term; e2::Term; pos::Pos end
