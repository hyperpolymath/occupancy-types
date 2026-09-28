/-
SPDX-License-Identifier: MPL-2.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)

Main — lake exe stackcert --ci F.ci --su F.su --ann annotations.toml --cert cert.toml
→ exit 0 (certificate accepted) / 1 (rejected) / 2 (usage).

Pipeline: parse inputs (UNVERIFIED layer) → build CallGraph → run
StackcertCore.check (verified layer) → report.  CLI-level rejections before
the core runs: unresolved indirect calls, alloca/VLA-style dynamic frames
without a [dynamic] bound, call edges into longjmp-family functions, and
non-self cycles without annotation.  See README.adoc for the fixture request
and ground-truth protocol; this exe's outputs are NOT yet a measurement.
-/

import StackcertCore
import Parsers

open StackcertCore StackcertParsers

def lookupNat (l : List (String × Nat)) (k : String) : Option Nat :=
  match l with
  | [] => none
  | (k', v) :: rest => if k == k' then some v else lookupNat rest k

def lookupStrs (l : List (String × List String)) (k : String) : Option (List String) :=
  match l with
  | [] => none
  | (k', v) :: rest => if k == k' then some v else lookupStrs rest k

def dedup (l : List String) : List String :=
  l.foldl (fun acc x => if acc.any (fun y => y == x) then acc else acc ++ [x]) []

def isForbiddenTarget (t : String) : Bool :=
  t == "alloca" || t == "__builtin_alloca" || t == "longjmp"
  || t == "_longjmp" || t == "__longjmp" || t == "__longjmp_chk"
  || t == "_setjmp" || t == "__sigsetjmp"

/-- Non-self cycle detection (CLI-level; `partial` is fine outside the proof). -/
partial def reaches (callees : List (String × List String)) (start fuel : Nat)
    (cur tgt : String) : Bool :=
  if fuel = 0 then false
  else
    match lookupStrs callees cur with
    | none => false
    | some ds =>
      ds.any (fun d =>
        if d == tgt then true
        else if d == cur then false
        else reaches callees start (fuel - 1) d tgt)

partial def hasNonSelfCycle (names : List String)
    (callees : List (String × List String)) : Option (String × String) :=
  match names with
  | [] => none
  | v :: rest =>
    match lookupStrs callees v with
    | none => hasNonSelfCycle rest callees
    | some ds =>
      match ds.find? (fun u => u != v && reaches callees (names.length + 1) (names.length + 1) v u) with
      | some u => some (v, u)
      | none => hasNonSelfCycle rest callees

def usage : String :=
  "usage: stackcert --ci FILE.ci --su FILE.su --ann annotations.toml --cert cert.toml"

def getFlag (args : List String) (flag : String) : Option String :=
  match args with
  | [] => none
  | a :: rest => if a == flag then rest.headD "" else getFlag rest flag

def main (args : List String) : IO UInt32 := do
  let ciP := getFlag args "--ci"
  let suP := getFlag args "--su"
  let annP := getFlag args "--ann"
  let certP := getFlag args "--cert"
  match ciP, suP, annP, certP with
  | some ciF, some suF, some annF, some certF => do
    let ciText ← IO.FS.readFile ciF
    let suText ← IO.FS.readFile suF
    let annText ← IO.FS.readFile annF
    let certText ← IO.FS.readFile certF
    match parseCI ciText, parseSU suText, parseToml annText, parseToml certText with
    | .error e, _, _, _ => IO.println s!"ERR E_PARSE: {e}"; return 1
    | _, .error e, _, _ => IO.println s!"ERR E_PARSE: {e}"; return 1
    | _, _, .error e, _ => IO.println s!"ERR E_PARSE: {e}"; return 1
    | _, _, _, .error e => IO.println s!"ERR E_PARSE: {e}"; return 1
    | .ok ciItems, .ok suEntries, .ok annRows, .ok certRows => do
      match annOfToml annRows, certOfToml certRows with
      | .error e, _ => IO.println s!"ERR E_PARSE: {e}"; return 1
      | _, .error e => IO.println s!"ERR E_PARSE: {e}"; return 1
      | .ok ann, .ok certList => do
        let suNames := suEntries.map (·.name)
        let nodeNames := ciItems.filterMap (fun i =>
          match i with
          | CiItem.node t =>
            let n := normName t
            if n == "__indirect_call" then none  -- placeholder node, not a function
            else some n
          | _ => none)
        let names := dedup (suNames ++ nodeNames)
        -- frames from .su
        let frames := suEntries.map (fun e => (e.name, e.bytes))
        -- callees from .ci edges (normalized); indirect handled below
        let mut callees : List (String × List String) := names.map (fun n => (n, []))
        let mut indirectUsers : List String := []
        let mut badTarget : Option String := none
        for item in ciItems do
          match item with
          | CiItem.edge s t =>
            let s' := normName s
            let t' := normName t
            if isForbiddenTarget t' then badTarget := some t'
            else
              callees := callees.map (fun (k, ds) =>
                if k == s' then (k, if ds.any (fun x => x == t') then ds else ds ++ [t'])
                else (k, ds))
          | CiItem.indirectEdge s => indirectUsers := indirectUsers ++ [normName s]
          | CiItem.node _ => pure ()
        match badTarget with
        | some t =>
          IO.println s!"ERR E_FORBIDDEN: call to {t} (alloca/VLA/longjmp are rejected)"
          return 1
        | none => pure ()
        -- resolve indirect calls via [indirect]
        for f in indirectUsers do
          match lookupStrs ann.indirect f with
          | none =>
            IO.println s!"ERR E_INDIRECT: unresolved indirect call in {f}"
            return 1
          | some ts =>
            for t in ts do
              if !(names.any (fun n => n == t)) then
                IO.println s!"ERR E_INDIRECT: target {t} of {f} is not a known function"
                return 1
              callees := callees.map (fun (k, ds) =>
                if k == f then (k, if ds.any (fun x => x == t) then ds else ds ++ [t])
                else (k, ds))
        -- dynamic frames need a [dynamic] bound
        for e in suEntries do
          match e.qual with
          | Qual.static => pure ()
          | _ =>
            match lookupNat ann.dynamic e.name with
            | none =>
              IO.println s!"ERR E_DYNAMIC: {e.name} has a dynamic/bounded frame without [dynamic] annotation"
              return 1
            | some _ => pure ()
        -- non-self cycles rejected
        match hasNonSelfCycle names callees with
        | some (v, u) =>
          IO.println s!"ERR E_CYCLE: undeclared cycle {v} -> ... -> {u}"
          return 1
        | none => pure ()
        -- certificates must cover every function
        for n in names do
          if (lookupNat certList n).isNone then
            IO.println s!"ERR E_CERT: no [cert] entry for {n}"
            return 1
        -- build the core model and check
        let g : CallGraph String := {
          fns := names
          frame := fun fn => (lookupNat frames fn).getD 0
          callees := fun fn => (lookupStrs callees fn).getD []
        }
        let a : Annot String := {
          selfDepth := fun fn => lookupNat ann.selfDepth fn
        }
        let cert := fun fn : String => (lookupNat certList fn).getD 0
        if check g a cert then
          IO.println s!"OK certificate accepted for {names.length} function(s)"
          return 0
        else
          IO.println "ERR E_CERT: certificate rejected by rule (see StackcertCore.rule)"
          return 1
  | _, _, _, _ =>
    IO.println usage
    return 2
