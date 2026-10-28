import Foundation

/// Only transfer-owned workspaces and sandbox import copies are disposable.
public enum GameTransferTemporaryFiles {
    public static var root: URL { FileManager.default.temporaryDirectory.appendingPathComponent("DeltaTransfers", isDirectory: true) }

    public static func createWorkspace(in root: URL = GameTransferTemporaryFiles.root) throws -> URL {
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    public static func discardWorkspace(_ directory: URL, in root: URL = GameTransferTemporaryFiles.root) {
        guard UUID(uuidString: directory.lastPathComponent) != nil,
              directory.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == root.resolvingSymlinksInPath().standardizedFileURL,
              (try? directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else { return }
        try? FileManager.default.removeItem(at: directory)
    }
    /// Snapshot once during app launch, before accepting transfers; never sweep live workspaces.
    public static func interruptedWorkspaces(in root: URL = GameTransferTemporaryFiles.root) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])) ?? []
        return items.filter {
            guard UUID(uuidString: $0.lastPathComponent) != nil,
                  let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return values.isDirectory == true && values.isSymbolicLink != true
        }
    }
    public static func isIncomingCopy(_ url: URL,
                                      temporaryRoot: URL = FileManager.default.temporaryDirectory,
                                      inboxRoot: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Inbox"),
                                      workspaceRoot: URL = GameTransferTemporaryFiles.root) -> Bool {
        guard url.isFileURL, url.pathExtension.lowercased() == "deltatransfer",
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return false }
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        func inside(_ root: URL) -> Bool { candidate.hasPrefix(root.resolvingSymlinksInPath().standardizedFileURL.path + "/") }
        // An active sender may still be sharing its archive; that lifetime has a separate owner.
        return !inside(workspaceRoot) && (inside(temporaryRoot) || inside(inboxRoot))
    }
    public static func discardIncomingCopy(_ url: URL) {
        guard isIncomingCopy(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// A share sheet retains this lease. Failed presentation or dismissal also releases its files.
public final class GameTransferExportLifetime: Sendable {
    private let directory: URL
    private let root: URL
    public init(directory: URL, root: URL = GameTransferTemporaryFiles.root) { self.directory = directory; self.root = root }
    public func finish() { GameTransferTemporaryFiles.discardWorkspace(directory, in: root) }
    deinit { GameTransferTemporaryFiles.discardWorkspace(directory, in: root) }
}
