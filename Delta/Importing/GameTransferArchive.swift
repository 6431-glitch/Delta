import Foundation
import CoreData
import CryptoKit
import DeltaCore
import DeltaApplication
import ZIPFoundation
import Roxas

/// Archive/file work uses immutable snapshots; managed objects remain on their context.
enum GameTransferArchive {
    struct Snapshot: Sendable {
        var manifest: GameTransferManifest
        var sources: [String: URL]
        var embedded: [String: Data]
    }
    struct Prepared: Sendable {
        let manifest: GameTransferManifest
        let directory: URL
    }
    private static let fm = FileManager.default

    @MainActor static func snapshot(_ root: Game) throws -> Snapshot {
        try snapshot([root])
    }

    @MainActor static func snapshot(_ roots: [Game]) throws -> Snapshot {
        guard let root = roots.first else { throw GameTransferError.emptyLibrary }
        var sources: [String: URL] = [:], embedded: [String: Data] = [:]
        var records: [GameTransferManifest.GameRecord] = [], visited = Set<String>()
        func add(_ url: URL, path: String, required: Bool = false) throws {
            guard fm.fileExists(atPath: url.path) else { if required { throw GameTransferError.missingFile }; return }
            guard try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true,
                  url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL else { throw GameTransferError.invalidPackage }
            sources[path] = url
        }
        func tree(_ url: URL, prefix: String) throws {
            guard fm.fileExists(atPath: url.path) else { return }
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            for file in contents {
                let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw GameTransferError.invalidPackage }
                if values.isDirectory == true { try tree(file, prefix: prefix + "/" + file.lastPathComponent) }
                else { try add(file, path: prefix + "/" + file.lastPathComponent, required: true) }
            }
        }
        func artwork(_ url: URL?, id: String, kind: String) throws -> GameTransferManifest.Artwork? {
            guard let url else { return nil }
            if url.isFileURL {
                let path = "Games/" + id + "-transfer-" + kind + "." + url.pathExtension.lowercased()
                try add(url, path: path, required: true)
                return .init(file: path)
            }
            if let data = ArtworkImagePipeline.cachedImage(for: url)?.pngData() {
                let path = "Games/" + id + "-transfer-" + kind + ".png"
                embedded[path] = data
                return .init(file: path, remoteURL: url.absoluteString)
            }
            return .init(remoteURL: url.absoluteString)
        }
        func capture(_ game: Game) throws {
            guard visited.insert(game.identifier).inserted else { return }
            guard CoreStorageAdapter.firmware(game.identifier) == nil, !game.isDeleted,
                  EmulationServices.sessions.session(gameIdentifier: game.identifier) == nil,
                  !(game.type == .j2me && EmulationServices.isJavaActive) else { throw GameTransferError.gameInUse }
            var record = GameTransferManifest.GameRecord(identifier: game.identifier, gameType: game.type.rawValue, filename: game.filename,
                name: game.name, isFavorite: game.isFavorite, collectionIndex: game.gameCollection?.index ?? 0)
            record.playedDate = game.playedDate
            if let settings = game.gameSettings { record.settings = try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0) }
            record.artwork = try artwork(game.artworkURL, id: game.identifier, kind: "cover")
            record.backdrop = try artwork(game.backdropURL, id: game.identifier, kind: "backdrop")
            record.secondaryIdentifier = game.secondaryGame?.identifier
            record.previewStateIdentifier = game.previewSaveState?.identifier
            record.saveModifiedDate = game.gameSave?.modifiedDate
            for state in game.saveStates.sorted(by: { $0.identifier < $1.identifier }) {
                record.states.append(.init(identifier: state.identifier, filename: state.filename, name: state.name, type: state.type.rawValue,
                    creationDate: state.creationDate, modifiedDate: state.modifiedDate, coreIdentifier: state.coreIdentifier,
                    coreVersion: state.coreVersion, tagsRaw: state.tagsRaw, sortPosition: state.sortPosition))
                try add(state.fileURL, path: "Save States/" + game.identifier + "/" + state.filename, required: true)
            }
            try tree(DatabaseManager.saveStatesDirectoryURL(for: game), prefix: "Save States/" + game.identifier)
            record.cheats = game.cheats.sorted { $0.identifier < $1.identifier }.map {
                .init(identifier: $0.identifier, name: $0.name, code: $0.code, type: $0.type.rawValue, isEnabled: $0.isEnabled,
                      symbolName: $0.symbolName, creationDate: $0.creationDate, modifiedDate: $0.modifiedDate)
            }
            for relationship in GameTransferManifest.skinRelationships.sorted() {
                guard let skin = game.value(forKey: relationship) as? ControllerSkin else { continue }
                record.skins.append(.init(relationship: relationship, identifier: skin.identifier, name: skin.name, filename: skin.filename,
                    isStandard: skin.isStandard, configurations: skin.supportedConfigurations.rawValue))
                if !skin.isStandard { try add(skin.fileURL, path: "Controller Skins/" + game.type.rawValue + "/" + skin.filename, required: true) }
            }
            // Content, battery saves, RTC, JAD and other game-ID sidecars (never other games).
            for url in try fm.contentsOfDirectory(at: DatabaseManager.gamesDirectoryURL, includingPropertiesForKeys: nil)
                where url.lastPathComponent.hasPrefix(game.identifier + ".") {
                try add(url, path: "Games/" + url.lastPathComponent)
            }
            try add(game.fileURL, path: "Games/" + game.filename, required: true)
            if game.type == .j2me {
                try tree(CoreStorageAdapter.javaSaveDirectory(identifier: game.identifier), prefix: "Games/J2ME/" + game.identifier)
                for suffix in [".receipt", "-recovery.j2mebackup"] {
                    let path = "Games/J2ME/" + game.identifier + suffix
                    try add(DatabaseManager.defaultDirectoryURL().appendingPathComponent(path), path: path)
                }
            }
            records.append(record)
            if let secondary = game.secondaryGame { try capture(secondary) }
        }
        for game in roots { try capture(game) }
        return Snapshot(manifest: .init(rootIdentifier: root.identifier, games: records), sources: sources, embedded: embedded)
    }

    static func digest(_ url: URL) throws -> (UInt64, String) {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256(), count: UInt64 = 0
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { count += UInt64(data.count); hash.update(data: data) }
        return (count, hash.finalize().map { String(format: "%02x", $0) }.joined())
    }

    static func create(_ snapshot: Snapshot) throws -> URL {
        let directory = try GameTransferTemporaryFiles.createWorkspace()
        do {
            let staging = directory.appendingPathComponent("staging", isDirectory: true)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            var manifest = snapshot.manifest
            let paths = Set(snapshot.sources.keys).union(snapshot.embedded.keys).sorted()
            for path in paths {
                guard GameTransferManifest.safePath(path) else { throw GameTransferError.invalidPackage }
                let target = staging.appendingPathComponent(path)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let data = snapshot.embedded[path] { try data.write(to: target) }
                else if let source = snapshot.sources[path] { try fm.copyItem(at: source, to: target) }
                let (size, hash) = try digest(target)
                manifest.files.append(.init(path: path, byteCount: size, sha256: hash))
            }
            try manifest.validate()
            let name = manifest.games.first { $0.identifier == manifest.rootIdentifier }!.name
            let safeName = String(name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || " _-".unicodeScalars.contains($0) }.prefix(60))
            let outputName = manifest.games.count > 1 ? "Delta Library" : (safeName.isEmpty ? "Game" : safeName)
            let output = directory.appendingPathComponent(outputName + ".deltatransfer")
            let archive = try Archive(url: output, accessMode: .create)
            let manifestURL = staging.appendingPathComponent("manifest.json")
            let manifestData = try JSONEncoder().encode(manifest)
            guard manifestData.count <= 16 * 1024 * 1024 else { throw GameTransferError.invalidPackage }
            try manifestData.write(to: manifestURL)
            try archive.addEntry(with: "manifest.json", fileURL: manifestURL, compressionMethod: .deflate)
            for file in manifest.files { try archive.addEntry(with: file.path, fileURL: staging.appendingPathComponent(file.path), compressionMethod: .deflate) }
            try fm.removeItem(at: staging)
            return output
        } catch { try? fm.removeItem(at: directory); throw error }
    }

    static func prepare(_ url: URL) throws -> Prepared {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let directory = try GameTransferTemporaryFiles.createWorkspace()
        var prepared = false
        defer { if !prepared { GameTransferTemporaryFiles.discardWorkspace(directory) } }
        var source = url
        if GameTransferTemporaryFiles.isIncomingCopy(url) {
            // Take ownership of the sandbox copy, never the user's original in Files.
            source = directory.appendingPathComponent("incoming.deltatransfer")
            try fm.moveItem(at: url, to: source)
        }
        let archive = try Archive(url: source, accessMode: .read)
        let entries = Array(archive)
        guard entries.count <= 20001, Set(entries.map(\.path)).count == entries.count,
              entries.allSatisfy({ $0.type == .file }),
              let header = entries.first(where: { $0.path == "manifest.json" }), header.uncompressedSize <= 16 * 1024 * 1024 else { throw GameTransferError.invalidPackage }
        var data = Data()
        let headerChecksum = try archive.extract(header) { chunk in
            guard data.count + chunk.count <= 16 * 1024 * 1024 else { throw GameTransferError.invalidPackage }
            data.append(chunk)
        }
        guard headerChecksum == header.checksum else { throw GameTransferError.invalidPackage }
        let manifest = try JSONDecoder().decode(GameTransferManifest.self, from: data)
        guard manifest.version == 1 else { throw GameTransferError.unsupportedVersion }
        try manifest.validate()
        guard Set(entries.map(\.path)) == Set(manifest.files.map(\.path)).union(["manifest.json"]) else { throw GameTransferError.invalidPackage }
        let entriesByPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
        do {
            for file in manifest.files {
                guard let entry = entriesByPath[file.path], entry.uncompressedSize == file.byteCount else { throw GameTransferError.invalidPackage }
                let destination = directory.appendingPathComponent(file.path)
                // Bound actual output as well as declared sizes; ZIP metadata is untrusted.
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                fm.createFile(atPath: destination.path, contents: nil)
                let handle = try FileHandle(forWritingTo: destination)
                do {
                    var written: UInt64 = 0
                    let checksum = try archive.extract(entry) { chunk in
                        written += UInt64(chunk.count)
                        guard written <= file.byteCount else { throw GameTransferError.invalidPackage }
                        try handle.write(contentsOf: chunk)
                    }
                    guard checksum == entry.checksum else { throw GameTransferError.invalidPackage }
                    try handle.close()
                } catch { try? handle.close(); throw error }
                let (size, hash) = try digest(destination)
                guard size == file.byteCount && hash == file.sha256 else { throw GameTransferError.invalidPackage }
            }
            for record in manifest.games {
                let content = directory.appendingPathComponent("Games/" + record.filename)
                guard GameType(fileExtension: content.pathExtension)?.rawValue == record.gameType,
                      try RSTHasher.sha1HashOfFile(at: content) == record.identifier else { throw GameTransferError.invalidPackage }
                _ = try ContentImportAdapter.inspect(content)
            }
            prepared = true
            return Prepared(manifest: manifest, directory: directory)
        } catch { try? fm.removeItem(at: directory); throw error }
    }

    static func install(_ prepared: Prepared, container: NSPersistentContainer = DatabaseManager.shared, completion: @escaping (Result<Void, Error>) -> Void) {
        container.performBackgroundTask { context in
            // Unfinished rollback data must survive app restarts and temporary-file cleanup.
            let rollbackDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Transfers/Recovery/Incomplete/" + UUID().uuidString, isDirectory: true)
            var transaction: GameTransferFileTransaction?
            do {
                // Validate all relationships/collisions before writing anything.
                var games: [String: Game] = [:]
                for record in prepared.manifest.games {
                    let game: Game = try find(Game.self, id: record.identifier, context: context) ?? Game(context: context)
                    if !game.isInserted && game.type.rawValue != record.gameType { throw GameTransferError.incompatibleGame }
                    game.identifier = record.identifier; game.type = GameType(rawValue: record.gameType); game.filename = record.filename
                    games[record.identifier] = game
                    for state in record.states {
                        if let existing = try find(SaveState.self, id: state.identifier, context: context), existing.game?.identifier != record.identifier { throw GameTransferError.incompatibleGame }
                    }
                    for cheat in record.cheats {
                        if let existing = try find(Cheat.self, id: cheat.identifier, context: context), existing.game?.identifier != record.identifier { throw GameTransferError.incompatibleGame }
                    }
                    for skin in record.skins where !skin.isStandard {
                        let path = "Controller Skins/" + record.gameType + "/" + skin.filename
                        let destination = DatabaseManager.defaultDirectoryURL().appendingPathComponent(path)
                        if fm.fileExists(atPath: destination.path) {
                            guard try digest(destination).1 == digest(prepared.directory.appendingPathComponent(path)).1 else { throw GameTransferError.incompatibleGame }
                        }
                        let request: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
                        request.predicate = NSPredicate(format: "identifier == %@ AND gameType == %@", skin.identifier, record.gameType)
                        if let existing = try context.fetch(request).first, fm.fileExists(atPath: existing.fileURL.path) {
                            guard try digest(existing.fileURL).1 == digest(prepared.directory.appendingPathComponent(path)).1 else { throw GameTransferError.incompatibleGame }
                        }
                    }
                }
                let files = try GameTransferFileTransaction(root: DatabaseManager.defaultDirectoryURL(), recoveryDirectory: rollbackDirectory)
                transaction = files
                for file in prepared.manifest.files { try files.install(from: prepared.directory.appendingPathComponent(file.path), path: file.path) }
                for record in prepared.manifest.games {
                    let game = games[record.identifier]!
                    game.name = record.name; game.isFavorite = record.isFavorite; game.playedDate = record.playedDate
                    game.gameSettings = try record.settings.map { try PropertyListSerialization.propertyList(from: $0, format: nil) as! NSDictionary }
                    func asset(_ asset: GameTransferManifest.Artwork?) -> URL? {
                        if let path = asset?.file { return DatabaseManager.defaultDirectoryURL().appendingPathComponent(path) }
                        return asset?.remoteURL.flatMap(URL.init(string:))
                    }
                    game.artworkURL = asset(record.artwork); game.backdropURL = asset(record.backdrop)
                    let collection = try find(GameCollection.self, id: record.gameType, context: context) ?? GameCollection(context: context)
                    collection.identifier = record.gameType
                    if collection.isInserted { collection.index = record.collectionIndex }
                    game.gameCollection = collection
                    for value in record.states {
                        let state = try find(SaveState.self, id: value.identifier, context: context) ?? SaveState(context: context)
                        state.identifier = value.identifier; state.filename = value.filename; state.name = value.name
                        state.type = SaveStateType(rawValue: value.type)!
                        state.creationDate = value.creationDate; state.modifiedDate = value.modifiedDate
                        state.coreIdentifier = value.coreIdentifier; state.coreVersion = value.coreVersion
                        state.tagsRaw = value.tagsRaw; state.sortPosition = value.sortPosition; state.game = game
                    }
                    for value in record.cheats {
                        let cheat = try find(Cheat.self, id: value.identifier, context: context) ?? Cheat(context: context)
                        cheat.identifier = value.identifier; cheat.name = value.name; cheat.code = value.code; cheat.type = CheatType(rawValue: value.type)
                        cheat.isEnabled = value.isEnabled; cheat.symbolName = value.symbolName
                        cheat.creationDate = value.creationDate; cheat.modifiedDate = value.modifiedDate; cheat.game = game
                    }
                    for relationship in GameTransferManifest.skinRelationships { game.setValue(nil, forKey: relationship) }
                    for value in record.skins {
                        let request: NSFetchRequest<ControllerSkin> = ControllerSkin.fetchRequest()
                        request.predicate = NSPredicate(format: "identifier == %@ AND gameType == %@", value.identifier, record.gameType)
                        let skin = try context.fetch(request).first ?? ControllerSkin(context: context)
                        if skin.isInserted {
                            skin.identifier = value.identifier; skin.gameType = game.type; skin.name = value.name; skin.filename = value.filename
                            skin.isStandard = value.isStandard; skin.supportedConfigurations = ControllerSkinConfigurations(rawValue: value.configurations)
                        }
                        game.setValue(skin, forKey: value.relationship)
                    }
                    if fm.fileExists(atPath: game.gameSaveURL.path) {
                        let save = game.gameSave ?? GameSave(context: context)
                        save.identifier = game.identifier; save.modifiedDate = record.saveModifiedDate ?? Date()
                        save.sha1 = try RSTHasher.sha1HashOfFile(at: game.gameSaveURL); game.gameSave = save
                    }
                }
                for record in prepared.manifest.games {
                    let game = games[record.identifier]!
                    game.secondaryGame = record.secondaryIdentifier.flatMap { games[$0] }
                    game.previewSaveState = try record.previewStateIdentifier.flatMap { try find(SaveState.self, id: $0, context: context) }
                }
                try context.save()
                files.commit()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                context.rollback()
                do { try transaction?.rollback() }
                catch {
                    let failure = NSError(domain: "Delta.GameTransfer", code: 1, userInfo: [NSLocalizedDescriptionKey: "The transfer could not finish restoring its files. Recovery files remain at \(rollbackDirectory.path).", NSUnderlyingErrorKey: error])
                    DispatchQueue.main.async { completion(.failure(failure)) }; return
                }
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    static func find<T: NSManagedObject>(_ type: T.Type, id: String, context: NSManagedObjectContext) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "identifier == %@", id); request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
