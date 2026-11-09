#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Core proofs plus expected rejections.  Pattern: residual-evidence-types.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
export LC_ALL="${LC_ALL:-C.UTF-8}"
prover="${AGDA:-agda}"
"$prover" --version
ra="${RESOURCE_ALGEBRA_SRC:-_build/dependencies/resource-algebra/src}"
if [ -z "${RESOURCE_ALGEBRA_SRC:-}" ]; then
  bash scripts/fetch-siblings.sh
fi
test -d "$ra" || { echo "ERROR: resource-algebra sources not found at $ra" >&2; exit 1; }
flags=(--safe --without-K --cubical-compatible --no-libraries --ignore-interfaces --double-check -i src -i "$ra")
# PROOF-POLICY §8.4.6: a comment-aware postulate scan of the import cone
# (src/ and the pinned resource-algebra sources), alongside --safe.
# scripts/scan-postulates.pl reads each file in source order (nested block
# comments, line comments, strings) and fails on a file it cannot read.
# find runs to a file, not a process substitution, so its own failure (a
# directory it cannot read) stops the gate instead of leaving a partial cone.
cone_list="$(mktemp)"
trap 'rm -f "$cone_list"' EXIT
find src "$ra" -name '*.agda' -print0 > "$cone_list" \
  || { echo "ERROR: could not list the import cone (src/, $ra)" >&2; exit 1; }
mapfile -d '' cone < "$cone_list"
(( ${#cone[@]} > 0 )) || { echo "ERROR: no Agda sources in the import cone" >&2; exit 1; }
if ! perl scripts/scan-postulates.pl "${cone[@]}"; then
  echo "ERROR: postulate in the import cone (src/, $ra), or an unreadable file" >&2
  exit 1
fi
echo "PASS: no postulate in the import cone (src/, resource-algebra)"
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
