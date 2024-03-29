import std/[sequtils, tables]
import ./testutils
import unibs


let hexChars = block:
  var res: array[16, char]
  var i = 0
  for cs in ['0'..'9', 'A'..'F']:
    for c in cs:
      res[i] = c
      inc i
  res

proc hex(s: string): string =
  for c in s:
    result &= hexChars[(c.int shr 4) and 15] 
    result &= hexChars[ c.int        and 15] 

proc testEq[T](v: T): bool =
  let s = v.serialize
  when T isnot set:
    echo s.hex
  s.deserialize(T) == v

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

  when not defined(js):
    checkEq high(uint64)
    checkEq high(int64)

  checkEq 1.4
  checkEq 578.356

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
proc `==`*(x, y: Degrees): bool {.borrow.}
func `$`*(x: Degrees): string {.borrow.}

test "distinct":
  checkEq 300.Degrees


test "tuple":
  checkEq (1, 'a', true)


test "set":

  checkEq {'0'..'3', 'x', '+'}
  checkEq {0.uint16, 67, 16}
  checkEq {8, 45, 7}

  checkEq {north, west}


test "array":

  checkEq [1, 3, 6, -2]
  checkEq [true, false, false]
  checkEq [3.5, 0.4]

  checkEq [(3, 'x'), (7, 'd'), (0, '0')]

  let arr: array[range[3..6], uint8] = [2u8,1,5,6]
  checkEq arr
  checkEq [north: 0.Degrees, east: 90.Degrees, south: 180.Degrees, west: 270.Degrees]


test "seq":

  checkEq @[4, 2, 0]
  checkEq @['a', '0', '+', ' ']

  checkEq @["foo", "ba"]

  checkEq @[('a', 42, true), ('b', 1337, false)]
  checkEq @[@["bmo"], @["jake", "finn"]]
  checkEq @[@[(2, "frfr")], @[(67, "bli"), (99, "bla")]]


test "ref":

  var v: ref int
  new v
  v[] = 23

  check v.serialize.deserialize(ref int)[] == v[]

  checkEq (ref int)(nil)
  checkEq (ref char)(nil)


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
  let niTest = ni.serialize.deserialize(Number)
  check ni.kind == niTest.kind
  check ni.i    == niTest.i

  let nf = Number(kind: numFloat, f: 13.37)
  let nfTest = nf.serialize.deserialize(Number)
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
  let t1Test = t1.serialize.deserialize(Tree)
  check t1.val        == t1Test.val
  check t1.lhs.isLeaf == t1Test.lhs.isLeaf
  check t1.lhs.val    == t1Test.lhs.val
  check t1.rhs.val    == t1Test.rhs.val

  let t2 = tree(3, 5, tree(tree(8, 3, 2), 6, 9))
  let t2Test = t2.serialize.deserialize(Tree)
  check t2.lhs.val         == t2Test.lhs.val
  check t2.rhs.lhs.val     == t2Test.rhs.lhs.val
  check t2.rhs.lhs.rhs.val == t2Test.rhs.lhs.rhs.val


test "tables":

  checkEq {"dede": 2, "dfb89=": -467, "": 0}.toTable
  checkEq {(3, '-'): true, (-45, '0'): false, (42, '#'): true}.toOrderedTable
  checkEq {"foo": 4, "ba": 2}.toCountTable
  checkEq {"bli": (123u8, true), "bla": (2u8, false)}.newTable


printResult()