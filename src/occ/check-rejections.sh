#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# check-rejections.sh — expected-rejection controls for the Occ spike.
#
# Each Reject*.idr beside this script MUST FAIL `idris2 --check`.  A control
# that starts typechecking is a red flag (the discipline softened) and fails
# this script.  Exit codes:
#   0  every control rejected (and Demo.idr / Occ.idr compile — the accepts)
#   1  a control was accepted, or an accept module failed to compile
#   2  idris2 not on PATH (fixture request; NEVER a silent skip)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v idris2 >/dev/null 2>&1; then
  cat >&2 <<'EOF'
FAIL (fixture request): idris2 not on PATH — the Occ spike is UNVERIFIED here.
Unblock with:
  install Idris 2 (>= 0.7.0), e.g. via pack, or build from
  https://github.com/idris-lang/Idris2/releases
then re-run:  bash src/occ/check-rejections.sh
EOF
  exit 2
fi

echo "=== Occ spike: accept modules (must compile) ==="
fail=0
for mod in Occ.idr Demo.idr; do
  printf '  %-24s ' "$mod"
  out="$(idris2 --check "$mod" 2>&1)" && ! grep -q '^Error:' <<<"$out" || {
    echo "FAIL (does not compile)"; echo "$out" | head -20; fail=1; continue; }
  echo "PASS"
done

echo "=== Occ spike: expected-rejection controls (must NOT compile) ==="
for mod in Reject*.idr; do
  printf '  %-24s ' "$mod"
  if out="$(idris2 --check "$mod" 2>&1)" && ! grep -q '^Error:' <<<"$out"; then
    echo "FAIL (control was ACCEPTED — the discipline softened)"
    fail=1
  else
    echo "PASS (rejected)"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "check-rejections: FAIL" >&2
  exit 1
fi
echo "check-rejections: OK — accepts compile, all controls rejected"
