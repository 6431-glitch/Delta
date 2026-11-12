import Foundation

/// Reversible file installation. Keep backups until the caller's database save succeeds.
public final class GameTransferFileTransaction {
    private let root: URL
    public let recoveryDirectory: URL
    private var installed: [(target: URL, backup: URL?)] = []
    public init(root: URL, recoveryDirectory: URL) throws {
        self.root = root.resolvingSymlinksInPath().standardizedFileURL
        self.recoveryDirectory = recoveryDirectory
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
    }
    public func install(from source: URL, path: String) throws {
        guard GameTransferManifest.safePath(path) else { throw GameTransferError.invalidPackage }
        let fm = FileManager.default, target = root.appendingPathComponent(path)
        // Reject pre-existing symlinks in any destination component, including the file itself.
        var part = root
        for component in path.split(separator: "/") {
            part.appendPathComponent(String(component))
            if (try? part.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { throw GameTransferError.invalidPackage }
        }
        var backup: URL?
        if fm.fileExists(atPath: target.path) {
            guard (try target.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else { throw GameTransferError.invalidPackage }
            let url = recoveryDirectory.appendingPathComponent(UUID().uuidString)
            try fm.copyItem(at: target, to: url); backup = url
        }
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = target.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: temporary) }
        try fm.copyItem(at: source, to: temporary)
        // Track before removing the destination so a failed move can also be rolled back.
        installed.append((target, backup))
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.moveItem(at: temporary, to: target)
    }
    public func rollback() throws {
        let fm = FileManager.default
        for entry in installed.reversed() {
            if fm.fileExists(atPath: entry.target.path) { try fm.removeItem(at: entry.target) }
            if let backup = entry.backup { try fm.moveItem(at: backup, to: entry.target) }
        }
        installed.removeAll()
        try? fm.removeItem(at: recoveryDirectory)
    }
    public func commit() {
        installed.removeAll()
        try? FileManager.default.removeItem(at: recoveryDirectory)
    }
}
