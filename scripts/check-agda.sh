#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Core proofs plus expected rejections.  Pattern: residual-evidence-types.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
export LC_ALL="${LC_ALL:-C.UTF-8}"
prover="${AGDA:-agda}"
"$prover" --version
ra="${RESOURCE_ALGEBRA_SRC:-_build/dependencies/resource-algebra/src}"
test -d "$ra" || { echo "ERROR: resource-algebra sources not found at $ra" >&2; exit 1; }
flags=(--safe --without-K --no-libraries --ignore-interfaces --double-check -i src -i "$ra")
"$prover" "${flags[@]}" src/OccupancyTypes/All.agda
mkdir -p _build/check-logs
shopt -s nullglob
rejects=(tests/reject/*.agda)
shopt -u nullglob
if (( ${#rejects[@]} == 0 )); then
  echo 'ERROR: no expected-rejection modules found under tests/reject' >&2
  exit 1
fi
for file in "${rejects[@]}"; do
  name="$(basename -- "$file" .agda)"
  log="_build/check-logs/$name.log"
  if "$prover" "${flags[@]}" -i tests/reject "$file" >"$log" 2>&1; then
    cat "$log"
    echo "ERROR: invalid proof accepted: $name" >&2
    exit 1
  fi
  if ! grep -Eq "/$name\.agda:[0-9]+,[0-9]+" "$log" ||
     ! grep -q 'when checking that' "$log" ||
     grep -Eq 'Not in scope|Failed to find|Unsolved|Parse error' "$log"; then
    cat "$log"
    echo "ERROR: unexpected failure while checking $name" >&2
    exit 1
  fi
  echo "PASS: rejected $name at its invalid declaration"
done
echo "PASS: core proofs and all ${#rejects[@]} expected rejections"
