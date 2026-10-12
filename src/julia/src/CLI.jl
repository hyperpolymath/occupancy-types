# SPDX-License-Identifier: MPL-2.0
# check FILE | run FILE [--trace] | test MANIFEST.  Port of cli.py.  The
# manifest is read with a minimal JSON reader so the package has no
# dependencies beyond the standard library.

fmt2(x) = (s = string(round(x; digits=2)); occursin('.', s) ? (length(split(s, '.')[2]) == 1 ? s * "0" : s) : s * ".00")

errline(err::SIRError) = "ERR $(err.code): $(err.msg)" * (err.pos === nothing ? "" : " (at $(err.pos[1]):$(err.pos[2]))")

function cmd_check(path::String)
    try
        res = check_program(parse_sir(read(path, String)))
        println("OK $(pp_ty(res.ty)) | $(res.grade)"); return 0
    catch err
        err isa SIRError || rethrow(); println(errline(err)); return 1
    end
end

function cmd_run(path::String; trace::Bool=false)
    res = nothing; stats = nothing
    try
        e = parse_sir(read(path, String)); res = check_program(e); stats = run_program(e)
    catch err
        err isa SIRError || rethrow(); println(errline(err)); return 1
    end
    ok = stats.comm_steps <= res.grade
    verdict = ok ? "steps <= grade OK" : "R_UNSOUND: steps exceeded grade"
    ratio = stats.comm_steps == 0 ? 0.0 : res.grade / stats.comm_steps
    println("OK $(pp_ty(res.ty)) | grade=$(res.grade) steps=$(stats.comm_steps) peak_live=$(stats.peak_live) peak_inflight=$(stats.peak_inflight) certified/measured=$(fmt2(ratio)) — $verdict")
    trace && foreach(l -> println("  | $l"), stats.trace)
    return ok ? 0 : 1
end

# Minimal JSON for the manifest: objects, arrays, strings, integers, true/false/null.
function json_parse(s::AbstractString)
    cs = collect(s); i = Ref(1)
    ws!() = (while i[] <= length(cs) && isspace(cs[i[]]); i[] += 1 end)
    function val()
        ws!(); c = cs[i[]]
        if c == '{'
            i[] += 1; d = Dict{String,Any}(); ws!()
            if cs[i[]] == '}'; i[] += 1; return d end
            while true
                ws!(); k = val(); ws!(); cs[i[]] == ':' || error("json: expected ':'"); i[] += 1
                d[k] = val(); ws!()
                if cs[i[]] == ','; i[] += 1; continue end
                cs[i[]] == '}' || error("json: expected '}'"); i[] += 1; return d
            end
        elseif c == '['
            i[] += 1; a = Any[]; ws!()
            if cs[i[]] == ']'; i[] += 1; return a end
            while true
                push!(a, val()); ws!()
                if cs[i[]] == ','; i[] += 1; continue end
                cs[i[]] == ']' || error("json: expected ']'"); i[] += 1; return a
            end
        elseif c == '"'
            i[] += 1; buf = IOBuffer()
            while cs[i[]] != '"'
                if cs[i[]] == '\\'; i[] += 1; e = cs[i[]]; write(buf, e == 'n' ? '\n' : e == 't' ? '\t' : e); i[] += 1
                else write(buf, cs[i[]]); i[] += 1 end
            end
            i[] += 1; return String(take!(buf))
        elseif c == 't'; i[] += 4; return true
        elseif c == 'f'; i[] += 5; return false
        elseif c == 'n'; i[] += 4; return nothing
        else
            j = i[]; while j <= length(cs) && (isdigit(cs[j]) || cs[j] == '-'); j += 1 end
            n = parse(Int, String(cs[i[]:j-1])); i[] = j; return n
        end
    end
    val()
end

function cmd_test(manifest_path::String)
    manifest = json_parse(read(manifest_path, String))
    base = occursin("/", manifest_path) ? rsplit(manifest_path, "/"; limit=2)[1] : "."
    rows = String[]; failures = 0
    for case in manifest["examples"]
        rel = case["file"]; path = "$base/$rel"; expect = case["expect"]
        got = ""; verdict = ""
        try
            e = parse_sir(read(path, String)); res = check_program(e)
            if expect == "reject"
                got = "accepted ($(pp_ty(res.ty)) | $(res.grade))"; verdict = "FAIL (expected reject)"; failures += 1
            else
                problems = String[]
                haskey(case, "type") && pp_ty(res.ty) != case["type"] && push!(problems, "type $(pp_ty(res.ty)) != $(case["type"])")
                haskey(case, "grade") && res.grade != case["grade"] && push!(problems, "grade $(res.grade) != $(case["grade"])")
                got = "$(pp_ty(res.ty)) | $(res.grade)"
                if !isempty(problems)
                    verdict = "FAIL (" * join(problems, "; ") * ")"; failures += 1
                else
                    stats = run_program(e)
                    if stats.comm_steps > res.grade
                        verdict = "FAIL (R_UNSOUND steps=$(stats.comm_steps) > $(res.grade))"; failures += 1
                    elseif haskey(case, "steps") && stats.comm_steps != case["steps"]
                        verdict = "FAIL (steps $(stats.comm_steps) != $(case["steps"]))"; failures += 1
                    elseif haskey(case, "peak_live") && stats.peak_live != case["peak_live"]
                        verdict = "FAIL (peak_live $(stats.peak_live) != $(case["peak_live"]))"; failures += 1
                    else
                        verdict = "PASS steps=$(stats.comm_steps)<=r peak_live=$(stats.peak_live)"
                    end
                end
            end
        catch err
            err isa SIRError || rethrow()
            if expect == "reject"
                want = get(case, "error", nothing)
                if want !== nothing && err.code != want
                    got = err.code; verdict = "FAIL (wrong error: $(err.code), want $want)"; failures += 1
                else
                    got = err.code; verdict = "PASS (rejected)"
                end
            else
                got = err.code; verdict = "FAIL (unexpected $(err.code))"; failures += 1
            end
        end
        push!(rows, "  " * rpad(rel, 34) * " " * rpad(expect, 7) * " -> " * rpad(got, 28) * " " * verdict)
    end
    println(rpad("file", 36) * " " * rpad("expect", 7) * "   " * rpad("got", 28) * " verdict")
    foreach(println, rows)
    total = length(manifest["examples"]); println("$(total - failures)/$total examples OK")
    return failures == 0 ? 0 : 1
end

function main(args::Vector{String}=ARGS)
    if length(args) == 2 && args[1] == "check"; return cmd_check(args[2]) end
    if length(args) in (2, 3) && args[1] == "run"; return cmd_run(args[2]; trace=(length(args) == 3 && args[3] == "--trace")) end
    if length(args) == 2 && args[1] == "test"; return cmd_test(args[2]) end
    println(stderr, "usage: julia --project=src/julia src/julia/bin/sessionir.jl {check FILE | run FILE [--trace] | test MANIFEST}"); return 2
end
