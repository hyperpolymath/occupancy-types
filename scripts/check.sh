#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# check.sh — the occupancy-types gate: ULTRAPLAN §5
#   just check = proofs + tests + expected-rejection controls + checker on fixtures
#
# A missing toolchain is a FAIL with a fixture request, never a silent skip
# (estate doctrine: a gate that cannot run must not report OK).  The
# --runnable-only flag runs just the stages this environment can execute and
# reports the rest as BLOCKED; its scope is printed and its exit code reflects
# only the stages it ran.
#
# Stages:
#   1  session-ir examples (accept/reject/expected bounds) + steps <= grade
#   2  Phase 0 kill-test audit (four sentences; banned word absent)
#   3  repo shape gates (root allowlist; no stray .md under docs/)
#   4  Idris Occ spike: accepts compile + 4 expected-rejection controls
#   5  stackcert: core axiom footprint + fixture + 4 negative controls

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
MODE="${1:-all}"
fail=0
blocked=0

note() { printf '%s\n' "$*"; }
ok()   { printf 'PASS: %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

note "=== 1. Session IR checker on fixtures ==="
if PYTHONPATH=src python3 -m session_ir test examples/session_ir/manifest.json; then
  ok "session-ir examples (accept + reject + expected bounds; steps <= grade)"
else
  bad "session-ir examples"
fi

note ""
note "=== 2. Phase 0 kill-test audit ==="
if python3 - <<'PY'
import re, sys
src = open('docs/OPERATIONAL-MODEL.md', encoding='utf-8').read()
m = re.search(r'<!-- KILL-TEST-BEGIN -->\n(.*?)<!-- KILL-TEST-END -->', src, re.S)
if not m:
    sys.exit('KILL-TEST block missing from docs/OPERATIONAL-MODEL.md')
block = m.group(1).strip()
if 'tropical' in block.lower():
    sys.exit('banned word present in kill-test block')
lines = [l for l in block.splitlines() if l.strip()]
if not (len(lines) == 4 and all(l.rstrip().endswith('.') for l in lines)):
    sys.exit(f'kill-test must be exactly 4 sentences, found {len(lines)}')
print('kill-test: 4 sentences, banned word absent')
PY
then ok "kill-test audit"; else bad "kill-test audit"; fi

note ""
note "=== 3. Repo shape gates ==="
if bash scripts/check-root-shape.sh . >/dev/null && bash scripts/check-no-md-in-docs.sh . >/dev/null; then
  ok "root allowlist + docs .md policy"
else
  bad "repo shape gates (run scripts/check-root-shape.sh / check-no-md-in-docs.sh)"
fi

note ""
note "=== 4. Idris Occ spike (accepts + expected-rejection controls) ==="
if command -v idris2 >/dev/null 2>&1; then
  if bash src/occ/check-rejections.sh; then
    ok "Occ spike"
  else
    bad "Occ spike"
  fi
else
  if [ "$MODE" = "--runnable-only" ]; then
    note "BLOCKED: idris2 not on PATH (fixture request in src/occ/README.adoc)"
    blocked=1
  else
    bad "idris2 not on PATH — Occ spike cannot be checked (fixture request: src/occ/README.adoc)"
  fi
fi

note ""
note "=== 5. stackcert (core + fixture + negative controls) ==="
if command -v lean >/dev/null 2>&1 && command -v lake >/dev/null 2>&1; then
  if bash tests/run_stackcert.sh; then
    ok "stackcert"
  else
    bad "stackcert"
  fi
else
  if [ "$MODE" = "--runnable-only" ]; then
    note "BLOCKED: lean/lake not on PATH (fixture request in src/stackcert/README.adoc)"
    blocked=1
  else
    bad "lean/lake not on PATH — stackcert cannot be checked (fixture request: src/stackcert/README.adoc)"
  fi
fi

note ""
if [ "$fail" -ne 0 ]; then
  note "check: FAIL"
  exit 1
fi
if [ "$blocked" -ne 0 ]; then
  note "check (--runnable-only): OK for the stages that ran; PROOFS BLOCKED (see above)"
  exit 0
fi
note "check: OK — proofs + tests + expected-rejection controls + fixtures"
