# Lowbar

A utility-belt plugin for the [ARO language](https://github.com/arolang/aro) that gives you 71 qualifiers and 5 actions for working with collections, objects, types, and values — all expressed in plain language.

Lowbar turns common data operations into single ARO statements. Filter a list, reshape an object, check a type, generate a sequence — no boilerplate, no ceremony.

```aro
Create the <users> with [
    { name: "Alice", age: 30, role: "admin" },
    { name: "Bob",   age: 25, role: "user" },
    { name: "Eve",   age: 22, role: "user" }
].

Compute the <admins: lowbar.matching> from the <users> with { role: "admin" }.
Compute the <names: lowbar.pluck> from the <admins> with { field: "name" }.
(* names = ["Alice"] *)

Compute the <sorted: lowbar.sortby> from the <users> with { field: "age" }.
Compute the <youngest: lowbar.first> from the <sorted>.
(* youngest = { name: "Eve", age: 22, role: "user" } *)
```

## Installation

### With the ARO package manager

```bash
aro add https://github.com/arolang/Lowbar.git
```

### Manual

Copy the `Plugins/lowbar/` directory into your ARO application's `Plugins/` folder:

```
MyApp/
├── main.aro
└── Plugins/
    └── lowbar/
        ├── plugin.yaml
        ├── Package.swift
        └── Sources/
            └── LowbarPlugin.swift
```

ARO discovers and compiles the plugin automatically on first run.

## How It Works

Lowbar provides two kinds of tools:

### Qualifiers

Qualifiers transform values inline using the `<result: handle.qualifier>` syntax. The handle is `lowbar`:

```aro
Compute the <reversed: lowbar.reverse> from the <items>.
```

Many qualifiers accept parameters through a `with { }` clause:

```aro
Compute the <top-three: lowbar.first> from the <items> with { n: 3 }.
Compute the <sorted: lowbar.sortby> from the <users> with { field: "age" }.
```

Qualifiers also work inside expressions:

```aro
Log <items: lowbar.reverse> to the <console>.
```

### Actions

Actions are verb-based statements that generate new data. The handle is `Lowbar` (PascalCase):

```aro
Lowbar.Range the <numbers> with { stop: 10 }.
Lowbar.Random the <dice> with { min: 1, max: 6 }.
```

## Quick Reference

### Collections (39 qualifiers)

| Qualifier | Description | Example |
|-----------|-------------|---------|
| `first` | First element, or first N | `<x: lowbar.first>` / `with { n: 3 }` |
| `last` | Last element, or last N | `<x: lowbar.last>` / `with { n: 2 }` |
| `rest` | Everything after the first | `<x: lowbar.rest>` / `with { n: 3 }` |
| `initial` | Everything before the last | `<x: lowbar.initial>` / `with { n: 2 }` |
| `compact` | Remove falsy values | `<x: lowbar.compact>` |
| `flatten` | Flatten nested lists | `<x: lowbar.flatten>` / `with { deep: false }` |
| `uniq` | Remove duplicates | `<x: lowbar.uniq>` / `with { field: "id" }` |
| `shuffle` | Random reorder (Fisher-Yates) | `<x: lowbar.shuffle>` |
| `sample` | Random element(s) | `<x: lowbar.sample>` / `with { n: 3 }` |
| `size` | Count elements/chars/keys | `<x: lowbar.size>` |
| `reverse` | Reverse list or string | `<x: lowbar.reverse>` |
| `toarray` | Convert to array | `<x: lowbar.toarray>` |
| `sortby` | Sort by field | `with { field: "age" }` / `with { order: "desc" }` |
| `groupby` | Group by field | `with { field: "role" }` |
| `countby` | Count per group | `with { field: "status" }` |
| `indexby` | Build lookup object | `with { field: "id" }` |
| `pluck` | Extract one field | `with { field: "name" }` |
| `matching` | Filter by properties | `with { role: "admin", active: true }` |
| `findwhere` | First match | `with { role: "admin" }` |
| `rejectwhere` | Inverse filter | `with { role: "admin" }` |
| `partition` | Split into [pass, fail] | `with { active: true }` |
| `max` | Maximum value or by field | `<x: lowbar.max>` / `with { field: "age" }` |
| `min` | Minimum value or by field | `<x: lowbar.min>` / `with { field: "age" }` |
| `includes` | Check membership | `with { value: 42 }` |
| `every` | All match? | `with { active: true }` |
| `some` | Any match? | `with { role: "admin" }` |
| `without` | Remove specific values | `with { values: [3, 5, 7] }` |
| `union` | Combine (unique) | `with { other: [4, 5, 6] }` |
| `intersection` | Common values | `with { other: [3, 4, 5] }` |
| `difference` | Values not in other | `with { other: [3, 4, 5] }` |
| `zip` | Pair at positions | `with { other: [1, 2, 3] }` |
| `unzip` | Transpose pairs | `<x: lowbar.unzip>` |
| `object` | Pairs to object | `<x: lowbar.object>` |
| `chunk` | Split into chunks | `with { size: 3 }` |
| `indexof` | Find position | `with { value: "x" }` |
| `last-indexof` | Find last position | `with { value: "x" }` |
| `sortedindex` | Insertion point | `with { value: 5 }` |
| `findindex` | Index by properties | `with { role: "admin" }` |
| `findlast-index` | Last index by properties | `with { role: "admin" }` |

### Numeric (3 qualifiers)

| Qualifier | Description | Example |
|-----------|-------------|---------|
| `sum` | Sum numeric values | `<total: lowbar.sum>` |
| `avg` | Average of values | `<mean: lowbar.avg>` |
| `reduce` | Fold with operation | `with { op: "+" }` / `with { op: "*" }` / `with { op: "join", separator: ", " }` |

### Objects (14 qualifiers)

| Qualifier | Description | Example |
|-----------|-------------|---------|
| `keys` | All keys (sorted) | `<k: lowbar.keys>` |
| `values` | All values | `<v: lowbar.values>` |
| `pairs` | To [[key, value], ...] | `<p: lowbar.pairs>` |
| `invert` | Swap keys and values | `<inv: lowbar.invert>` |
| `pick` | Keep specified keys | `with { keys: ["name", "email"] }` |
| `omit` | Remove specified keys | `with { keys: ["password"] }` |
| `defaults` | Fill missing keys | `with { timeout: 30, debug: false }` |
| `extend` | Merge (overwrite) | `with { port: 9090, debug: true }` |
| `clone` | Shallow copy | `<copy: lowbar.clone>` |
| `has` | Key exists? | `with { key: "host" }` |
| `get` | Nested dot path | `with { path: "user.address.city" }` |
| `findkey` | Find key by value | `with { value: "#ff0000" }` |
| `mapobject` | Rename keys | `with { old: "firstName", new: "name" }` |
| `ismatch` | Has properties? | `with { host: "localhost" }` |

### Type Checks (9 qualifiers)

| Qualifier | Description |
|-----------|-------------|
| `isempty` | True for `[]`, `""`, `{}`, nil |
| `isarray` | True for lists |
| `isstring` | True for strings |
| `isnumber` | True for Int or Double |
| `isboolean` | True for booleans |
| `isobject` | True for objects/dicts |
| `isnull` | True for nil |
| `isfinite` | True for finite numbers |
| `isequal` | Deep equality: `with { other: 42 }` |

### Utility (6 qualifiers)

| Qualifier | Description | Example |
|-----------|-------------|---------|
| `identity` | Pass-through | `<same: lowbar.identity>` |
| `escape` | HTML-escape | `<safe: lowbar.escape>` |
| `unescape` | Reverse HTML-escape | `<raw: lowbar.unescape>` |
| `join` | List to string | `with { separator: ", " }` |
| `split` | String to list | `with { separator: ":" }` |
| `tap` | Pass-through (debug) | `<x: lowbar.tap>` |

### Actions (5)

| Action | Description | Example |
|--------|-------------|---------|
| `Range` | Generate integer list | `Lowbar.Range the <n> with { stop: 10 }.` |
| `Random` | Random integer | `Lowbar.Random the <n> with { min: 1, max: 6 }.` |
| `UniqueId` | Unique identifier | `Lowbar.UniqueId the <id> with { prefix: "u_" }.` |
| `Now` | Unix timestamp (ms) | `Lowbar.Now the <ts> for the <system>.` |
| `Times` | Repeat a value | `Lowbar.Times the <stars> with { n: 5, value: "*" }.` |

## Testing

```bash
aro test .
```

The `tests/` directory contains 67 test files with 155 test cases covering all Lowbar functions.

## Building from Source

```bash
cd Plugins/lowbar
swift build -c release
```

Requires Swift 6.2+, ARO 0.9.1+, and the [ARO Plugin SDK](https://github.com/arolang/aro-plugin-sdk-swift).

## Acknowledgments

Lowbar is a clone of [Underscore.js](https://underscorejs.org) by Jeremy Ashkenas and the many contributors who have maintained it since 2009. The function names, semantics, and organization are modeled directly after underscore's API, adapted to ARO's declarative qualifier syntax. Thank you to the underscore.js team for their outstanding work for the JavaScript community — Lowbar carries that spirit into the ARO community.

## License

MIT
