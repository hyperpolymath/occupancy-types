#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Fetch the compared sibling at its pinned commit (pattern: residual-evidence-types).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
RESOURCE_ALGEBRA_COMMIT="${RESOURCE_ALGEBRA_COMMIT:-0b338c9fc45cd04e7ee7d00b3855cd59d56a2afe}"
mkdir -p _build/dependencies
if [ ! -d _build/dependencies/resource-algebra ]; then
  git clone --quiet https://github.com/hyperpolymath/resource-algebra.git _build/dependencies/resource-algebra
fi
git -C _build/dependencies/resource-algebra fetch --quiet origin
git -C _build/dependencies/resource-algebra checkout --quiet "$RESOURCE_ALGEBRA_COMMIT"
echo "resource-algebra at $(git -C _build/dependencies/resource-algebra rev-parse --short HEAD)"
