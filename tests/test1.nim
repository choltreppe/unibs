import std/[unittest, sequtils]

import b64serial {.all.}


proc testEq[T](v: T): bool =
  let s = v.toB64s
  s.allIt(it in base64table) and
  s.fromB64s(T) == v

template checkEq(v: untyped) =
  check testEq  v


test "basic types":

  checkEq true
  checkEq false

  checkEq 2679
  checkEq -45
  checkEq 67.int8
  checkEq 67.uint8
  checkEq 78900123.uint32

  checkEq 'd'
  checkEq '-'


test "string":

  checkEq "a"
  checkEq "bc"
  checkEq "def"
  checkEq "ghij"
  checkEq "klmno"
  checkEq "pqrstu"
  checkEq "vwxyz42"


type Direction = enum north, east, south, west

test "enum":
  checkEq east


type Degrees = distinct int
proc `==` * (x, y: Degrees): bool {.borrow.}

test "distinct":
  checkEq 300.Degrees


test "tuple":
  checkEq (1, 'a', true)


test "set":

  checkEq {'0'..'3', 'x', '+'}
  checkEq {0.uint16, 67, 16}
  checkEq {8, 45, 7}

  checkEq {north, south}


test "array":

  checkEq [1, 3, 6, -2]
  checkEq [true, false, false]
  checkEq [3.5, 0.4]

  checkEq [(3, 'x'), (7, 'd'), (0, '0')]

  checkEq array[3..6, uint8]([2u8,1,5,6])
  checkEq [north: 0.Degrees, east: 90.Degrees, south: 180.Degrees, west: 270.Degrees]


test "seq":

  checkEq @[4, 2, 0]
  checkEq @['a', '0', '+', ' ']

  checkEq @[('a', 42, true), ('b', 1337, false)]


test "ref":

  var v: ref int
  new v
  v[] = 23

  check v.toB64s.fromB64s(ref int)[] == v[]


test "object (basic)":

  type
    Gender = enum male, female
    Person = object
      name: string
      age: int
      gender: Gender

  checkEq Person(name: "Joe", age: 42, gender: male)


test "variant object":

  type
    NumberKind = enum numInt, numFloat
    Number = object
      case kind: NumberKind
      of numInt:   i: int
      of numFloat: f: float

  let ni = Number(kind: numInt, i: 8)
  let niTest = ni.toB64s.fromB64s(Number)
  check ni.kind == niTest.kind
  check ni.i    == niTest.i

  let nf = Number(kind: numFloat, f: 13.37)
  let nfTest = nf.toB64s.fromB64s(Number)
  check nf.kind == nfTest.kind
  check nf.f    == nfTest.f


test "recursive object":

  type
    Tree = ref object
      val: int
      case isLeaf: bool
      of true: discard
      else:
        lhs, rhs: Tree

  func val(v: int): Tree = Tree(val: v, isLeaf: true)
  func val(tree: Tree): Tree = tree

  func tree(l: int|Tree, v: int, r: int|Tree): Tree =
    Tree(val: v, isLeaf: false, lhs: val(l), rhs: val(r))

  let t1 = tree(1, 2, 3)
  let t1Test = t1.toB64s.fromB64s(Tree)
  check t1.val        == t1Test.val
  check t1.lhs.isLeaf == t1Test.lhs.isLeaf
  check t1.lhs.val    == t1Test.lhs.val
  check t1.rhs.val    == t1Test.rhs.val

  let t2 = tree(3, 5, tree(tree(8, 3, 2), 6, 9))
  let t2Test = t2.toB64s.fromB64s(Tree)
  check t2.lhs.val         == t2Test.lhs.val
  check t2.rhs.lhs.val     == t2Test.rhs.lhs.val
  check t2.rhs.lhs.rhs.val == t2Test.rhs.lhs.rhs.val


test "variant object with multiple discriminators":

  type
    ComplexVariantKind = enum cvkA, cvkB, cvkC
    ComplexVariantSubKind = enum cvskA, cvskB
    ComplexVariant = object
      a: int
      case kind: ComplexVariantKind
      of cvkA: b: int
      else:
        case subKind: ComplexVariantSubKind
        of cvskA: c: int
        of cvskB:
          d,e: int
      case isSomething: bool
      of true: f: int
      else: discard

  let cv1 = ComplexVariant(a: 4, kind: cvkA, b: 2, isSomething: true, f: 0)
  let cv1Test = cv1.toB64s.fromB64s(ComplexVariant)

  doAssert cv1.a == cv1Test.a
  doAssert cv1.b == cv1Test.b
  doAssert cv1.f == cv1Test.f

  let cv2 = ComplexVariant(a: 1, kind: cvkC, subKind: cvskB, d: 3, e: 3, isSomething: true, f: 7)
  let cv2Test = cv2.toB64s.fromB64s(ComplexVariant)

  doAssert cv2.a == cv2Test.a
  doAssert cv2.d == cv2Test.d
  doAssert cv2.e == cv2Test.e
  doAssert cv2.f == cv2Test.f