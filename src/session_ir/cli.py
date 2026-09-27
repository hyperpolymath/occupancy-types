# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""CLI for the Session IR checker/stepper.

    python3 -m session_ir check FILE        type-check; print A|r or error
    python3 -m session_ir run FILE          check, then step; assert steps <= r
    python3 -m session_ir test MANIFEST     run every example in a manifest

Exit codes: 0 ok, 1 failure (type error, unsound bound, example mismatch),
2 usage error.
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Optional

from .checker import check_program
from .machine import run_program
from .syntax import SIRError, pp_ty
from .parser import parse


def cmd_check(path: str) -> int:
    try:
        with open(path, encoding="utf-8") as f:
            src = f.read()
        e = parse(src)
        res = check_program(e)
    except SIRError as err:
        print(f"ERR {err.code}: {err.msg}" + (f" (at {err.pos[0]}:{err.pos[1]})" if err.pos else ""))
        return 1
    print(f"OK {pp_ty(res.ty)} | {res.grade}")
    return 0


def cmd_run(path: str, trace: bool = False) -> int:
    try:
        with open(path, encoding="utf-8") as f:
            src = f.read()
        e = parse(src)
        res = check_program(e)
        stats = run_program(e)
    except SIRError as err:
        print(f"ERR {err.code}: {err.msg}" + (f" (at {err.pos[0]}:{err.pos[1]})" if err.pos else ""))
        return 1
    ok = stats.comm_steps <= res.grade
    verdict = "steps <= grade OK" if ok else "R_UNSOUND: steps exceeded grade"
    print(f"OK {pp_ty(res.ty)} | grade={res.grade} steps={stats.comm_steps} "
          f"peak_live={stats.peak_live} peak_inflight={stats.peak_inflight} "
          f"certified/measured={res.grade / stats.comm_steps if stats.comm_steps else 0:.2f} "
          f"— {verdict}")
    if trace:
        for line in stats.trace:
            print(f"  | {line}")
    return 0 if ok else 1


def cmd_test(manifest_path: str) -> int:
    with open(manifest_path, encoding="utf-8") as f:
        manifest = json.load(f)
    base = manifest_path.rsplit("/", 1)[0] if "/" in manifest_path else "."
    rows: List[str] = []
    failures = 0
    for case in manifest["examples"]:
        rel = case["file"]
        path = f"{base}/{rel}"
        expect = case["expect"]
        got_label = ""
        verdict = ""
        try:
            with open(path, encoding="utf-8") as f:
                src = f.read()
            e = parse(src)
            res = check_program(e)
            if expect == "reject":
                got_label = f"accepted ({pp_ty(res.ty)} | {res.grade})"
                verdict = "FAIL (expected reject)"
                failures += 1
            else:
                want_ty = case.get("type")
                want_grade = case.get("grade")
                problems = []
                if want_ty is not None and pp_ty(res.ty) != want_ty:
                    problems.append(f"type {pp_ty(res.ty)} != {want_ty}")
                if want_grade is not None and res.grade != want_grade:
                    problems.append(f"grade {res.grade} != {want_grade}")
                got_label = f"{pp_ty(res.ty)} | {res.grade}"
                if problems:
                    verdict = "FAIL (" + "; ".join(problems) + ")"
                    failures += 1
                else:
                    stats = run_program(e)
                    if stats.comm_steps > res.grade:
                        verdict = f"FAIL (R_UNSOUND steps={stats.comm_steps} > {res.grade})"
                        failures += 1
                    elif "steps" in case and stats.comm_steps != case["steps"]:
                        verdict = f"FAIL (steps {stats.comm_steps} != {case['steps']})"
                        failures += 1
                    elif "peak_live" in case and stats.peak_live != case["peak_live"]:
                        verdict = f"FAIL (peak_live {stats.peak_live} != {case['peak_live']})"
                        failures += 1
                    else:
                        verdict = (f"PASS steps={stats.comm_steps}<=r "
                                   f"peak_live={stats.peak_live}")
        except SIRError as err:
            if expect == "reject":
                want = case.get("error")
                if want is not None and err.code != want:
                    got_label = err.code
                    verdict = f"FAIL (wrong error: {err.code}, want {want})"
                    failures += 1
                else:
                    got_label = err.code
                    verdict = "PASS (rejected)"
            else:
                got_label = err.code
                verdict = f"FAIL (unexpected {err.code})"
                failures += 1
        rows.append(f"  {rel:<34} {expect:<7} -> {got_label:<28} {verdict}")

    print(f"{'file':<36} {'expect':<7}   {'got':<28} verdict")
    for r in rows:
        print(r)
    total = len(manifest["examples"])
    print(f"{total - failures}/{total} examples OK")
    return 1 if failures else 0


def main(argv: Optional[List[str]] = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if len(args) == 2 and args[0] == "check":
        return cmd_check(args[1])
    if len(args) in (2, 3) and args[0] == "run":
        return cmd_run(args[1], trace=(len(args) == 3 and args[2] == "--trace"))
    if len(args) == 2 and args[0] == "test":
        return cmd_test(args[1])
    print("usage: python3 -m session_ir {check FILE | run FILE [--trace] | "
          "test MANIFEST}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
