import Foundation

/// A bounded, versioned RMS + preferences bundle. No executable or game JAR is included.
struct J2MEBackup: Codable {
    let version: Int
    let gameID: String
    let settings: Data
    let files: [String: Data]
    static let maximumBytes = 32 * 1024 * 1024
    enum Failure: LocalizedError {
        case invalid, wrongGame, tooLarge
        var errorDescription: String? {
            switch self {
            case .invalid: return "This Java ME backup is invalid or contains unsafe paths."
            case .wrongGame: return "This backup belongs to a different game."
            case .tooLarge: return "The Java ME backup exceeds the 32 MB save limit."
            }
        }
    }
    static func validPath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return !path.isEmpty && !path.contains("\\") && !path.contains("\0") && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
    static func capture(gameID: String, settings: [String: Any], directory: URL) throws -> Self {
        let fm = FileManager.default
        let canonicalRoot = directory.resolvingSymlinksInPath().standardizedFileURL.path
        var files: [String: Data] = [:]
        var bytes = 0
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) {
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isSymbolicLink != true else { throw Failure.invalid }
                guard values.isRegularFile == true else { continue }
                let canonicalPath = url.resolvingSymlinksInPath().standardizedFileURL.path
                guard canonicalPath.hasPrefix(canonicalRoot + "/") else { throw Failure.invalid }
                let path = String(canonicalPath.dropFirst(canonicalRoot.count + 1))
                guard validPath(path) else { throw Failure.invalid }
                bytes += values.fileSize ?? 0
                guard bytes <= maximumBytes, files.count < 4096 else { throw Failure.tooLarge }
                files[path] = try Data(contentsOf: url)
            }
        }
        let filtered = settings.filter { $0.key.hasPrefix("j2me.") }
        return Self(version: 1, gameID: gameID, settings: try JSONSerialization.data(withJSONObject: filtered, options: [.sortedKeys]), files: files)
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
    static func read(_ url: URL, gameID: String) throws -> Self {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes * 2 else { throw Failure.tooLarge }
        let backup = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try backup.validate(gameID: gameID)
        return backup
    }
    func validate(gameID: String) throws {
        guard version == 1 else { throw Failure.invalid }
        guard self.gameID == gameID else { throw Failure.wrongGame }
        guard files.count <= 4096, settings.count <= 256 * 1024,
              files.values.reduce(0, { $0 + $1.count }) <= Self.maximumBytes else { throw Failure.tooLarge }
        guard files.keys.allSatisfy(Self.validPath),
              let dictionary = try JSONSerialization.jsonObject(with: settings) as? [String: Any],
              dictionary.keys.allSatisfy({ $0.hasPrefix("j2me.") }) else { throw Failure.invalid }
        // Reject a file that is also an ancestor directory of another file.
        for path in files.keys {
            var parts = path.split(separator: "/"); parts.removeLast()
            while !parts.isEmpty {
                guard files[parts.joined(separator: "/")] == nil else { throw Failure.invalid }
                parts.removeLast()
            }
        }
    }
    func restore(to directory: URL) throws {
        try validate(gameID: gameID)
        let fm = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(UUID().uuidString)
        let previous = parent.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        for (path, data) in files {
            let target = staging.appendingPathComponent(path)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
        }
        let existed = fm.fileExists(atPath: directory.path)
        if existed { try fm.moveItem(at: directory, to: previous) }
        do { try fm.moveItem(at: staging, to: directory) }
        catch { if existed { try? fm.moveItem(at: previous, to: directory) }; throw error }
        if existed { try? fm.removeItem(at: previous) }
    }
}
