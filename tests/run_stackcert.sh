#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# run_stackcert.sh — stackcert verification harness.
#
# Stages (each must pass; nothing silently skips):
#   1. core:   lean StackcertCore.lean  — compiles, #print axioms clean
#              (no Classical.choice, no sorryAx)
#   2. build:  lake build
#   3. positive fixture: probe.* + annotations.toml + cert.toml -> exit 0
#   4. negative controls (each must be rejected, exit 1):
#        cert-decremented.toml        decremented bound
#        annotations-no-recursion     undeclared self-recursion
#        annotations-no-indirect      unresolved indirect call
#        cycle.*                      undeclared (non-self) cycle
#
# Exit: 0 all green; 1 failure; 2 toolchain absent (fixture request, never a
# silent skip).

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../src/stackcert"

if ! command -v lean >/dev/null 2>&1 || ! command -v lake >/dev/null 2>&1; then
  cat >&2 <<'EOF'
FAIL (fixture request): lean/lake not on PATH — stackcert is UNVERIFIED here.
Unblock with:
  curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y
  elan default leanprover/lean4:v4.15.0
then re-run:  bash tests/run_stackcert.sh
EOF
  exit 2
fi

echo "=== 1. core compile + axiom footprint ==="
lean_out="$(lean StackcertCore.lean 2>&1)" || { echo "FAIL: core does not compile"; echo "$lean_out"; exit 1; }
echo "$lean_out" | grep -q "cert_sound" || { echo "FAIL: no #print axioms output for cert_sound"; echo "$lean_out"; exit 1; }
if echo "$lean_out" | grep -E "Classical\.choice|sorryAx|propext" ; then
  echo "FAIL: axiom footprint not clean (must be [] for cert_sound)"; exit 1
fi
echo "PASS (axiom footprint clean)"
echo "$lean_out" | tail -3

echo "=== 2. lake build ==="
lake build >/dev/null || { echo "FAIL: lake build"; exit 1; }
echo "PASS"

echo "=== 3. positive fixture (must be accepted) ==="
run() { lake exe stackcert --ci "$1" --su "$2" --ann "$3" --cert "$4"; }
if out="$(run fixtures/probe.ci fixtures/probe.su fixtures/annotations.toml fixtures/cert.toml)"; then
  echo "PASS: $out"
else
  echo "FAIL: positive fixture rejected: $out"; exit 1
fi

echo "=== 4. negative controls (must be rejected) ==="
fail=0
neg() { # name, then the 4 paths; expects exit 1
  local name="$1"; shift
  printf '  %-28s ' "$name"
  if out="$(run "$@" 2>&1)"; then
    echo "FAIL (accepted!)"; fail=1
  else
    echo "PASS (rejected: $(echo "$out" | head -1))"
  fi
}
neg "cert-decremented"      fixtures/probe.ci fixtures/probe.su fixtures/annotations.toml fixtures/cert-decremented.toml
neg "undeclared-recursion"  fixtures/probe.ci fixtures/probe.su fixtures/annotations-no-recursion.toml fixtures/cert.toml
neg "unresolved-indirect"   fixtures/probe.ci fixtures/probe.su fixtures/annotations-no-indirect.toml fixtures/cert.toml
neg "undeclared-cycle"      fixtures/cycle.ci fixtures/cycle.su fixtures/cycle-annotations.toml fixtures/cycle-cert.toml

[ "$fail" -eq 0 ] || { echo "run_stackcert: FAIL" >&2; exit 1; }
echo "run_stackcert: OK — core verified, fixture accepted, all controls rejected"
