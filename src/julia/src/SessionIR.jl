# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
# Session IR v0: parser, linear/session checker with max-plus grades, and
# the operational stepper.  Port of the Python package of the same name
# (occupancy-types, 2026-10-12); no dependencies beyond Base.
module SessionIR
include("Syntax.jl")
include("Parser.jl")
include("Checker.jl")
include("Machine.jl")
include("CLI.jl")
export parse_sir, check_program, run_program, pp_ty, SIRError, main
end
