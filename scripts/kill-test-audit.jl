# SPDX-License-Identifier: MPL-2.0
# Phase 0 kill-test audit (was an inline Python block in scripts/check.sh).
src = read("docs/OPERATIONAL-MODEL.md", String)
m = match(r"<!-- KILL-TEST-BEGIN -->\n(.*?)<!-- KILL-TEST-END -->"s, src)
m === nothing && (println(stderr, "KILL-TEST block missing from docs/OPERATIONAL-MODEL.md"); exit(1))
block = strip(m.captures[1])
occursin("tropical", lowercase(block)) && (println(stderr, "banned word present in kill-test block"); exit(1))
lines = [l for l in split(block, '\n') if !isempty(strip(l))]
(length(lines) == 4 && all(endswith(rstrip(l), '.') for l in lines)) || (println(stderr, "kill-test must be exactly 4 sentences, found $(length(lines))"); exit(1))
println("kill-test: 4 sentences, banned word absent")
