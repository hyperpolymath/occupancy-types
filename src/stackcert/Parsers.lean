/-
SPDX-License-Identifier: MPL-2.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)

Parsers — GCC `.su` / `.ci` (VCG from -fcallgraph-info=su) and the
annotations.toml subset.  UNVERIFIED I/O layer: not covered by cert_sound;
inputs are treated as untrusted text and every failure mode is an Except.
Formats were captured from real GCC output (see fixtures/).
-/

namespace StackcertParsers

/-- Frame quality from .su: `static`, `dynamic`, `dynamic,bounded`. -/
inductive Qual where
  | static
  | dynamic
  | dynamicBounded
  deriving Repr, BEq

structure SuEntry where
  name : String
  bytes : Nat
  qual : Qual
  deriving Repr

structure Ann where
  selfDepth : List (String × Nat)       -- [recursion]   fn = depth
  indirect  : List (String × List String) -- [indirect]  fn = ["target", ...]
  dynamic   : List (String × Nat)       -- [dynamic]     fn = explicit bytes
  isr       : List (String × Nat)       -- [isr]         fn = level
  threads   : List (String × Nat)       -- [threads]     fn = stack bytes
  deriving Repr

/-- Text after `needle`, up to the next double quote. -/
def extractAfter (needle : String) (line : String) : Option String :=
  match line.splitOn needle with
  | _ :: rest :: _ =>
    match rest.splitOn "\"" with
    | first :: _ => some first
    | _ => none
  | _ => none

def nameOfLoc (loc : String) : String :=
  match (loc.splitOn ":").reverse with
  | n :: _ => n
  | _ => loc

/-- Parse one .su line: `file:line:col:func\tbytes\tqualifiers`. -/
def parseSuLine (line : String) : Option SuEntry :=
  let fields := line.splitOn "\t"
  match fields with
  | loc :: bytesS :: qualS :: _ =>
    match bytesS.toNat? with
    | none => none
    | some bytes =>
      let q := qualS.trim
      let qual :=
        if q == "static" then some Qual.static
        else if q == "dynamic" then some Qual.dynamic
        else if q == "dynamic,bounded" then some Qual.dynamicBounded
        else none
      match qual with
      | some qq => some { name := nameOfLoc loc, bytes := bytes, qual := qq }
      | none => none
  | _ => none

/-- Parse a whole .su file (blank lines ignored). -/
def parseSU (text : String) : Except String (List SuEntry) :=
  let lines := (text.splitOn "\n").filter (fun l => l.trim ≠ "")
  let entries := lines.filterMap parseSuLine
  if entries.length = lines.length then .ok entries
  else .error "unparsed .su line(s)"

/-- One .ci graph item. -/
inductive CiItem where
  | node (title : String)
  | edge (src dst : String)
  | indirectEdge (src : String)
  deriving Repr

def parseCiLine (line : String) : Option CiItem :=
  if line.trim.startsWith "node:" then
    match extractAfter "title: \"" line with
    | some t => some (CiItem.node t)
    | none => none
  else if line.trim.startsWith "edge:" then
    match extractAfter "sourcename: \"" line, extractAfter "targetname: \"" line with
    | some s, some "__indirect_call" => some (CiItem.indirectEdge s)
    | some s, some t => some (CiItem.edge s t)
    | _, _ => none
  else none

/-- Parse a whole .ci file.  Titles are node identities; a node title of the
form `file.c:fn` is normalized to `fn` (GCC qualifies statics). -/
def parseCI (text : String) : Except String (List CiItem) :=
  let lines := (text.splitOn "\n").filter (fun l => l.trim ≠ "")
  let items := lines.filterMap parseCiLine
  if items.length = 0 then .error "no graph items parsed from .ci"
  else .ok items

def normName (title : String) : String := nameOfLoc title

/-! ## annotations.toml / cert.toml subset --------------------------------

   [section]
   key = 42
   key = ["a", "b"]
-/

def parseNatValue (v : String) : Option Nat := v.trim.toNat?

def parseListValue (v : String) : Option (List String) :=
  let s := v.trim
  if s.startsWith "[" && s.endsWith "]" then
    let inner := (s.drop 1).dropRight 1
    some (((inner.splitOn ",").map String.trim).filter (fun x => x ≠ ""))
  else none

def parseToml (text : String) :
    Except String (List (String × String × String)) :=  -- (section, key, value)
  let lines := (text.splitOn "\n").map String.trim
  let rec go (sec : String) (acc : List (String × String × String))
      (ls : List String) : Except String (List (String × String × String)) :=
    match ls with
    | [] => .ok acc.reverse
    | l :: rest =>
      if l = "" ∨ l.startsWith "#" then go sec acc rest
      else if l.startsWith "[" && l.endsWith "]" then
        let name := ((l.drop 1).dropRight 1).trim
        go name acc rest
      else
        match l.splitOn "=" with
        | k :: v :: _ => go sec ((sec, k.trim, (String.intercalate "=" v).trim) :: acc) rest
        | _ => .error s!"bad toml line: {l}"
  go "" [] lines

def annOfToml (rows : List (String × String × String)) : Except String Ann := do
  let mut sd : List (String × Nat) := []
  let mut ind : List (String × List String) := []
  let mut dyn : List (String × Nat) := []
  let mut isr : List (String × Nat) := []
  let mut thr : List (String × Nat) := []
  for (sec, k, v) in rows do
    match sec with
    | "recursion" =>
      match parseNatValue v with
      | some n => sd := (k, n) :: sd
      | none => return .error s!"recursion depth not a number: {k} = {v}"
    | "indirect" =>
      match parseListValue v with
      | some ls => ind := (k, ls) :: ind
      | none => return .error s!"indirect targets not a list: {k} = {v}"
    | "dynamic" =>
      match parseNatValue v with
      | some n => dyn := (k, n) :: dyn
      | none => return .error s!"dynamic bound not a number: {k} = {v}"
    | "isr" =>
      match parseNatValue v with
      | some n => isr := (k, n) :: isr
      | none => return .error s!"isr level not a number: {k} = {v}"
    | "threads" =>
      match parseNatValue v with
      | some n => thr := (k, n) :: thr
      | none => return .error s!"thread stack not a number: {k} = {v}"
    | "" => return .error s!"top-level key outside a section: {k}"
    | other => return .error s!"unknown section [{other}]"
  return { selfDepth := sd.reverse, indirect := ind.reverse,
           dynamic := dyn.reverse, isr := isr.reverse, threads := thr.reverse }

def certOfToml (rows : List (String × String × String)) :
    Except String (List (String × Nat)) := do
  let mut c : List (String × Nat) := []
  for (sec, k, v) in rows do
    if sec ≠ "cert" then return .error s!"cert file has unexpected section [{sec}]"
    match parseNatValue v with
    | some n => c := (k, n) :: c
    | none => return .error s!"cert bound not a number: {k} = {v}"
  return c.reverse

end StackcertParsers
