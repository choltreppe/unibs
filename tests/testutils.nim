import std/macros

macro check*(body: bool) =
  let bodyStr = body.repr
  let worked = ident"worked"
  quote do:
    if not `body`:
      echo "failed assertion: ", `bodyStr`
      `worked` = false

template test*(name: static string, body: untyped) =
  block:
    var worked {.inject.} = true
    `body`
    echo:
      "[" & (
        if worked: "OK"
        else: "FAILED"
      ) &
      " " & name & "]"