# SPDX-License-Identifier: MPL-2.0
# The manifest suite is the test: every pinned fixture must reproduce its
# judgment, grade, steps, peak live bytes or exact error code.
using Test, SessionIR
root = normpath(joinpath(@__DIR__, "..", "..", ".."))
@test SessionIR.main(["test", joinpath(root, "examples", "session_ir", "manifest.json")]) == 0
