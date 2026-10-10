import Foundation
import CryptoKit
import CoreData

/// Value-only CloudKit identity and revision contracts, independent of transport.
enum iCloudSyncState {
    /// Harmony consumes managed objects synchronously inside its completion handlers.
    /// Awaiting context.perform for creation alone does not keep the caller on that queue.
    static func deliver<T, E: Error>(_ result: Result<T, E>, on context: NSManagedObjectContext?, completion: @escaping (Result<T, E>) -> Void) {
        if let context {
            context.perform { completion(result) }
        } else {
            completion(result)
        }
    }

    struct Revision: Codable, Equatable, Sendable {
        let identifier: String
        let date: Date
    }
    struct Token: Codable, Equatable {
        let account: String
        let serverToken: Data
        func token(for account: String) throws -> Data {
            guard self.account == account else { throw StateError.changedAccount }
            return serverToken
        }
    }
    enum StateError: Error { case changedAccount, missingVersion }

    static func identifier(kind: String, components: [String]) throws -> String {
        let data = try JSONEncoder().encode(components)
        return kind + "-" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func revision(in history: [Revision], requested: String?) throws -> Revision {
        let revision: Revision?
        if let requested { revision = history.first { $0.identifier == requested } }
        else { revision = history.first }
        guard let revision else { throw StateError.missingVersion }
        return revision
    }

    /// Stream large ROMs into small assets without loading the ROM into RAM.
    static func split(_ source: URL, into directory: URL, chunkSize: Int = 16 * 1024 * 1024) throws -> [URL] {
        guard chunkSize > 0 else { throw CocoaError(.fileWriteUnknown) }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        var urls: [URL] = []
        while let data = try input.read(upToCount: chunkSize), !data.isEmpty {
            let url = directory.appendingPathComponent(String(urls.count))
            try data.write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }
    static func assemble(_ chunks: [URL], at target: URL) throws {
        guard FileManager.default.createFile(atPath: target.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let output = try FileHandle(forWritingTo: target)
        defer { try? output.close() }
        do {
            for url in chunks {
                let input = try FileHandle(forReadingFrom: url)
                defer { try? input.close() }
                while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty { try output.write(contentsOf: data) }
            }
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }
}
