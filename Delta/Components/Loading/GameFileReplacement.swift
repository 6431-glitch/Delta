import Foundation
import Darwin

/// Stage and swap on disk; replacing a large ROM never loads both copies into RAM.
enum GameFileReplacement {
    static func replace(source: URL, destination: URL, commit: () throws -> Void) throws {
        let files = FileManager.default
        let directory = destination.deletingLastPathComponent()
        let staged = directory.appendingPathComponent(".replacement-" + UUID().uuidString)
        let backup = directory.appendingPathComponent(".previous-" + UUID().uuidString)
        let existed = files.fileExists(atPath: destination.path)
        var retainBackup = false
        defer {
            try? files.removeItem(at: staged)
            if !retainBackup { try? files.removeItem(at: backup) }
        }
        try files.copyItem(at: source, to: staged)
        let size = try files.attributesOfItem(atPath: staged.path)[.size] as? NSNumber
        guard let size, size.int64Value > 0 else { throw CocoaError(.fileReadCorruptFile) }
        if existed { try files.copyItem(at: destination, to: backup) }
        try swap(staged, destination)
        do { try commit() }
        catch {
            do {
                if existed { try swap(backup, destination) }
                else { try files.removeItem(at: destination) }
            } catch let restoreError {
                retainBackup = true
                throw NSError(domain: "GameFileReplacement", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Could not restore the previous game file. Its backup has been retained."),
                    NSUnderlyingErrorKey: restoreError,
                    NSFilePathErrorKey: backup.path
                ])
            }
            throw error
        }
    }
    private static func swap(_ source: URL, _ destination: URL) throws {
        guard rename(source.path, destination.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }
}
