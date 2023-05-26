import std/[macros, typetraits, bitops, tables]
import ./private/objvar


type BasicType = bool | char | SomeInteger | SomeFloat

type SomeTable[K, V] = Table[K, V] | OrderedTable[K, V]

func neededSpace(T: typedesc[not set]): int =
  when defined(js) and T is int: 8
  else: sizeof(T)

func neededSpace[T](td: typedesc[set[T]]): int =
  (high(T).int - low(T).int + 8) div 8

func neededSpace[T](v: T): int = neededSpace(T)


# ---- forward decl ----

proc serialize(s: var string, v: string)
proc deserialize(s: string, i: var int, v: var string)

proc serialize[I, T](s: var string, vs: array[I, T])
proc deserialize[T: array](s: string, i: var int, vs: var T)

proc serialize[T](s: var string, vs: seq[T])
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

proc serialize(s: var string, t: SomeTable | CountTable)
proc deserialize[K, V](s: string, i: var int, t: var SomeTable[K, V])
proc deserialize[K](s: string, i: var int, t: var CountTable[K])


# ---- int/float ----

macro buildNumSerial: untyped =
  result = newStmtList()
  const sizes =
    when defined(js): [8, 16, 32]
    else:             [8, 16, 32, 64]
  for size in sizes:
    for baseT in ["int", "uint"]:
      let T = ident(baseT & $size)
      result.add: quote do:

        proc serialize(s: var string, v: `T`, i = -1) =
          let size = neededSpace(`T`)
          var base = i
          if i < 0:
            base = len(s)
            s.setLen base + size
          var v = v
          for i in countdown(base+size-1, base):
            s[i] = (v and 255).char
            v = v shr 8

        proc deserialize(s: string, i: var int, v: var `T`) =
          for _ in 0 ..< neededSpace(`T`):
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

buildNumSerial()

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
      view.setUint32(offset, vi)
    v = view.getFloat64(0)

  proc serialize(s: var string, v: int, i = -1) =
    if i < 0:
      let base = len(s) + 4
      s.setLen base + 4
      serialize(s, v.int32, base)
    else:
      serialize(s, v.int32, i + 4)

  proc deserialize(s: string, i, v: var int) =
    i += 4
    var vi: int32
    deserialize(s, i, vi)
    v = vi.int

else:

  proc serialize(s: var string, v: int, i = -1) =
    serialize(s, v.int64, i)

  proc deserialize(s: string, i, v: var int) =
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

proc serialize[I, T](s: var string, vs: array[I, T]) =
  when T is BasicType:
    var base = len(s)
    let size = neededSpace(T)
    s.setLen base + size*len(vs)
    for v in vs:
      serialize(s, v, base)
      base += size
  else:
    for v in vs: serialize(s, v)

proc deserialize[T: array](s: string, i: var int, vs: var T) =
  for v in vs.mitems: deserialize(s, i, v)


# ---- seq ----

proc serialize[T](s: var string, vs: seq[T]) =
  when T is BasicType:
    var base = len(s)
    let size = neededSpace(T)
    let l = len(vs)
    s.setLen base + size*l + neededSpace(l)
    serialize(s, l, base)
    base += neededSpace(l)
    for v in vs:
      serialize(s, v, base)
      base += size
  else:
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

proc serialize[T](s: var string, vs: set[T]) =
  var base = len(s)
  s.setLen base + neededSpace(vs)
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
  if i > 0:
    s[base] = v.char

proc deserialize[T](s: string, i: var int, vs: var set[T]) =
  var v = low(T)
  for c in s[(len(s) - neededSpace(vs)) ..< len(s)]:
    for i in 0 ..< 8:
      if c.int.testBit(i): vs.incl v
      if v == high(T): return
      inc v


# ---- ref ----

proc serialize[T: ref](s: var string, v: T) =
  if v == nil: s &= '0'
  else:
    s &= char(1)
    serialize(s, v[])

proc deserialize[T: ref](s: string, i: var int, v: var T) =
  inc i
  if s[i-1] != '0':
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
  const size = neededSpace(T)
  serialize(s):
    when size == 1: v.int8
    elif size <= 2: v.int16
    elif size <= 4: v.int32
    elif size <= 8: v.int64

proc deserialize[T: enum](s: string, i: var int, v: var T) =
  const size = neededSpace(T)
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

proc serialize(s: var string, x: object) =
  when x.isObjectVariant:
    serialize(s, x.discriminatorField)
    for k, e in x.fieldPairs:
      when k != x.discriminatorFieldName:
        serialize(s, e)
  else:
    for e in x.fields:
      serialize(s, e)

proc deserialize(s: string, i: var int, x: var object) =
  when x.isObjectVariant:
    var discriminator: type(x.discriminatorField)
    deserialize(s, i, discriminator)
    new(x, discriminator)
    for k, e in x.fieldPairs:
      when k != x.discriminatorFieldName:
        deserialize(s, i, e)
  else:
    for e in x.fields:
      deserialize(s, i, e)


# ---- tables ----

proc serialize(s: var string, t: SomeTable | CountTable) =
  serialize(s, len(t))
  for kv in t.pairs:
    serialize(s, kv)

proc deserializeTable[T](s: string, i: var int, t: var T, K,V: typedesc) =
  var kvs: seq[(K, V)]
  deserialize(s, i, kvs)
  for (k, v) in kvs:
    t[k] = v

proc deserialize[K, V](s: string, i: var int, t: var SomeTable[K, V]) =
  deserializeTable(s, i, t, K, V)

proc deserialize[K](s: string, i: var int, t: var CountTable[K]) =
  deserializeTable(s, i, t, K, int)


# ---- main ----

proc serialize*[T](v: T): string =
  serialize(result, v)

proc deserialize*[T](s: string, td: typedesc[T]): T =
  var i = 0
  deserialize(s, i, result)