# Package

version       = "0.1.0"
author        = "Joel Lienhard"
description   = "binary de-/serialization that works on js, c and comp-time"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.9.1"


task test, "run tests":

  echo "[ TEST c backend ]"
  exec "nim c -r tests/test.nim"

  echo "[ TEST js backend ]"
  exec "nim js -r tests/test.nim"

  #echo "[ TEST vm ]"
  #exec "nim e tests/test.nim"