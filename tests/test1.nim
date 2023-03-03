# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import b64serial


proc testEq[T](v: T): bool =
  v.toB64s.fromB64s(T) == v

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