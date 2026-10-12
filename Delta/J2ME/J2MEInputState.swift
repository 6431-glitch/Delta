import Foundation

/// Multiple controls can hold the same Java key. Only the first press and last
/// release reach the MIDlet, including touch cancellation/controller disconnect.
struct J2MEInputState {
    private(set) var held: [String: Int32] = [:]
    mutating func press(source: String, code: Int32) -> Bool {
        guard held[source] == nil else { return false }
        let first = !held.values.contains(code)
        held[source] = code
        return first
    }
    mutating func release(source: String) -> Int32? {
        guard let code = held.removeValue(forKey: source), !held.values.contains(code) else { return nil }
        return code
    }
    mutating func releaseAll() -> Set<Int32> {
        let codes = Set(held.values); held.removeAll(); return codes
    }
}
