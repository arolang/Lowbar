// ============================================================
// LowbarPlugin.swift
// Lowbar — The utility toolkit for ARO
// ============================================================
//
// A comprehensive utility plugin providing 60+ qualifiers and
// actions modeled after underscore.js. Provides collection
// manipulation, object utilities, type checks, and generators.
//
// Usage in ARO:
//   Compute the <first: lowbar.first> from the <items>.
//   Compute the <names: lowbar.pluck> from the <users> with { field: "name" }.
//   Lowbar.Range the <numbers> with { stop: 10 }.

import Foundation
import AROPluginKit

// MARK: - Helpers

private func anyEquals(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (nil, nil): return true
    case (nil, _), (_, nil): return false
    case (let a as String, let b as String): return a == b
    case (let a as Int, let b as Int): return a == b
    case (let a as Double, let b as Double): return a == b
    case (let a as Bool, let b as Bool): return a == b
    case (let a as Int, let b as Double): return Double(a) == b
    case (let a as Double, let b as Int): return a == Double(b)
    default: return false
    }
}

private func anyToDouble(_ value: Any?) -> Double? {
    switch value {
    case let d as Double: return d
    case let i as Int: return Double(i)
    case let s as String: return Double(s)
    default: return nil
    }
}

private func anyToString(_ value: Any?) -> String {
    switch value {
    case nil: return ""
    case let s as String: return s
    case let i as Int: return String(i)
    case let d as Double: return String(d)
    case let b as Bool: return String(b)
    default: return String(describing: value!)
    }
}

private func isFalsy(_ value: Any?) -> Bool {
    switch value {
    case nil: return true
    case let b as Bool: return !b
    case let i as Int: return i == 0
    case let d as Double: return d == 0
    case let s as String: return s.isEmpty
    case let a as [Any]: return a.isEmpty
    case let d as [String: Any]: return d.isEmpty
    default: return false
    }
}

private func compareLessThan(_ a: Any?, _ b: Any?) -> Bool {
    if let da = anyToDouble(a), let db = anyToDouble(b) { return da < db }
    return anyToString(a) < anyToString(b)
}

private func fieldValue(_ item: Any, _ field: String) -> Any? {
    (item as? [String: Any])?[field]
}

private func matchesProps(_ item: Any, _ props: Params) -> Bool {
    guard let dict = item as? [String: Any] else { return false }
    for key in props.keys {
        if !anyEquals(dict[key], props[key]) { return false }
    }
    return true
}

private func arrayContains(_ array: [Any], _ value: Any?) -> Bool {
    array.contains { anyEquals($0, value) }
}

private func deepFlatten(_ array: [Any]) -> [Any] {
    var result: [Any] = []
    for item in array {
        if let nested = item as? [Any] {
            result.append(contentsOf: deepFlatten(nested))
        } else {
            result.append(item)
        }
    }
    return result
}

private func resolveNestedPath(_ dict: [String: Any], _ path: String) -> Any? {
    let parts = path.split(separator: ".").map(String.init)
    var current: Any = dict
    for part in parts {
        guard let d = current as? [String: Any], let next = d[part] else { return nil }
        current = next
    }
    return current
}

private func generateUniqueId() -> String {
    UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
}

// MARK: - Plugin Registration

@AROExport
private let plugin = AROPlugin(name: "lowbar", version: "0.2.0", handle: "Lowbar")

    // ================================================================
    // MARK: — Collection Qualifiers
    // ================================================================

    // --- first ---
    // Compute the <head: lowbar.first> from the <items>.
    // Compute the <top-three: lowbar.first> from the <items> with { n: 3 }.
    .qualifier("first", inputTypes: ["List"],
               description: "Return the first element, or first N elements with { n }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("first requires a non-empty list") }
        if let n = p.with.int("n") {
            return .success(Array(arr.prefix(max(0, n))))
        }
        return .success(arr[0])
    }

    // --- initial ---
    // Compute the <all-but-last: lowbar.initial> from the <items>.
    // Compute the <all-but-last-3: lowbar.initial> from the <items> with { n: 3 }.
    .qualifier("initial", inputTypes: ["List"],
               description: "Return everything except the last element (or last N with { n })",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("initial requires a non-empty list") }
        let drop = p.with.int("n") ?? 1
        let end = max(0, arr.count - drop)
        return .success(Array(arr.prefix(end)))
    }

    // --- last ---
    // Compute the <tail: lowbar.last> from the <items>.
    // Compute the <last-two: lowbar.last> from the <items> with { n: 2 }.
    .qualifier("last", inputTypes: ["List"],
               description: "Return the last element, or last N elements with { n }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("last requires a non-empty list") }
        if let n = p.with.int("n") {
            return .success(Array(arr.suffix(max(0, n))))
        }
        return .success(arr[arr.count - 1])
    }

    // --- rest ---
    // Compute the <remaining: lowbar.rest> from the <items>.
    // Compute the <from-third: lowbar.rest> from the <items> with { n: 3 }.
    .qualifier("rest", inputTypes: ["List"],
               description: "Return everything except the first element (or from index N with { n })",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("rest requires a list") }
        let start = p.with.int("n") ?? 1
        if start >= arr.count { return .success([Any]()) }
        return .success(Array(arr.dropFirst(max(0, start))))
    }

    // --- compact ---
    // Compute the <truthy: lowbar.compact> from the <mixed-values>.
    .qualifier("compact", inputTypes: ["List"],
               description: "Remove all falsy values (nil, false, 0, empty string)") { p in
        guard let arr = p.arrayValue else { return .failure("compact requires a list") }
        return .success(arr.filter { !isFalsy($0) })
    }

    // --- flatten ---
    // Compute the <flat: lowbar.flatten> from the <nested-list>.
    // Compute the <shallow: lowbar.flatten> from the <nested-list> with { deep: false }.
    .qualifier("flatten", inputTypes: ["List"],
               description: "Flatten nested arrays (deep by default, shallow with { deep: false })",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("flatten requires a list") }
        let deep = p.with.bool("deep") ?? true
        if deep {
            return .success(deepFlatten(arr))
        }
        var result: [Any] = []
        for item in arr {
            if let nested = item as? [Any] { result.append(contentsOf: nested) }
            else { result.append(item) }
        }
        return .success(result)
    }

    // --- without ---
    // Compute the <filtered: lowbar.without> from the <numbers> with { values: [3, 5] }.
    .qualifier("without", inputTypes: ["List"],
               description: "Return list without specified values; use with { values: [...] }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("without requires a list") }
        guard let exclude = p.with.array("values") else { return .failure("without requires with { values: [...] }") }
        return .success(arr.filter { item in !exclude.contains { anyEquals($0, item) } })
    }

    // --- union ---
    // Compute the <combined: lowbar.union> from the <list-a> with { other: [4, 5, 6] }.
    .qualifier("union", inputTypes: ["List"],
               description: "Union with another list (unique values); use with { other: [...] }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("union requires a list") }
        guard let other = p.with.array("other") else { return .failure("union requires with { other: [...] }") }
        var result = arr
        for item in other {
            if !arrayContains(result, item) { result.append(item) }
        }
        return .success(result)
    }

    // --- intersection ---
    // Compute the <common: lowbar.intersection> from the <list-a> with { other: [3, 4, 5] }.
    .qualifier("intersection", inputTypes: ["List"],
               description: "Values present in both lists; use with { other: [...] }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("intersection requires a list") }
        guard let other = p.with.array("other") else { return .failure("intersection requires with { other: [...] }") }
        return .success(arr.filter { item in arrayContains(other, item) })
    }

    // --- difference ---
    // Compute the <unique-to-a: lowbar.difference> from the <list-a> with { other: [3, 4, 5] }.
    .qualifier("difference", inputTypes: ["List"],
               description: "Values in this list but not the other; use with { other: [...] }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("difference requires a list") }
        guard let other = p.with.array("other") else { return .failure("difference requires with { other: [...] }") }
        return .success(arr.filter { item in !arrayContains(other, item) })
    }

    // --- uniq ---
    // Compute the <unique: lowbar.uniq> from the <numbers>.
    // Compute the <unique-users: lowbar.uniq> from the <users> with { field: "role" }.
    .qualifier("uniq", inputTypes: ["List"],
               description: "Remove duplicate values (optionally by field with { field })",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("uniq requires a list") }
        let field = p.with.string("field")
        var seen: [String] = []
        var result: [Any] = []
        for item in arr {
            let key: String
            if let f = field {
                key = anyToString(fieldValue(item, f))
            } else {
                key = anyToString(item)
            }
            if !seen.contains(key) {
                seen.append(key)
                result.append(item)
            }
        }
        return .success(result)
    }

    // --- zip ---
    // Compute the <zipped: lowbar.zip> from ["a", "b", "c"] with { other: [1, 2, 3] }.
    .qualifier("zip", inputTypes: ["List"],
               description: "Merge arrays at corresponding positions; use with { other: [...] }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("zip requires a list") }
        guard let other = p.with.array("other") else { return .failure("zip requires with { other: [...] }") }
        let len = max(arr.count, other.count)
        var result: [Any] = []
        for i in 0..<len {
            let a: Any = i < arr.count ? arr[i] : "nil"
            let b: Any = i < other.count ? other[i] : "nil"
            result.append([a, b] as [Any])
        }
        return .success(result)
    }

    // --- unzip ---
    // Compute the <columns: lowbar.unzip> from [["a", 1], ["b", 2], ["c", 3]].
    .qualifier("unzip", inputTypes: ["List"],
               description: "Transpose array of pairs/tuples into separate arrays") { p in
        guard let arr = p.arrayValue else { return .failure("unzip requires a list") }
        guard let firstPair = arr.first as? [Any] else { return .failure("unzip requires a list of arrays") }
        let width = firstPair.count
        var columns = Array(repeating: [Any](), count: width)
        for item in arr {
            guard let pair = item as? [Any] else { continue }
            for (i, val) in pair.enumerated() where i < width {
                columns[i].append(val)
            }
        }
        return .success(columns)
    }

    // --- object ---
    // Compute the <dict: lowbar.object> from [["name", "Alice"], ["age", 30]].
    .qualifier("object", inputTypes: ["List"],
               description: "Convert [[key, value], ...] pairs into an object") { p in
        guard let arr = p.arrayValue else { return .failure("object requires a list") }
        var dict: [String: Any] = [:]
        for item in arr {
            if let pair = item as? [Any], pair.count >= 2 {
                dict[anyToString(pair[0])] = pair[1]
            }
        }
        return .success(dict)
    }

    // --- chunk ---
    // Compute the <chunks: lowbar.chunk> from the <items> with { size: 3 }.
    .qualifier("chunk", inputTypes: ["List"],
               description: "Split list into chunks of given size; use with { size }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("chunk requires a list") }
        let size = p.with.int("size") ?? 1
        guard size > 0 else { return .failure("chunk size must be positive") }
        var result: [Any] = []
        var i = 0
        while i < arr.count {
            result.append(Array(arr[i..<min(i + size, arr.count)]) as [Any])
            i += size
        }
        return .success(result)
    }

    // --- shuffle ---
    // Compute the <shuffled: lowbar.shuffle> from the <items>.
    // Compute the <anagram: lowbar.shuffle> from "hello".
    .qualifier("shuffle", inputTypes: ["List", "String"],
               description: "Return a shuffled copy using Fisher-Yates algorithm") { p in
        if let arr = p.arrayValue { return .success(arr.shuffled()) }
        if let str = p.stringValue { return .success(String(str.shuffled())) }
        return .failure("shuffle requires a list or string")
    }

    // --- sample ---
    // Compute the <picked: lowbar.sample> from the <items>.
    // Compute the <three-picks: lowbar.sample> from the <items> with { n: 3 }.
    .qualifier("sample", inputTypes: ["List"],
               description: "Return a random element, or N random elements with { n }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("sample requires a non-empty list") }
        if let n = p.with.int("n") {
            return .success(Array(arr.shuffled().prefix(min(n, arr.count))))
        }
        return .success(arr[Int.random(in: 0..<arr.count)])
    }

    // --- size ---
    // Compute the <count: lowbar.size> from the <items>.
    // Compute the <len: lowbar.size> from "hello".
    .qualifier("size", inputTypes: ["List", "String", "Object"],
               description: "Return the number of elements/characters/keys") { p in
        if let arr = p.arrayValue { return .success(arr.count) }
        if let str = p.stringValue { return .success(str.count) }
        if let dict = p.dictValue { return .success(dict.count) }
        return .failure("size requires a list, string, or object")
    }

    // --- reverse ---
    // Compute the <backwards: lowbar.reverse> from the <items>.
    // Compute the <reversed: lowbar.reverse> from "hello".
    .qualifier("reverse", inputTypes: ["List", "String"],
               description: "Reverse elements in a list or characters in a string") { p in
        if let arr = p.arrayValue { return .success(Array(arr.reversed())) }
        if let str = p.stringValue { return .success(String(str.reversed())) }
        return .failure("reverse requires a list or string")
    }

    // --- to-array ---
    // Compute the <chars: lowbar.toarray> from "hello".
    // Compute the <vals: lowbar.toarray> from the <config>.
    .qualifier("toarray", inputTypes: ["List", "String", "Object"],
               description: "Convert value to array (string to chars, object to values)") { p in
        if let arr = p.arrayValue { return .success(arr) }
        if let str = p.stringValue { return .success(str.map(String.init)) }
        if let dict = p.dictValue { return .success(Array(dict.values)) }
        return .failure("to-array requires a list, string, or object")
    }

    // ================================================================
    // MARK: — Collection Qualifiers with Field/Property Params
    // ================================================================

    // --- sort-by ---
    // Compute the <by-age: lowbar.sortby> from the <users> with { field: "age" }.
    // Compute the <by-age-desc: lowbar.sortby> from the <users> with { field: "age", order: "desc" }.
    .qualifier("sortby", inputTypes: ["List"],
               description: "Sort by field; with { field, order: desc }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("sort-by requires a list") }
        guard let field = p.with.string("field") else { return .failure("sort-by requires with { field }") }
        let desc = p.with.string("order") == "desc"
        let sorted = arr.sorted { a, b in
            let va = fieldValue(a, field)
            let vb = fieldValue(b, field)
            return desc ? compareLessThan(vb, va) : compareLessThan(va, vb)
        }
        return .success(sorted)
    }

    // --- group-by ---
    // Compute the <by-role: lowbar.groupby> from the <users> with { field: "role" }.
    .qualifier("groupby", inputTypes: ["List"],
               description: "Group list of objects by field value; use with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("group-by requires a list") }
        guard let field = p.with.string("field") else { return .failure("group-by requires with { field }") }
        var groups: [String: [Any]] = [:]
        for item in arr {
            let key = anyToString(fieldValue(item, field))
            groups[key, default: []].append(item)
        }
        return .success(groups)
    }

    // --- count-by ---
    // Compute the <role-counts: lowbar.countby> from the <users> with { field: "role" }.
    .qualifier("countby", inputTypes: ["List"],
               description: "Count items per group; use with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("count-by requires a list") }
        guard let field = p.with.string("field") else { return .failure("count-by requires with { field }") }
        var counts: [String: Int] = [:]
        for item in arr {
            let key = anyToString(fieldValue(item, field))
            counts[key, default: 0] += 1
        }
        return .success(counts)
    }

    // --- index-by ---
    // Compute the <user-lookup: lowbar.indexby> from the <users> with { field: "name" }.
    .qualifier("indexby", inputTypes: ["List"],
               description: "Create object lookup indexed by field; use with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("index-by requires a list") }
        guard let field = p.with.string("field") else { return .failure("index-by requires with { field }") }
        var index: [String: Any] = [:]
        for item in arr {
            let key = anyToString(fieldValue(item, field))
            index[key] = item
        }
        return .success(index)
    }

    // --- pluck ---
    // Compute the <names: lowbar.pluck> from the <users> with { field: "name" }.
    .qualifier("pluck", inputTypes: ["List"],
               description: "Extract a single field from each object; use with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("pluck requires a list") }
        guard let field = p.with.string("field") else { return .failure("pluck requires with { field }") }
        return .success(arr.compactMap { fieldValue($0, field) })
    }

    // --- where ---
    // Compute the <admins: lowbar.matching> from the <users> with { role: "admin" }.
    .qualifier("matching", inputTypes: ["List"],
               description: "Filter objects matching all with-clause properties",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("where requires a list") }
        let props = p.with
        if props.isEmpty { return .success(arr) }
        return .success(arr.filter { matchesProps($0, props) })
    }

    // --- find-where ---
    // Compute the <first-admin: lowbar.findwhere> from the <users> with { role: "admin" }.
    .qualifier("findwhere", inputTypes: ["List"],
               description: "Return first object matching all with-clause properties",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("find-where requires a list") }
        let props = p.with
        if props.isEmpty { return .failure("find-where requires properties in with-clause") }
        if let found = arr.first(where: { matchesProps($0, props) }) {
            return .success(found)
        }
        return .success("nil" as Any)
    }

    // --- reject-where ---
    // Compute the <non-admins: lowbar.rejectwhere> from the <users> with { role: "admin" }.
    .qualifier("rejectwhere", inputTypes: ["List"],
               description: "Return objects NOT matching with-clause properties (inverse of where)",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("reject-where requires a list") }
        let props = p.with
        if props.isEmpty { return .success(arr) }
        return .success(arr.filter { !matchesProps($0, props) })
    }

    // --- partition ---
    // Compute the <split: lowbar.partition> from the <users> with { active: true }.
    .qualifier("partition", inputTypes: ["List"],
               description: "Split list into [matching, non-matching] by with-clause properties",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("partition requires a list") }
        let props = p.with
        if props.isEmpty { return .failure("partition requires properties in with-clause") }
        var pass: [Any] = []
        var fail: [Any] = []
        for item in arr {
            if matchesProps(item, props) { pass.append(item) } else { fail.append(item) }
        }
        return .success([pass, fail] as [Any])
    }

    // --- max ---
    // Compute the <biggest: lowbar.max> from the <numbers>.
    // Compute the <oldest: lowbar.max> from the <users> with { field: "age" }.
    .qualifier("max", inputTypes: ["List"],
               description: "Return maximum value, optionally by field with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("max requires a non-empty list") }
        let field = p.with.string("field")
        var best = arr[0]
        for item in arr.dropFirst() {
            let a: Any = field != nil ? fieldValue(item, field!) as Any : item
            let b: Any = field != nil ? fieldValue(best, field!) as Any : best
            if compareLessThan(b, a) { best = item }
        }
        return .success(best)
    }

    // --- min ---
    // Compute the <smallest: lowbar.min> from the <numbers>.
    // Compute the <youngest: lowbar.min> from the <users> with { field: "age" }.
    .qualifier("min", inputTypes: ["List"],
               description: "Return minimum value, optionally by field with { field }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue, !arr.isEmpty else { return .failure("min requires a non-empty list") }
        let field = p.with.string("field")
        var best = arr[0]
        for item in arr.dropFirst() {
            let a: Any = field != nil ? fieldValue(item, field!) as Any : item
            let b: Any = field != nil ? fieldValue(best, field!) as Any : best
            if compareLessThan(a, b) { best = item }
        }
        return .success(best)
    }

    // --- contains ---
    // Compute the <found: lowbar.includes> from the <items> with { value: "needle" }.
    .qualifier("includes", inputTypes: ["List"],
               description: "Check if list contains a value; use with { value }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("contains requires a list") }
        guard let val = p.with["value"] else { return .failure("contains requires with { value }") }
        return .success(arrayContains(arr, val))
    }

    // --- every ---
    // Compute the <all-active: lowbar.every> from the <users> with { active: true }.
    .qualifier("every", inputTypes: ["List"],
               description: "Return true if all objects match with-clause properties",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("every requires a list") }
        let props = p.with
        if props.isEmpty {
            return .success(arr.allSatisfy { !isFalsy($0) })
        }
        return .success(arr.allSatisfy { matchesProps($0, props) })
    }

    // --- some ---
    // Compute the <any-admin: lowbar.some> from the <users> with { role: "admin" }.
    .qualifier("some", inputTypes: ["List"],
               description: "Return true if any object matches with-clause properties",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("some requires a list") }
        let props = p.with
        if props.isEmpty {
            return .success(arr.contains { !isFalsy($0) })
        }
        return .success(arr.contains { matchesProps($0, props) })
    }

    // --- index-of ---
    // Compute the <pos: lowbar.indexof> from the <items> with { value: "target" }.
    .qualifier("indexof", inputTypes: ["List"],
               description: "Return index of first occurrence, or -1; use with { value }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("index-of requires a list") }
        guard let val = p.with["value"] else { return .failure("index-of requires with { value }") }
        let idx = arr.firstIndex { anyEquals($0, val) } ?? -1
        return .success(idx)
    }

    // --- last-index-of ---
    // Compute the <last-pos: lowbar.last-indexof> from the <items> with { value: "target" }.
    .qualifier("last-indexof", inputTypes: ["List"],
               description: "Return index of last occurrence, or -1; use with { value }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("last-index-of requires a list") }
        guard let val = p.with["value"] else { return .failure("last-index-of requires with { value }") }
        let idx = arr.lastIndex { anyEquals($0, val) } ?? -1
        return .success(idx)
    }

    // --- sorted-index ---
    // Compute the <insert-at: lowbar.sortedindex> from the <sorted-list> with { value: 5 }.
    .qualifier("sortedindex", inputTypes: ["List"],
               description: "Find insertion index in sorted array; use with { value }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("sorted-index requires a list") }
        guard let val = p.with["value"] else { return .failure("sorted-index requires with { value }") }
        var idx = 0
        for item in arr {
            if compareLessThan(item, val) { idx += 1 } else { break }
        }
        return .success(idx)
    }

    // --- find-index ---
    // Compute the <admin-idx: lowbar.findindex> from the <users> with { role: "admin" }.
    .qualifier("findindex", inputTypes: ["List"],
               description: "Return index of first object matching with-clause properties, or -1",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("find-index requires a list") }
        let props = p.with
        if props.isEmpty { return .failure("find-index requires properties in with-clause") }
        let idx = arr.firstIndex { matchesProps($0, props) } ?? -1
        return .success(idx)
    }

    // --- find-last-index ---
    // Compute the <last-admin-idx: lowbar.findlast-index> from the <users> with { role: "admin" }.
    .qualifier("findlast-index", inputTypes: ["List"],
               description: "Return index of last object matching with-clause properties, or -1",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("find-last-index requires a list") }
        let props = p.with
        if props.isEmpty { return .failure("find-last-index requires properties in with-clause") }
        let idx = arr.lastIndex { matchesProps($0, props) } ?? -1
        return .success(idx)
    }

    // ================================================================
    // MARK: — Numeric Collection Qualifiers
    // ================================================================

    // --- sum ---
    // Compute the <total: lowbar.sum> from the <numbers>.
    .qualifier("sum", inputTypes: ["List"],
               description: "Sum all numeric values in the list") { p in
        guard let arr = p.arrayValue else { return .failure("sum requires a list") }
        let total = arr.compactMap { anyToDouble($0) }.reduce(0.0, +)
        if total == total.rounded() && total < Double(Int.max) { return .success(Int(total)) }
        return .success(total)
    }

    // --- avg ---
    // Compute the <average: lowbar.avg> from the <scores>.
    .qualifier("avg", inputTypes: ["List"],
               description: "Calculate the average of numeric values") { p in
        guard let arr = p.arrayValue else { return .failure("avg requires a list") }
        let nums = arr.compactMap { anyToDouble($0) }
        guard !nums.isEmpty else { return .failure("avg requires numeric values") }
        return .success(nums.reduce(0.0, +) / Double(nums.count))
    }

    // --- reduce ---
    // Compute the <total: lowbar.reduce> from the <numbers> with { op: "+" }.
    // Compute the <product: lowbar.reduce> from the <numbers> with { op: "*" }.
    // Compute the <csv: lowbar.reduce> from the <names> with { op: "join", separator: " | " }.
    .qualifier("reduce", inputTypes: ["List"],
               description: "Reduce with operation; with { op: + or * or join, separator }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("reduce requires a list") }
        let op = p.with.string("op") ?? "+"
        switch op {
        case "+":
            let total = arr.compactMap { anyToDouble($0) }.reduce(anyToDouble(p.with["initial"]) ?? 0.0, +)
            if total == total.rounded() && abs(total) < Double(Int.max) { return .success(Int(total)) }
            return .success(total)
        case "*":
            let total = arr.compactMap { anyToDouble($0) }.reduce(anyToDouble(p.with["initial"]) ?? 1.0, *)
            if total == total.rounded() && abs(total) < Double(Int.max) { return .success(Int(total)) }
            return .success(total)
        case "join":
            let sep = p.with.string("separator") ?? ","
            return .success(arr.map { anyToString($0) }.joined(separator: sep))
        default:
            return .failure("reduce op must be +, *, or join")
        }
    }

    // ================================================================
    // MARK: — Object Qualifiers
    // ================================================================

    // --- keys ---
    // Compute the <field-names: lowbar.keys> from the <config>.
    .qualifier("keys", inputTypes: ["Object"],
               description: "Return all keys of an object") { p in
        guard let dict = p.dictValue else { return .failure("keys requires an object") }
        return .success(Array(dict.keys).sorted())
    }

    // --- values ---
    // Compute the <field-values: lowbar.values> from the <config>.
    .qualifier("values", inputTypes: ["Object"],
               description: "Return all values of an object") { p in
        guard let dict = p.dictValue else { return .failure("values requires an object") }
        return .success(Array(dict.values))
    }

    // --- pairs ---
    // Compute the <entries: lowbar.pairs> from the <config>.
    .qualifier("pairs", inputTypes: ["Object"],
               description: "Convert object to [[key, value], ...] pairs") { p in
        guard let dict = p.dictValue else { return .failure("pairs requires an object") }
        return .success(dict.sorted(by: { $0.key < $1.key }).map { [$0.key, $0.value] as [Any] })
    }

    // --- invert ---
    // Compute the <swapped: lowbar.invert> from the <color-codes>.
    .qualifier("invert", inputTypes: ["Object"],
               description: "Swap keys and values in an object") { p in
        guard let dict = p.dictValue else { return .failure("invert requires an object") }
        var result: [String: Any] = [:]
        for (k, v) in dict { result[anyToString(v)] = k }
        return .success(result)
    }

    // --- pick ---
    // Compute the <subset: lowbar.pick> from the <user> with { keys: ["name", "email"] }.
    .qualifier("pick", inputTypes: ["Object"],
               description: "Return object with only specified keys; use with { keys: [...] }",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("pick requires an object") }
        guard let keys = p.with.array("keys") else { return .failure("pick requires with { keys: [...] }") }
        let keySet = Set(keys.map { anyToString($0) })
        return .success(dict.filter { keySet.contains($0.key) })
    }

    // --- omit ---
    // Compute the <safe: lowbar.omit> from the <user> with { keys: ["password", "secret"] }.
    .qualifier("omit", inputTypes: ["Object"],
               description: "Return object without specified keys; use with { keys: [...] }",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("omit requires an object") }
        guard let keys = p.with.array("keys") else { return .failure("omit requires with { keys: [...] }") }
        let keySet = Set(keys.map { anyToString($0) })
        return .success(dict.filter { !keySet.contains($0.key) })
    }

    // --- defaults ---
    // Compute the <full-config: lowbar.defaults> from the <config> with { timeout: 30, debug: false }.
    .qualifier("defaults", inputTypes: ["Object"],
               description: "Fill undefined properties with with-clause defaults",
               acceptsParameters: true) { p in
        guard var dict = p.dictValue else { return .failure("defaults requires an object") }
        for key in p.with.keys {
            if dict[key] == nil { dict[key] = p.with[key] }
        }
        return .success(dict)
    }

    // --- extend ---
    // Compute the <merged: lowbar.extend> from the <config> with { port: 9090, debug: true }.
    .qualifier("extend", inputTypes: ["Object"],
               description: "Merge with-clause properties into object (overwrites existing)",
               acceptsParameters: true) { p in
        guard var dict = p.dictValue else { return .failure("extend requires an object") }
        for key in p.with.keys {
            dict[key] = p.with[key]
        }
        return .success(dict)
    }

    // --- clone ---
    // Compute the <copy: lowbar.clone> from the <config>.
    .qualifier("clone", inputTypes: ["Object", "List"],
               description: "Create a shallow copy of the object or list") { p in
        if let dict = p.dictValue { return .success(dict) }
        if let arr = p.arrayValue { return .success(arr) }
        return .failure("clone requires an object or list")
    }

    // --- has ---
    // Compute the <exists: lowbar.has> from the <config> with { key: "host" }.
    .qualifier("has", inputTypes: ["Object"],
               description: "Check if object contains a key; use with { key }",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("has requires an object") }
        guard let key = p.with.string("key") else { return .failure("has requires with { key }") }
        return .success(dict[key] != nil)
    }

    // --- get ---
    // Compute the <city: lowbar.get> from the <user> with { path: "address.city" }.
    // Compute the <fallback: lowbar.get> from the <user> with { path: "phone", default: "N/A" }.
    .qualifier("get", inputTypes: ["Object"],
               description: "Get value at nested dot path; use with { path, default }",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("get requires an object") }
        guard let path = p.with.string("path") else { return .failure("get requires with { path }") }
        if let val = resolveNestedPath(dict, path) { return .success(val) }
        if let def = p.with["default"] { return .success(def) }
        return .success("nil" as Any)
    }

    // --- find-key ---
    // Compute the <color-name: lowbar.findkey> from the <colors> with { value: "#ff0000" }.
    .qualifier("findkey", inputTypes: ["Object"],
               description: "Find first key whose value matches; use with { value }",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("find-key requires an object") }
        guard let target = p.with["value"] else { return .failure("find-key requires with { value }") }
        if let key = dict.first(where: { anyEquals($0.value, target) })?.key {
            return .success(key)
        }
        return .success("nil" as Any)
    }

    // --- map-object ---
    // Compute the <renamed: lowbar.mapobject> from the <obj> with { from: "old_name", to: "new_name" }.
    // Compute the <remapped: lowbar.mapobject> from the <obj> with { map: { old: "new", x: "y" } }.
    .qualifier("mapobject", inputTypes: ["Object"],
               description: "Rename keys; with { old, new } or { map: {old: new} }",
               acceptsParameters: true) { p in
        guard var dict = p.dictValue else { return .failure("map-object requires an object") }
        if let from = p.with.string("old"), let to = p.with.string("new") {
            if let val = dict.removeValue(forKey: from) { dict[to] = val }
            return .success(dict)
        }
        if let mapping = p.with.dict("map") {
            var result: [String: Any] = [:]
            for (k, v) in dict {
                let newKey = (mapping[k] as? String) ?? k
                result[newKey] = v
            }
            return .success(result)
        }
        return .failure("map-object requires with { from, to } or { map: {...} }")
    }

    // --- is-match ---
    // Compute the <matches: lowbar.ismatch> from the <config> with { host: "localhost" }.
    .qualifier("ismatch", inputTypes: ["Object"],
               description: "Check if object contains all with-clause key-value pairs",
               acceptsParameters: true) { p in
        guard let dict = p.dictValue else { return .failure("is-match requires an object") }
        let props = p.with
        if props.isEmpty { return .success(true) }
        for key in props.keys {
            if !anyEquals(dict[key], props[key]) { return .success(false) }
        }
        return .success(true)
    }

    // ================================================================
    // MARK: — Type Check Qualifiers
    // ================================================================

    // --- is-empty ---
    // Compute the <empty: lowbar.isempty> from the <items>.
    .qualifier("isempty", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is empty (list, string, object, nil)") { p in
        if let arr = p.arrayValue { return .success(arr.isEmpty) }
        if let str = p.stringValue { return .success(str.isEmpty) }
        if let dict = p.dictValue { return .success(dict.isEmpty) }
        if p.rawValue == nil { return .success(true) }
        return .success(false)
    }

    // --- is-array ---
    // Compute the <check: lowbar.isarray> from the <value>.
    .qualifier("isarray", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is a list/array") { p in
        .success(p.arrayValue != nil)
    }

    // --- is-string ---
    // Compute the <check: lowbar.isstring> from the <value>.
    .qualifier("isstring", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is a string") { p in
        .success(p.rawValue is String)
    }

    // --- is-number ---
    // Compute the <check: lowbar.isnumber> from the <value>.
    .qualifier("isnumber", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is a number (Int or Double)") { p in
        .success(p.rawValue is Int || p.rawValue is Double)
    }

    // --- is-boolean ---
    // Compute the <check: lowbar.isboolean> from the <value>.
    .qualifier("isboolean", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is a boolean") { p in
        .success(p.rawValue is Bool)
    }

    // --- is-object ---
    // Compute the <check: lowbar.isobject> from the <value>.
    .qualifier("isobject", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is an object/dictionary") { p in
        .success(p.dictValue != nil)
    }

    // --- is-null ---
    // Compute the <check: lowbar.isnull> from the <value>.
    .qualifier("isnull", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return true if the value is null/nil") { p in
        .success(p.rawValue == nil)
    }

    // --- is-finite ---
    // Compute the <finite: lowbar.isfinite> from the <number>.
    .qualifier("isfinite", inputTypes: ["Int", "Double"],
               description: "Return true if the value is a finite number") { p in
        if let d = p.doubleValue { return .success(d.isFinite) }
        if p.intValue != nil { return .success(true) }
        return .success(false)
    }

    // --- is-equal ---
    // Compute the <equal: lowbar.isequal> from the <a> with { other: 42 }.
    .qualifier("isequal", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Deep equality comparison; use with { other }",
               acceptsParameters: true) { p in
        guard let other = p.with["other"] else { return .failure("is-equal requires with { other }") }
        return .success(anyEquals(p.rawValue, other))
    }

    // ================================================================
    // MARK: — Utility Qualifiers
    // ================================================================

    // --- identity ---
    // Compute the <same: lowbar.identity> from the <value>.
    .qualifier("identity", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Return the same value (pass-through)") { p in
        guard let val = p.rawValue else { return .success("nil" as Any) }
        return .success(val)
    }

    // --- escape ---
    // Compute the <safe-html: lowbar.escape> from "<script>alert('xss')</script>".
    .qualifier("escape", inputTypes: ["String"],
               description: "Escape HTML entities (ampersand, angle brackets, quotes)") { p in
        guard let str = p.stringValue else { return .failure("escape requires a string") }
        let escaped = str
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
        return .success(escaped)
    }

    // --- unescape ---
    // Compute the <raw: lowbar.unescape> from "&lt;b&gt;bold&lt;/b&gt;".
    .qualifier("unescape", inputTypes: ["String"],
               description: "Unescape HTML entities back to characters") { p in
        guard let str = p.stringValue else { return .failure("unescape requires a string") }
        let unescaped = str
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
        return .success(unescaped)
    }

    // --- join ---
    // Compute the <csv: lowbar.join> from the <names> with { separator: ", " }.
    .qualifier("join", inputTypes: ["List"],
               description: "Join list elements into a string; with { separator }",
               acceptsParameters: true) { p in
        guard let arr = p.arrayValue else { return .failure("join requires a list") }
        let sep = p.with.string("separator") ?? ","
        return .success(arr.map { anyToString($0) }.joined(separator: sep))
    }

    // --- split ---
    // Compute the <parts: lowbar.split> from "one:two:three" with { separator: ":" }.
    .qualifier("split", inputTypes: ["String"],
               description: "Split string into a list; with { separator }",
               acceptsParameters: true) { p in
        guard let str = p.stringValue else { return .failure("split requires a string") }
        let sep = p.with.string("separator") ?? ","
        return .success(str.components(separatedBy: sep))
    }

    // --- tap ---
    // Compute the <debug: lowbar.tap> from the <value>.
    .qualifier("tap", inputTypes: ["List", "String", "Object", "Int", "Double", "Bool"],
               description: "Pass-through (identity) — useful as a pipeline checkpoint") { p in
        guard let val = p.rawValue else { return .success("nil" as Any) }
        return .success(val)
    }

    // ================================================================
    // MARK: — Actions
    // ================================================================

    // --- Range ---
    // Lowbar.Range the <numbers> with { stop: 10 }.
    // Lowbar.Range the <evens> with { start: 0, stop: 10, step: 2 }.
    // Lowbar.Range the <countdown> with { start: 5, stop: 0 }.
    .action("Range", verbs: ["range"], role: "own", prepositions: ["with", "from", "for"],
            description: "Generate a list of integers; use with { start, stop, step }") { input in
        let start = input.with.int("start") ?? 0
        guard let stop = input.with.int("stop") else {
            return .failure(.invalidInput, "Range requires with { stop } (and optional start, step)")
        }
        let step = input.with.int("step") ?? (start <= stop ? 1 : -1)
        guard step != 0 else { return .failure(.invalidInput, "Range step cannot be zero") }

        var result: [Int] = []
        var i = start
        if step > 0 {
            while i < stop { result.append(i); i += step }
        } else {
            while i > stop { result.append(i); i += step }
        }
        return .success(["data": result])
    }

    // --- Random ---
    // Lowbar.Random the <dice> with { min: 1, max: 6 }.
    .action("Random", verbs: ["random"], role: "own", prepositions: ["with", "from", "for"],
            description: "Generate a random integer; use with { min, max }") { input in
        let lo = input.with.int("min") ?? 0
        let hi = input.with.int("max") ?? 100
        guard lo <= hi else { return .failure(.invalidInput, "Random requires min <= max") }
        return .success(["data": Int.random(in: lo...hi)])
    }

    // --- UniqueId ---
    // Lowbar.UniqueId the <id> with { prefix: "user_" }.
    // Lowbar.UniqueId the <id> for the <session>.
    .action("UniqueId", verbs: ["uniqueid", "unique-id"], role: "own", prepositions: ["with", "for"],
            description: "Generate a unique ID; optionally with { prefix }") { input in
        let prefix = input.with.string("prefix") ?? ""
        let id = generateUniqueId()
        return .success(["data": "\(prefix)\(id)"])
    }

    // --- Now ---
    // Lowbar.Now the <timestamp> for the <system>.
    .action("Now", verbs: ["now"], role: "own", prepositions: ["for"],
            description: "Return the current Unix timestamp in milliseconds") { _ in
        let ms = Int(Date().timeIntervalSince1970 * 1000)
        return .success(["data": ms])
    }

    // --- Times ---
    // Lowbar.Times the <stars> with { n: 5, value: "*" }.
    .action("Times", verbs: ["times"], role: "own", prepositions: ["with", "for"],
            description: "Generate a list of N copies of a value; use with { n, value }") { input in
        let n = input.with.int("n") ?? 1
        guard n >= 0 else { return .failure(.invalidInput, "Times requires non-negative n") }
        let value: Any = input.with["value"] ?? n
        return .success(["data": Array(repeating: value, count: n)])
    }
