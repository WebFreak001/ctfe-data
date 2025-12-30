# ctfe-data

Allows you to put arbitrary data into the executable at CTFE, for later retrieval
using a runtime process, e.g. saving meta-data and retreiving it later.

Limitations: currently only supported on LDC and GDC on linux. GDC on linux further needs `align(16)` on the passed in data.

## Example

```d
// app code
injectCTFE!(ExamplePerson("Person inside main", 2));
```

```d
// reader code
foreach (row; extractCTFEData!ExamplePerson("./app1"))
	writeln("row: ", row);
```

```
cd example
dub build --compiler=ldc2 --config=application
dub run --compiler=ldc2 --config=reader
```
