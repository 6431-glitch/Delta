import Foundation
import Roxas
import CoreData

/// Reuses GameSave/Harmony, including the app's iCloud provider and conflict handling.
enum J2MESaveStore {
    static let queue = DispatchQueue(label: "Delta.J2ME.Saves", qos: .utility)
    static func receipt(_ id: String) -> URL {
        J2MELibrary.saveDirectory(identifier: id).deletingLastPathComponent().appendingPathComponent(id + ".receipt")
    }
    static func restoreIfNeeded(_ game: Game, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = game.identifier, archive = game.gameSaveURL, folder = J2MELibrary.saveDirectory(identifier: id)
        queue.async {
            do {
                var settings: [String: Any]?
                if FileManager.default.fileExists(atPath: archive.path) {
                    let hash = try RSTHasher.sha1HashOfFile(at: archive)
                    let applied = try? String(contentsOf: receipt(id), encoding: .utf8)
                    if applied != hash || !FileManager.default.fileExists(atPath: folder.path) {
                        let backup = try J2MEBackup.read(archive, gameID: id)
                        try backup.restore(to: folder)
                        settings = try JSONSerialization.jsonObject(with: backup.settings) as? [String: Any]
                        try hash.write(to: receipt(id), atomically: true, encoding: .utf8)
                    }
                }
                DispatchQueue.main.async {
                    if let settings {
                        var current = game.gameSettings as? [String: Any] ?? [:]
                        current = current.filter { !$0.key.hasPrefix("j2me.") }
                        current.merge(settings) { _, new in new }
                        game.gameSettings = current as NSDictionary
                        game.managedObjectContext?.saveWithErrorLogging()
                    }
                    completion(.success(()))
                }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    static func checkpoint(_ game: Game, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        let id = game.identifier, archive = game.gameSaveURL, objectID = game.objectID
        let settings = game.gameSettings as? [String: Any] ?? [:]
        queue.async {
            do {
                let backup = try J2MEBackup.capture(gameID: id, settings: settings, directory: J2MELibrary.saveDirectory(identifier: id))
                try backup.encoded().write(to: archive, options: .atomic)
                let hash = try RSTHasher.sha1HashOfFile(at: archive)
                try hash.write(to: receipt(id), atomically: true, encoding: .utf8)
                DatabaseManager.shared.performBackgroundTask { context in
                    do {
                        guard let game = try context.existingObject(with: objectID) as? Game else { return }
                        if game.gameSave?.sha1 != hash {
                            let save = game.gameSave ?? GameSave(context: context)
                            save.identifier = id; save.modifiedDate = Date(); save.sha1 = hash
                            game.gameSave = save
                            try context.save()
                        }
                        DispatchQueue.main.async { completion(.success(())) }
                    } catch { DispatchQueue.main.async { completion(.failure(error)) } }
                }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    static func export(_ game: Game, completion: @escaping (Result<URL, Error>) -> Void) {
        checkpoint(game) { result in
            do {
                try result.get()
                let exportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
                let name = String(game.name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || " _-".unicodeScalars.contains($0) }.prefix(60))
                let target = exportDirectory.appendingPathComponent((name.isEmpty ? "Java ME" : name) + ".j2mebackup")
                try FileManager.default.copyItem(at: game.gameSaveURL, to: target)
                completion(.success(target))
            } catch { completion(.failure(error)) }
        }
    }
    static func importBackup(_ url: URL, game: Game, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = game.identifier, folder = J2MELibrary.saveDirectory(identifier: game.identifier)
        let previousSettings = game.gameSettings as? [String: Any] ?? [:]
        queue.async {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let backup = try J2MEBackup.read(url, gameID: id)
                // Keep the previous save as an undoable backup outside the active RMS directory.
                if FileManager.default.fileExists(atPath: folder.path) {
                    let old = try J2MEBackup.capture(gameID: id, settings: previousSettings, directory: folder)
                    try old.encoded().write(to: recoveryURL(id), options: .atomic)
                }
                try backup.restore(to: folder)
                let imported = try JSONSerialization.jsonObject(with: backup.settings) as? [String: Any] ?? [:]
                DispatchQueue.main.async {
                    var settings = game.gameSettings as? [String: Any] ?? [:]
                    settings = settings.filter { !$0.key.hasPrefix("j2me.") }; settings.merge(imported) { _, new in new }
                    game.gameSettings = settings as NSDictionary
                    game.managedObjectContext?.saveWithErrorLogging()
                    checkpoint(game, completion: completion)
                }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
    static func recoveryURL(_ id: String) -> URL {
        J2MELibrary.saveDirectory(identifier: id).deletingLastPathComponent().appendingPathComponent(id + "-recovery.j2mebackup")
    }
    static func reset(_ game: Game, completion: @escaping (Result<Void, Error>) -> Void) {
        let id = game.identifier, settings = game.gameSettings as? [String: Any] ?? [:]
        queue.async {
            do {
                let folder = J2MELibrary.saveDirectory(identifier: id)
                let old = try J2MEBackup.capture(gameID: id, settings: settings, directory: folder)
                try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
                try old.encoded().write(to: recoveryURL(id), options: .atomic)
                let empty = J2MEBackup(version: 1, gameID: id, settings: old.settings, files: [:])
                try empty.restore(to: folder)
                DispatchQueue.main.async { checkpoint(game, completion: completion) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
}
