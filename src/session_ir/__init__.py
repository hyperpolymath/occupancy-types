# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""occupancy-types Session IR: checker + stepper (ULTRAPLAN R0-B, Phase 1)."""

from .checker import check_program
from .machine import run_program
from .parser import parse
from .syntax import SIRError, MaxPlus, pp_ty

__all__ = ["parse", "check_program", "run_program", "SIRError", "MaxPlus", "pp_ty"]
