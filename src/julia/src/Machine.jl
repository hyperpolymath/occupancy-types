# SPDX-License-Identifier: MPL-2.0
# Operational stepper with operational statistics (comm steps, peak live
# bytes, peak in-flight events).  Port of machine.py.

mutable struct BufVal; bid::Int; size::Int; dropped::Bool end
Base.show(io::IO, b::BufVal) = print(io, "<buf#", b.bid, ":", b.size, ">")
mutable struct Chan
    cid::Int
    queues::Dict{String,Vector{Tuple{String,Any}}}
    closed::Dict{String,Bool}
end
Chan(cid) = Chan(cid, Dict("a" => Tuple{String,Any}[], "b" => Tuple{String,Any}[]), Dict("a" => false, "b" => false))
other(side::String) = side == "a" ? "b" : "a"
struct EpVal; chan::Chan; side::String end
Base.show(io::IO, e::EpVal) = print(io, "<ep ", e.chan.cid, ".", e.side, ">")
struct PairVal; v1::Any; v2::Any end

mutable struct RunStats
    comm_steps::Int; peak_live::Int; peak_inflight::Int; live_bytes::Int; trace::Vector{String}
end
RunStats() = RunStats(0, 0, 0, 0, String[])
note!(st::RunStats, msg) = push!(st.trace, msg)

mutable struct Machine
    stats::RunStats; next_bid::Int; next_cid::Int; chans::Vector{Chan}
end
Machine() = Machine(RunStats(), 0, 0, Chan[])
"""Count queued message and selection events across all channels, or zero if none exist."""
inflight(m::Machine) = sum((length(q) for c in m.chans for q in values(c.queues)); init=0)
touch_inflight!(m::Machine) = (m.stats.peak_inflight = max(m.stats.peak_inflight, inflight(m)))
function getep(env, name, pos)
    v = get(env, name, nothing)
    v isa EpVal || throw(SIRError(R_INTERNAL, "'$name' is not an endpoint at runtime", pos))
    v
end
"""
Evaluate `e` from an empty environment, retaining and updating `m`'s existing
channels and statistics, and return the value. Propagate evaluation errors and
throw `SIRError(R_CLOSE_PENDING, ...)` if any channel events remain afterwards.
No type check or state rollback is performed.
"""
function run!(m::Machine, e::Term)
    v = eval_term(m, e, Dict{String,Any}())
    pending = inflight(m)
    pending > 0 && throw(SIRError(R_CLOSE_PENDING, "$pending channel event(s) still queued at end of program", e.pos))
    v
end
"""
Evaluate a term in `env`, returning its value and updating machine statistics,
channels and referenced buffers. Unit-valued operations return `nothing`.
Throw `SIRError` for an empty receive/case queue (`R_DEADLOCK`), closing with queued
events (`R_CLOSE_PENDING`), or invalid runtime values/protocol events (`R_INTERNAL`).
An unbound variable raises `KeyError`. Errors retain any mutations already made;
callers are expected to type-check the term first.
"""
function eval_term(m::Machine, e::Term, env::Dict{String,Any})
    st = m.stats
    if e isa Var; return env[e.name]
    elseif e isa UnitLit; return nothing
    elseif e isa Alloc
        b = BufVal(m.next_bid, e.n, false); m.next_bid += 1
        st.live_bytes += e.n; st.peak_live = max(st.peak_live, st.live_bytes)
        note!(st, "alloc $(e.n) -> $b (live=$(st.live_bytes))"); return b
    elseif e isa Drop
        v = eval_term(m, e.e, env)
        v isa BufVal || throw(SIRError(R_INTERNAL, "drop of a non-buffer at runtime", e.pos))
        v.dropped && throw(SIRError(R_INTERNAL, "double free at runtime", e.pos))
        v.dropped = true; st.live_bytes -= v.size
        note!(st, "drop $v (live=$(st.live_bytes))"); return nothing
    elseif e isa Pair; return PairVal(eval_term(m, e.e1, env), eval_term(m, e.e2, env))
    elseif e isa LetPair
        v = eval_term(m, e.e1, env)
        v isa PairVal || throw(SIRError(R_INTERNAL, "letpair of a non-pair", e.pos))
        env2 = copy(env); env2[e.x] = v.v1; env2[e.y] = v.v2
        return eval_term(m, e.e2, env2)
    elseif e isa New
        c = Chan(m.next_cid); m.next_cid += 1; push!(m.chans, c)
        note!(st, "new channel $(c.cid) ($(pp_ty(SessT(e.s))) | dual)")
        return PairVal(EpVal(c, "a"), EpVal(c, "b"))
    elseif e isa SendT
        ep = getep(env, e.ep, e.pos); v = eval_term(m, e.val, env)
        push!(ep.chan.queues[other(ep.side)], ("msg", v))
        st.comm_steps += 1; touch_inflight!(m); note!(st, "send $ep (step $(st.comm_steps))"); return nothing
    elseif e isa RecvT
        ep = getep(env, e.ep, e.pos); q = ep.chan.queues[ep.side]
        isempty(q) && throw(SIRError(R_DEADLOCK, "recv on '$(e.ep)' with nothing in flight", e.pos))
        kind, v = popfirst!(q)
        kind == "msg" || throw(SIRError(R_INTERNAL, "recv found a selection, not a message", e.pos))
        st.comm_steps += 1; touch_inflight!(m); note!(st, "recv $ep (step $(st.comm_steps))"); return v
    elseif e isa Select
        ep = getep(env, e.ep, e.pos)
        push!(ep.chan.queues[other(ep.side)], ("sel", e.label))
        st.comm_steps += 1; touch_inflight!(m); note!(st, "select '$(e.label)' on $ep (step $(st.comm_steps))"); return nothing
    elseif e isa Case
        ep = getep(env, e.ep, e.pos); q = ep.chan.queues[ep.side]
        isempty(q) && throw(SIRError(R_DEADLOCK, "case on '$(e.ep)' with nothing in flight", e.pos))
        kind, lab = popfirst!(q)
        kind == "sel" || throw(SIRError(R_INTERNAL, "case found a message, not a selection", e.pos))
        st.comm_steps += 1; touch_inflight!(m); note!(st, "case $ep -> '$lab' (step $(st.comm_steps))")
        for (blab, x, body) in e.branches
            if blab == lab; env2 = copy(env); env2[x] = ep; return eval_term(m, body, env2) end
        end
        throw(SIRError(R_INTERNAL, "selected label '$lab' has no branch", e.pos))
    elseif e isa Close
        ep = getep(env, e.ep, e.pos)
        ep.chan.closed[ep.side] && throw(SIRError(R_INTERNAL, "endpoint closed twice at runtime", e.pos))
        isempty(ep.chan.queues[ep.side]) || throw(SIRError(R_CLOSE_PENDING, "close '$(e.ep)' with unconsumed messages", e.pos))
        ep.chan.closed[ep.side] = true; note!(st, "close $ep"); return nothing
    elseif e isa Let
        v = eval_term(m, e.e1, env)
        if e.x != "_"; env = copy(env); env[e.x] = v end
        return eval_term(m, e.e2, env)
    end
    error("unreachable term $(e)")
end
"""
    run_program(e::Term)

Execute a term on a fresh machine and return its `RunStats`, discarding the value.
`comm_steps` counts sends, receives, selections and cases; `peak_live` and
`live_bytes` measure simulated buffer bytes; `peak_inflight` counts queued message
and selection events. `trace` contains the execution trace.

Call `check_program` first when static validation is required: this function does
not type-check or compare measured steps with a grade. Evaluation errors propagate,
including `SIRError` for deadlock, pending events or invalid runtime operations,
and `KeyError` for an unbound variable.
"""
function run_program(e::Term)
    m = Machine(); run!(m, e); m.stats
end
