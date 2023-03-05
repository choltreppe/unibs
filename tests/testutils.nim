import std/macros

var allPassed = true

macro check*(body: bool) =
  let bodyStr = body.repr
  let passed = ident"passed"
  quote do:
    if not `body`:
      echo "failed assertion: ", `bodyStr`
      `passed` = false

template test*(name: static string, body: untyped) =
  block:
    var passed {.inject.} = true
    `body`
    echo:
      "[" & (
        if passed: "OK"
        else:
          allPassed = false
          "FAILED"
      ) &
      " " & name & "]"

proc printResult* =
  if allPassed:
    echo "[all tests passed]"

  else: quit 1