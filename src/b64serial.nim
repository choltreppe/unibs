import std/[macros, typetraits, bitops]


const
  base64table = block:
    var res: array[64, char]
    var i = 0
    for s in ['A'..'Z', 'a'..'z', '0'..'9']:
      for c in s:
        res[i] = c
        inc i
    res[62] = '+'
    res[63] = '/'
    res

  base64tableInv = block:
    var res: array[char, int8]
    for i, c in base64table:
      res[c] = i
    res

template neededSpace(T: typedesc): int =
  (sizeof(T)*8 + 5) div 6


# ---- forward decl ----

proc toB64s[T: array](s: var string, vs: T)
proc fromB64s[T: array](s: string, i: var int, vs: var T)
proc toB64s[T: seq](s: var string, vs: T)
proc fromB64s[T: seq](s: string, i: var int, vs: var T)
proc toB64s[T: tuple](s: var string, vs: T)
proc fromB64s[T: tuple](s: string, i: var int, vs: var T)
proc toB64s[T](s: var string, vs: set[T])
proc fromB64s[T](s: string, i: var int, vs: var set[T])
proc toB64s[T: ref](s: var string, v: T)
proc fromB64s[T: ref](s: string, i: var int, v: var T)
proc toB64s[T: distinct](s: var string, v: T)
proc fromB64s[T: distinct](s: string, i: var int, v: var T)
proc toB64s[T: enum](s: var string, v: T)
proc fromB64s[T: enum](s: string, i: var int, v: var T)
proc toB64s(s: var string, x: object)
proc fromB64s(s: string, i: var int, x: var object)


# ---- int/float ----

macro buildNumB64: untyped =
  result = newStmtList()
  for size in [8, 16, 32, 64]:
    for baseT in ["int", "uint"]:
      let T = ident(baseT & $size)
      result.add: quote do:

        proc toB64s(s: var string, v: `T`) =
          let base = len(s)
          s.setLen base + neededSpace(`T`)
          var v = v
          for i in countdown(high(s), base):
            s[i] = base64table[v and 63]
            v = v shr 6

        proc fromB64s(s: string, i: var int, v: var `T`) =
          for _ in 0 ..< neededSpace(`T`):
            v = (v shl 6) or base64tableInv[s[i]].`T`
            inc i

    if size >= 32:
      let T = ident("float" & $size)
      let intT = ident("int" & $size)
      result.add: quote do:

        proc toB64s(s: var string, v: `T`) =
          toB64s(s, cast[`intT`](v))

        proc fromB64s(s: string, i: var int, v: var `T`) =
          var vi: `intT`
          fromB64s(s, i, vi)
          v = cast[`T`](vi)

buildNumB64()

proc toB64s(s: var string, v: int) =
  when sizeof(int) == 4: toB64s(s, v.int32)
  elif sizeof(int) == 8: toB64s(s, v.int64)

proc fromB64s(s: string, i: var int, v: var int) =
  when sizeof(int) == 4:
    var vi: int32
  elif sizeof(int) == 8:
    var vi: int64
  fromB64s(s, i, vi)
  v = vi.int


# ---- char ----

proc toB64s(s: var string, v: char) =
  toB64s(s, v.int8)

proc fromB64s(s: string, i: var int, v: var char) =
  var vi: int8
  fromB64s(s, i, vi)
  v = vi.char


# ---- bool ----

proc toB64s(s: var string, v: bool) =
  s &= base64table[v.int]

proc fromB64s(s: string, i: var int, v: var bool) =
  v = base64tableInv[s[i]] != 0
  inc i


# ---- string ----

#[proc toB64s(s: var string, v: string) =
  toB64s(s, len(v))
  let base = len(s)
  s.setLen base + len(v)]#


# ---- array ----

proc toB64s[T: array](s: var string, vs: T) =
  for v in vs: toB64s(s, v)

proc fromB64s[T: array](s: string, i: var int, vs: var T) =
  for v in vs.mitems: fromB64s(s, i, v)


# ---- seq ----

proc toB64s[T: seq](s: var string, vs: T) =
  toB64s(s, len(vs))
  for v in vs: toB64s(s, v)

proc fromB64s[T: seq](s: string, i: var int, vs: var T) =
  var l: int
  fromB64s(s, i, l)
  vs.setLen l
  for v in vs.mitems: fromB64s(s, i, v)


# ---- tuple ----

proc toB64s[T: tuple](s: var string, vs: T) =
  for v in vs.fields: toB64s(s, v)

proc fromB64s[T: tuple](s: string, i: var int, vs: var T) =
  for v in vs.fields: fromB64s(s, i, v)


# ---- set ----

proc toB64s[T](s: var string, vs: set[T]) =
  var base = len(s)
  s.setLen base + neededSpace(set[T])
  var i = 0
  var v: int8
  for x in low(T)..high(T):
    if x in vs: v.setBit i
    inc i
    if i == 6:
      s[base] = base64table[v]
      v = 0
      i = 0
      inc base
  s[base] = base64table[v]

proc fromB64s[T](s: string, i: var int, vs: var set[T]) =
  var v = low(T)
  for c in s[(len(s) - neededSpace(set[T])) ..< len(s)]:
    let b = base64tableInv[c]
    for i in 0 ..< 6:
      if v == high(T): return
      if b.testBit(i): vs.incl v
      inc v


# ---- ref ----

proc toB64s[T: ref](s: var string, v: T) =
  toB64s(s, v[])

proc fromB64s[T: ref](s: string, i: var int, v: var T) =
  new v
  fromB64s(s, i, v[])


# ---- distinct ----

proc toB64s[T: distinct](s: var string, v: T) =
  toB64s(s, v.distinctBase)

proc fromB64s[T: distinct](s: string, i: var int, v: var T) =
  fromB64s(s, i, v.distinctBase)


# ---- enum ----

proc toB64s[T: enum](s: var string, v: T) =
  const size = sizeof(T)
  toB64s(s):
    when size == 1: v.int8
    elif size <= 2: v.int16
    elif size <= 4: v.int32
    elif size <= 8: v.int64

proc fromB64s[T: enum](s: string, i: var int, v: var T) =
  const size = sizeof(T)
  when size == 1:
    var vi: int8
  elif size <= 2:
    var vi: int16
  elif size <= 4:
    var vi: int32
  elif size <= 8:
    var vi: int64
  fromB64s(s, i, vi)
  v = vi.T


# ---- object ----

template objectRecCaseImpl(node: NimNode, selfCall: untyped): untyped =
  var caseStmt = nnkCaseStmt.newTree(discriminator)
  for branch in node[1 .. ^1]:
    caseStmt.add:
      if branch.kind == nnkOfBranch:
        if branch[1].kind == nnkRecList:
          var nextNode {.inject.} = branch[1]
          nnkOfBranch.newTree(branch[0], selfCall)
        else:
          let nextNode {.inject.} = branch[1 .. ^1]
          nnkOfBranch.newTree(branch[0], selfCall)
      else:
        if branch[0].kind == nnkRecList:
          let nextNode {.inject.} = branch[0]
          nnkElse.newTree(selfCall)
        else:
          let nextNode {.inject.} = branch
          nnkElse.newTree(selfCall)
  result.add caseStmt


macro toB64sImpl(s: var string, x: object) =

  func gen(nodes: NimNode|seq[NimNode], s,x: NimNode): NimNode =
    result = newStmtList()
    for node in nodes:
      case node.kind
      of nnkRecList:
        result.add gen(node, s,x)

      of nnkRecCase:
        let discriminatorField = node[0][0]
        let discriminator = quote do: `x`.`discriminatorField`
        result.add: quote do:
          `s`.toB64s(`discriminator`)

        objectRecCaseImpl(node): gen(nextNode, s,x)

      else:
        if node.kind != nnkIdentDefs: debugEcho "here"
        let field = node[0]
        result.add: quote do:
          `s`.toB64s(`x`.`field`)

  gen(x.getTypeImpl[2], s,x)

proc toB64s(s: var string, x: object) = toB64sImpl(s, x)


macro fromB64sImpl(s: string, i: var int, x: var object) =

  func gen(nodes: NimNode|seq[NimNode], s,i,x: NimNode): NimNode =
    result = newStmtList()
    for node in nodes:
      case node.kind
      of nnkRecList:
        result.add gen(node, s,i,x)

      of nnkRecCase:
        let discriminatorField = node[0][0]
        let discriminatorType = node[0][1]
        let discriminator = genSym(nskVar, "discriminator")
        result.add: quote do:
          var `discriminator`: `discriminatorType`
          `s`.fromB64s(`i`, `discriminator`)
          `x`.`discriminatorField` = `discriminator`

        objectRecCaseImpl(node): gen(nextNode, s,i,x)

      else:
        let field = node[0]
        result.add: quote do:
          `s`.fromB64s(`i`, `x`.`field`)

  result = gen(x.getTypeImpl[2], s,i,x)

proc fromB64s(s: string, i: var int, x: var object) = fromB64sImpl(s, i, x)


# ---- main ----

proc toB64s*[T](v: T): string =
  toB64s(result, v)

proc fromB64s*[T](s: string, td: typedesc[T]): T =
  var i = 0
  fromB64s(s, i, result)