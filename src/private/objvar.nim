#[
The MIT License (MIT)

Copyright (c) 2021 Andre von Houck

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]#

import std/macros

proc hasKind(node: NimNode, kind: NimNodeKind): bool =
  for c in node.children:
    if c.kind == kind:
      return true
  return false

proc `[]`(node: NimNode, kind: NimNodeKind): NimNode =
  for c in node.children:
    if c.kind == kind:
      return c
  return nil

macro isObjectVariant*(v: typed): bool =
  ## Is this an object variant?
  var typ = v.getTypeImpl()
  if typ.kind == nnkSym:
    return ident("false")
  while typ.kind != nnkObjectTy:
    typ = typ[0].getTypeImpl()
  if typ[2].hasKind(nnkRecCase):
    ident("true")
  else:
    ident("false")

proc discriminator*(v: NimNode): NimNode =
  var typ = v.getTypeImpl()
  while typ.kind != nnkObjectTy:
    typ = typ[0].getTypeImpl()
  return typ[nnkRecList][nnkRecCase][nnkIdentDefs][nnkSym]

macro discriminatorFieldName*(v: typed): untyped =
  ## Turns into the discriminator field.
  return newLit($discriminator(v))

macro discriminatorField*(v: typed): untyped =
  ## Turns into the discriminator field.
  let
    fieldName = discriminator(v)
  return quote do:
    `v`.`fieldName`

macro new*(v: typed, d: typed): untyped =
  ## Creates a new object variant with the discriminator field.
  let
    typ = v.getTypeInst()
    fieldName = discriminator(v)
  return quote do:
    `v` = `typ`(`fieldName`: `d`)