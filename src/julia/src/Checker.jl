# SPDX-License-Identifier: MPL-2.0
# Linear + session type checker with max-plus grades.  Port of checker.py.
# Contexts are ordered dictionaries name → Ty; the graveyard records why a
# linear name is gone so that the error is specific (alias / dropped / closed).

const Ctx = Dict{String,Ty}

struct CheckResult
    ty::Ty
    grade::Int
end

mutable struct Checker
    graveyard::Dict{String,String}
end
Checker() = Checker(Dict{String,String}())

"""
Return a copy of `ctx` binding `x` to `t`, clearing its consumption history in `ck`.
Throw `SIRError(E_ALIAS, ...)` if `x` already names a live linear value.
"""
function bind!(ck::Checker, ctx::Ctx, x::String, t::Ty, pos)
    haskey(ctx, x) && is_linear(ctx[x]) && throw(SIRError(E_ALIAS, "binder '$x' shadows a live linear name", pos))
    delete!(ck.graveyard, x)
    out = copy(ctx); out[x] = t; out
end

"""
Throw a `SIRError` for a missing name using its consumption history: `E_UNKNOWN`,
`E_ALIAS` or `E_USE_AFTER_DROP`. When `dropping` is true, an already dropped name
instead produces `E_DOUBLE_FREE`.
"""
function fail_consumed(ck::Checker, x::String, pos, dropping::Bool)
    reason = get(ck.graveyard, x, nothing)
    reason === nothing && throw(SIRError(E_UNKNOWN, "unbound name '$x'", pos))
    dropping && reason == "dropped" && throw(SIRError(E_DOUBLE_FREE, "buffer '$x' was already dropped", pos))
    reason == "dropped" && throw(SIRError(E_USE_AFTER_DROP, "buffer '$x' was dropped before this use", pos))
    reason == "closed" && throw(SIRError(E_USE_AFTER_DROP, "endpoint '$x' was closed before this use (use-after-close)", pos))
    throw(SIRError(E_ALIAS, "linear name '$x' already consumed at an earlier occurrence (aliasing)", pos))
end

"""
Return the named type and a copy of the context, removing linear names from that
copy and recording their use in `ck`. Missing names raise the `SIRError` selected
by `fail_consumed`.
"""
function use!(ck::Checker, ctx::Ctx, x::String, pos)
    if haskey(ctx, x)
        t = ctx[x]; out = copy(ctx)
        if is_linear(t); delete!(out, x); ck.graveyard[x] = "used" end
        return t, out
    end
    fail_consumed(ck, x, pos, false)
end

"""
Return the named session type and the original context without consuming the name.
Throw `SIRError(E_PROTOCOL, ...)` for a non-endpoint, or propagate the missing-name
error from `fail_consumed`.
"""
function use_ep(ck::Checker, ctx::Ctx, x::String, pos)
    if haskey(ctx, x)
        t = ctx[x]
        t isa SessT || throw(SIRError(E_PROTOCOL, "'$x' : $(pp_ty(t)) used where a session endpoint is required", pos))
        return t, ctx
    end
    fail_consumed(ck, x, pos, false)
end

"""Return a copy of `ctx` without `x`, recording `reason` in `ck` for later use errors."""
function consume_ep!(ck::Checker, ctx::Ctx, x::String, reason::String)
    out = copy(ctx); delete!(out, x); ck.graveyard[x] = reason; out
end

linear_part(c::Ctx) = Ctx(n => t for (n, t) in c if is_linear(t))

"""
Return `(type, communication_grade, remaining_context)` for a term, updating
`ck`'s consumption history without mutating `ctx`. Sequential grades add; a case
uses the maximum branch grade plus one. Send, receive, select and case each cost
one communication step. Throw `SIRError` for invalid ownership, protocol use,
branch agreement, type annotations or exceeded grade bounds. The caller must
check for an unconsumed linear result or remaining linear bindings.
"""
function check(ck::Checker, ctx::Ctx, e::Term)
    if e isa Var
        t, out = use!(ck, ctx, e.name, e.pos); return t, MaxPlus.zero, out
    elseif e isa UnitLit
        return UNIT, MaxPlus.zero, ctx
    elseif e isa Alloc
        return BufT(e.n), MaxPlus.zero, ctx
    elseif e isa Drop
        if e.e isa Var
            x = e.e.name
            haskey(ctx, x) || fail_consumed(ck, x, e.e.pos, true)
            t = ctx[x]
            t isa SessT && throw(SIRError(E_DROP_TYPE, "drop '$x' : endpoint — endpoints are consumed by close, not drop (D5)", e.pos))
            t isa BufT || throw(SIRError(E_DROP_TYPE, "drop '$x' : $(pp_ty(t)) — only Buf n can be dropped", e.pos))
            return UNIT, MaxPlus.zero, consume_ep!(ck, ctx, x, "dropped")
        end
        t, r, out = check(ck, ctx, e.e)
        t isa SessT && throw(SIRError(E_DROP_TYPE, "drop of an endpoint — use close (D5)", e.pos))
        t isa BufT || throw(SIRError(E_DROP_TYPE, "drop of $(pp_ty(t)) — only Buf n can be dropped", e.pos))
        return UNIT, r, out
    elseif e isa Pair
        t1, r1, c1 = check(ck, ctx, e.e1); t2, r2, c2 = check(ck, c1, e.e2)
        return PairT(t1, t2), MaxPlus.op_mul(r1, r2), c2
    elseif e isa LetPair
        t1, r1, c1 = check(ck, ctx, e.e1)
        t1 isa PairT || throw(SIRError(E_PROTOCOL, "letpair on $(pp_ty(t1)) — expected a pair", e.pos))
        e.x == e.y && throw(SIRError(E_ALIAS, "letpair binds both components as '$(e.x)'", e.pos))
        c1 = bind!(ck, c1, e.x, t1.a, e.pos); c1 = bind!(ck, c1, e.y, t1.b, e.pos)
        t2, r2, c2 = check(ck, c1, e.e2)
        return t2, MaxPlus.op_mul(r1, r2), c2
    elseif e isa New
        return PairT(SessT(e.s), SessT(dual(e.s))), MaxPlus.zero, ctx
    elseif e isa SendT
        s_ep, c0 = use_ep(ck, ctx, e.ep, e.pos)
        s_ep.s isa Send || throw(SIRError(E_PROTOCOL, "send on '$(e.ep)' : $(pp_ty(s_ep)) — endpoint does not offer !A.S", e.pos))
        c_pre = copy(c0); delete!(c_pre, e.ep)
        tv, rv, c1 = check(ck, c_pre, e.val)
        ty_eq(tv, s_ep.s.msg) || throw(SIRError(E_PROTOCOL, "send on '$(e.ep)': message type $(pp_ty(tv)) does not match declared $(pp_ty(s_ep.s.msg))", e.pos))
        c1 = copy(c1); c1[e.ep] = SessT(s_ep.s.cont)
        return UNIT, MaxPlus.op_mul(MaxPlus.one, rv), c1
    elseif e isa RecvT
        s_ep, c0 = use_ep(ck, ctx, e.ep, e.pos)
        s_ep.s isa Recv || throw(SIRError(E_PROTOCOL, "recv on '$(e.ep)' : $(pp_ty(s_ep)) — endpoint does not offer ?A.S", e.pos))
        c0 = copy(c0); c0[e.ep] = SessT(s_ep.s.cont)
        return s_ep.s.msg, MaxPlus.one, c0
    elseif e isa Close
        s_ep, c0 = use_ep(ck, ctx, e.ep, e.pos)
        s_ep.s isa End || throw(SIRError(E_CLOSE_NOT_END, "close '$(e.ep)' : $(pp_ty(s_ep)) — endpoint is not at End", e.pos))
        return UNIT, MaxPlus.zero, consume_ep!(ck, c0, e.ep, "closed")
    elseif e isa Select
        s_ep, c0 = use_ep(ck, ctx, e.ep, e.pos)
        s_ep.s isa IntChoice || throw(SIRError(E_PROTOCOL, "select on '$(e.ep)' : $(pp_ty(s_ep)) — endpoint does not offer +{...}", e.pos))
        labels = Dict(s_ep.s.branches)
        haskey(labels, e.label) || throw(SIRError(E_PROTOCOL, "select '$(e.label)' not offered by '$(e.ep)' : $(pp_ty(s_ep))", e.pos))
        c0 = copy(c0); c0[e.ep] = SessT(labels[e.label])
        return UNIT, MaxPlus.one, c0
    elseif e isa Case
        s_ep, c0 = use_ep(ck, ctx, e.ep, e.pos)
        if !(s_ep.s isa ExtChoice)
            hint = s_ep.s isa IntChoice ? " — endpoint offers +{...}; use select" : ""
            throw(SIRError(E_PROTOCOL, "case on '$(e.ep)' : $(pp_ty(s_ep)) — endpoint does not offer &{...}$hint", e.pos))
        end
        offered = Dict(s_ep.s.branches)
        given = Set(lab for (lab, _, _) in e.branches)
        if given != Set(keys(offered))
            missing = sort(collect(setdiff(Set(keys(offered)), given))); extra = sort(collect(setdiff(given, Set(keys(offered)))))
            throw(SIRError(E_PROTOCOL, "case on '$(e.ep)' must cover exactly the offered labels; missing=$missing extra=$extra", e.pos))
        end
        base = copy(c0); delete!(base, e.ep); ck.graveyard[e.ep] = "used"
        res_ty = nothing; res_ctx = nothing; grades = Int[]
        for (lab, x, body) in e.branches
            bi = bind!(ck, base, x, SessT(offered[lab]), e.pos)
            t, r, c = check(ck, bi, body)
            push!(grades, r)
            lin = linear_part(c)
            if res_ty === nothing
                res_ty = t; res_ctx = lin
            else
                ty_eq(t, res_ty) || throw(SIRError(E_CASE_TYPE, "branch '$lab' returns $(pp_ty(t)) but an earlier branch returns $(pp_ty(res_ty))", e.pos))
                lin == res_ctx || throw(SIRError(E_CASE_LINEAR, "branch '$lab' leaves a different live linear state than earlier branches ($(sort(collect(keys(lin)))) vs $(sort(collect(keys(res_ctx))))) — all branches must agree", e.pos))
            end
        end
        out_ctx = copy(res_ctx)
        for (n, t) in base; is_linear(t) || (out_ctx[n] = t) end
        return res_ty, MaxPlus.op_mul(MaxPlus.one, MaxPlus.op_sum(grades)), out_ctx
    elseif e isa Let
        t1, r1, c1 = check(ck, ctx, e.e1)
        e.ann !== nothing && !ty_eq(t1, e.ann) && throw(SIRError(E_LET_TYPE, "let '$(e.x)': annotation says $(pp_ty(e.ann)) but e1 has type $(pp_ty(t1))", e.pos))
        e.bound !== nothing && r1 > e.bound && throw(SIRError(E_BOUND, "let '$(e.x)': computed grade $r1 exceeds claimed bound @$(e.bound)", e.pos))
        if e.x == "_"
            is_linear(t1) && throw(SIRError(E_LEAK, "linear value of type $(pp_ty(t1)) discarded to _", e.pos))
        else
            c1 = bind!(ck, c1, e.x, t1, e.pos)
        end
        t2, r2, c2 = check(ck, c1, e.e2)
        return t2, MaxPlus.op_mul(r1, r2), c2
    end
    error("unreachable term $(e)")
end

"""
    check_program(e::Term)

Check a term from an empty context and return a `CheckResult` containing its type
and computed communication grade. Grade bounds on let bindings may equal or
exceed the computed grade; they do not replace it. Propagate checking `SIRError`s
and throw `SIRError(E_LEAK, ...)` for a linear result or remaining linear bindings.
This check does not execute the term or establish freedom from runtime deadlock.
"""
function check_program(e::Term)
    ck = Checker()
    t, r, out = check(ck, Ctx(), e)
    is_linear(t) && throw(SIRError(E_LEAK, "top-level result $(pp_ty(t)) is linear and is not consumed", e.pos))
    leaked = sort([n for (n, ty) in out if is_linear(ty)])
    isempty(leaked) || throw(SIRError(E_LEAK, "linear resources never consumed: " * join(["$n : $(pp_ty(out[n]))" for n in leaked], ", "), e.pos))
    CheckResult(t, r)
end
