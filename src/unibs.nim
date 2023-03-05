import std/[macros, typetraits, bitops]


type BasicType = bool | char | SomeInteger | SomeFloat


# ---- forward decl ----

proc serialize(s: var string, v: string)
proc deserialize(s: string, i: var int, v: var string)
proc serialize[I; T: BasicType](s: var string, vs: array[I, T])
proc serialize[I; T: not BasicType](s: var string, vs: array[I, T])
proc deserialize[T: array](s: string, i: var int, vs: var T)
proc serialize[T: BasicType](s: var string, vs: seq[T])
proc serialize[T: not BasicType](s: var string, vs: seq[T])
proc deserialize[T: seq](s: string, i: var int, vs: var T)
proc serialize[T: tuple](s: var string, vs: T)
proc deserialize[T: tuple](s: string, i: var int, vs: var T)
proc serialize[T](s: var string, vs: set[T])
proc deserialize[T](s: string, i: var int, vs: var set[T])
proc serialize[T: ref](s: var string, v: T)
proc deserialize[T: ref](s: string, i: var int, v: var T)
proc serialize[T: distinct](s: var string, v: T)
proc deserialize[T: distinct](s: string, i: var int, v: var T)
proc serialize[T: enum](s: var string, v: T)
proc deserialize[T: enum](s: string, i: var int, v: var T)
proc serialize(s: var string, x: object)
proc deserialize(s: string, i: var int, x: var object)


# ---- int/float ----

macro buildNumB64: untyped =
  result = newStmtList()
  const sizes =
    when defined(js): [8, 16, 32]
    else:             [8, 16, 32, 64]
  for size in sizes:
    for baseT in ["int", "uint"]:
      let T = ident(baseT & $size)
      result.add: quote do:

        proc serialize(s: var string, v: `T`, i = -1) =
          let size = sizeof(`T`)
          var base = i
          if i < 0:
            base = len(s)
            s.setLen base + size
          var v = v
          for i in countdown(base+size-1, base):
            s[i] = (v and 255).char
            v = v shr 8

        proc deserialize(s: string, i: var int, v: var `T`) =
          for _ in 0 ..< sizeof(`T`):
            v = (v shl 8) or s[i].`T`
            inc i

    when not defined(js):
      if size >= 32:
        let T = ident("float" & $size)
        let intT = ident("uint" & $size)
        result.add: quote do:

          proc serialize(s: var string, v: `T`, i = -1) =
            serialize(s, cast[`intT`](v), i)

          proc deserialize(s: string, i: var int, v: var `T`) =
            var vi: `intT`
            deserialize(s, i, vi)
            v = cast[`T`](vi)

buildNumB64()

when defined(js):
  import std/private/jsutils

  type DataView = ref object of JsRoot
  func newDataView(b: ArrayBuffer): DataView {.importjs: "new DataView(#)".}

  func getUint32(view: DataView, offset: int): uint32 {.importjs: "#.getUint32(#)".}
  proc setUint32(view: DataView, offset: int, n: uint32) {.importjs: "#.setUint32(#, #)".}

  func getFloat32(view: DataView, offset: int): float32 {.importjs: "#.getFloat32(#)".}
  proc setFloat32(view: DataView, offset: int, n: float32) {.importjs: "#.setFloat32(#, #)".}
  func getFloat64(view: DataView, offset: int): float64 {.importjs: "#.getFloat64(#)".}
  proc setFloat64(view: DataView, offset: int, n: float64) {.importjs: "#.setFloat64(#, #)".}

  proc serialize(s: var string, v: float32, i = -1) =
    let buffer = newArrayBuffer(4)
    let view = newDataView(buffer)
    view.setFloat32(0, v)
    serialize(s, view.getUint32(0), i)

  proc deserialize(s: string, i: var int, v: var float32) =
    let buffer = newArrayBuffer(4)
    let view = newDataView(buffer)
    var vi: uint32
    deserialize(s, i, vi)
    view.setUint32(0, vi)
    v = view.getFloat32(0)

  proc serialize(s: var string, v: float64, i = -1) =
    let buffer = newArrayBuffer(8)
    let view = newDataView(buffer)
    view.setFloat64(0, v)
    if i == -1:
      for offset in [0, 4]:
        serialize(s, view.getUint32(offset))
    else:
      for offset in [0, 4]:
        serialize(s, view.getUint32(offset), i + offset)
    
  proc deserialize(s: string, i: var int, v: var float64) =
    let buffer = newArrayBuffer(8)
    let view = newDataView(buffer)
    for offset in [0, 4]:
      var vi: uint32
      deserialize(s, i, vi)
      debugEcho vi
      view.setUint32(offset, vi)
    v = view.getFloat64(0)

proc serialize(s: var string, v: int, i = -1) =
  when sizeof(int) == 4: serialize(s, v.int32, i)
  elif sizeof(int) == 8: serialize(s, v.int64, i)

proc deserialize(s: string, i: var int, v: var int) =
  when sizeof(int) == 4:
    var vi: int32
  elif sizeof(int) == 8:
    var vi: int64
  deserialize(s, i, vi)
  v = vi.int


# ---- char ----

proc serialize(s: var string, v: char, i = -1) =
  if i == -1: s    &= v
  else:       s[i]  = v

proc deserialize(s: string, i: var int, v: var char) =
  v = s[i]
  inc i


# ---- bool ----

proc serialize(s: var string, v: bool, i = -1) =
  if i < 0: s   &= v.char
  else:     s[i] = v.char

proc deserialize(s: string, i: var int, v: var bool) =
  v = s[i] != '\0'
  inc i


# ---- string ----

proc serialize(s: var string, v: string) =
  serialize(s, len(v))
  s &= v

proc deserialize(s: string, i: var int, v: var string) =
  var l: int
  deserialize(s, i, l)
  let base = i
  i += l
  v = s[base ..< i]


# ---- array ----

proc serialize[I; T: BasicType](s: var string, vs: array[I, T]) =
  var base = len(s)
  let size = sizeof(T)
  s.setLen base + size*len(vs)
  for v in vs:
    serialize(s, v, base)
    base += size

proc serialize[I; T: not BasicType](s: var string, vs: array[I, T]) =
  for v in vs: serialize(s, v)

proc deserialize[T: array](s: string, i: var int, vs: var T) =
  for v in vs.mitems: deserialize(s, i, v)


# ---- seq ----

proc serialize[T: BasicType](s: var string, vs: seq[T]) =
  var base = len(s)
  let size = sizeof(T)
  let l = len(vs)
  s.setLen base + size*l + sizeof(l)
  serialize(s, l, base)
  base += sizeof(l)
  for v in vs:
    serialize(s, v, base)
    base += size

proc serialize[T: not BasicType](s: var string, vs: seq[T]) =
  serialize(s, len(vs))
  for v in vs: serialize(s, v)

proc deserialize[T: seq](s: string, i: var int, vs: var T) =
  var l: int
  deserialize(s, i, l)
  vs.setLen l
  for v in vs.mitems: deserialize(s, i, v)


# ---- tuple ----

proc serialize[T: tuple](s: var string, vs: T) =
  for v in vs.fields: serialize(s, v)

proc deserialize[T: tuple](s: string, i: var int, vs: var T) =
  for v in vs.fields: deserialize(s, i, v)


# ---- set ----

proc setSize(T: typedesc): int =
  high(T).int - low(T).int

proc serialize[T](s: var string, vs: set[T]) =
  var base = len(s)
  s.setLen base + setSize(T)
  var i = 0
  var v: uint8
  for x in low(T)..high(T):
    if x in vs: v.setBit i
    inc i
    if i == 8:
      s[base] = v.char
      v = 0
      i = 0
      inc base
  s[base] = v.char

proc deserialize[T](s: string, i: var int, vs: var set[T]) =
  var v = low(T)
  for c in s[(len(s) - setSize(T)) ..< len(s)]:
    for i in 0 ..< 8:
      if v == high(T): return
      if c.int.testBit(i): vs.incl v
      inc v


# ---- ref ----

proc serialize[T: ref](s: var string, v: T) =
  serialize(s, v[])

proc deserialize[T: ref](s: string, i: var int, v: var T) =
  new v
  deserialize(s, i, v[])


# ---- distinct ----

proc serialize[T: distinct](s: var string, v: T) =
  serialize(s, v.distinctBase)

proc deserialize[T: distinct](s: string, i: var int, v: var T) =
  var vb = v.distinctBase
  deserialize(s, i, vb)
  v = vb.T


# ---- enum ----

proc serialize[T: enum](s: var string, v: T) =
  const size = sizeof(T)
  serialize(s):
    when size == 1: v.int8
    elif size <= 2: v.int16
    elif size <= 4: v.int32
    elif size <= 8: v.int64

proc deserialize[T: enum](s: string, i: var int, v: var T) =
  const size = sizeof(T)
  when size == 1:
    var vi: int8
  elif size <= 2:
    var vi: int16
  elif size <= 4:
    var vi: int32
  elif size <= 8:
    var vi: int64
  deserialize(s, i, vi)
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


macro serializeImpl(s: var string, x: object) =

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
          `s`.serialize(`discriminator`)

        objectRecCaseImpl(node): gen(nextNode, s,x)

      else:
        if node.kind != nnkIdentDefs: debugEcho "here"
        let field = node[0]
        result.add: quote do:
          `s`.serialize(`x`.`field`)

  gen(x.getTypeImpl[2], s,x)

proc serialize(s: var string, x: object) = serializeImpl(s, x)


macro deserializeImpl(s: string, i: var int, x: var object) =

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
          `s`.deserialize(`i`, `discriminator`)
          `x`.`discriminatorField` = `discriminator`

        objectRecCaseImpl(node): gen(nextNode, s,i,x)

      else:
        let field = node[0]
        result.add: quote do:
          `s`.deserialize(`i`, `x`.`field`)

  result = gen(x.getTypeImpl[2], s,i,x)

proc deserialize(s: string, i: var int, x: var object) = deserializeImpl(s, i, x)


# ---- main ----

proc serialize*[T](v: T): string =
  serialize(result, v)

proc deserialize*[T](s: string, td: typedesc[T]): T =
  var i = 0
  deserialize(s, i, result)