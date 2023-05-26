**important: this package is pretty much a worse version of flatty (some parts even copied from there) except the advantage that it works at comp-time**, so just cosider it when you need the comptime support.

## Unibs

Serialize and deserialize any type to/from binary form.<br>
Works in `c`, `js` backend, and in compiletime.<br>

### serialize
```nim
let serial = serialize([("foo", 4), ("ba", 2)])
```

### deserialize
```nim
let data = deserialize(serial, array[2, (string, int)])
```
