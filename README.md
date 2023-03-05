## Unibs

Serialize and deserialize any any type to/from binary form.<br>
Works in `c`, `js` backend, and in compiletime.<br>

### serialize
```nim
let serial = serialize([("foo", 4), ("ba", 2)])
```

### deserialize
```nim
let data = deserialize(x, array[2, (string, int)])
```