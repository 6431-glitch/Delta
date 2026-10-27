#if DEBUG
import Foundation
import UIKit
import CoreData
import DeltaCore
import DeltaApplication
import ZIPFoundation

/// Opt-in round trip for original fixtures on a disposable test simulator only.
@MainActor enum QualityTransferDriver {
    static func run(_ game: Game) {
        guard ProcessInfo.processInfo.environment["DELTA_QUALITY_TRANSFER_ROUNDTRIP"] == "1" else { return }
        Task {
            do {
                guard let path = ProcessInfo.processInfo.environment["DELTA_QUALITY_TRANSFER_JAR"] else { throw GameTransferError.missingFile }
                let java: Game = try await withCheckedThrowingContinuation { continuation in
                    DatabaseManager.shared.importGames(at: [URL(fileURLWithPath: path)]) { games, errors in
                        if let game = games.first { continuation.resume(returning: game) }
                        else { continuation.resume(throwing: errors.first ?? GameTransferError.missingFile) }
                    }
                }
                let context = DatabaseManager.shared.viewContext
                let fm = FileManager.default
                let date = Date(timeIntervalSince1970: 1700000000)
                game.name = "Transfer Custom Title"; game.isFavorite = true; game.playedDate = date
                game.gameSettings = ["fastForwardSpeed": 2.0, "saveStates.autosaveLimit": 8, "custom": ["enabled": true]]
                java.name = "Transfer Java"; java.isFavorite = true
                java.gameSettings = ["j2me.preferences": "{\"fps\":30,\"opacity\":0.5}", "j2me.descriptor": ["MIDlet-Name": "Original Fixture"]]
                game.secondaryGame = java
                let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
                    UIColor.magenta.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
                }.pngData()!
                for (suffix, assign) in [("cover", true), ("backdrop", false)] {
                    let url = DatabaseManager.gamesDirectoryURL.appendingPathComponent(game.identifier + "-transfer-" + suffix + ".png")
                    try image.write(to: url)
                    if assign { game.artworkURL = url } else { game.backdropURL = url }
                }
                try Data("battery-fixture".utf8).write(to: game.gameSaveURL)
                let save = game.gameSave ?? GameSave(context: context)
                save.identifier = game.identifier; save.modifiedDate = date; game.gameSave = save
                for type in [SaveStateType.auto, .quick, .general, .locked, .main] {
                    let state = SaveState(context: context); state.game = game; state.type = type
                    state.name = "Slot \(type.rawValue)"; state.tags = ["boss", "transfer"]
                    state.sortPosition = Double(type.rawValue); state.coreIdentifier = "quality-core"; state.coreVersion = "1"
                    state.creationDate = date; state.modifiedDate = date
                    try Data("state-\(type.rawValue)".utf8).write(to: state.fileURL)
                    try image.write(to: state.imageFileURL)
                    if type == .locked { game.previewSaveState = state }
                }
                let cheat = Cheat(context: context); cheat.game = game; cheat.name = "Custom Cheat"
                cheat.code = "SXIOPO"; cheat.type = CheatType(rawValue: "Game Genie"); cheat.isEnabled = true; cheat.symbolName = "bolt.fill"
                let skin = ControllerSkin(context: context); skin.identifier = "quality.transfer.skin"; skin.gameType = game.type
                skin.name = "Custom Transfer Skin"; skin.filename = "quality-transfer.deltaskin"; skin.isStandard = false
                skin.supportedConfigurations = .iphoneEdgeToEdgePortrait
                guard let standard = DeltaCore.ControllerSkin.standardControllerSkin(for: game.type) else { throw GameTransferError.missingFile }
                try fm.copyItem(at: standard.fileURL, to: skin.fileURL)
                game.preferredPortraitSkin = skin
                let rms = CoreStorageAdapter.javaSaveDirectory(identifier: java.identifier).appendingPathComponent("rms")
                try fm.createDirectory(at: rms, withIntermediateDirectories: true)
                try Data("RMS fixture data".utf8).write(to: rms.appendingPathComponent("transfer-record"))
                try context.save()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    J2MESaveStore.checkpoint(java) { continuation.resume(with: $0) }
                }
                context.refresh(java, mergeChanges: true)
                let snapshot = try GameTransferArchive.snapshot(game)
                let url = try await GameTransferCoordinator.work { try GameTransferArchive.create(snapshot) }
                defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
                let prepared = try await GameTransferCoordinator.work { try GameTransferArchive.prepare(url) }
                defer { try? fm.removeItem(at: prepared.directory) }
                // A new store with the actual model proves first import without UI deletion observers.
                let container = NSPersistentContainer(name: "TransferRoundTrip", managedObjectModel: DatabaseManager.shared.managedObjectModel)
                let description = NSPersistentStoreDescription(); description.type = NSInMemoryStoreType
                container.persistentStoreDescriptions = [description]
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    container.loadPersistentStores { _, error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
                for file in prepared.manifest.files {
                    try fm.removeItem(at: DatabaseManager.defaultDirectoryURL().appendingPathComponent(file.path))
                }
                try await install(prepared, container: container)
                let importedContext = container.viewContext
                guard let restored = try GameTransferArchive.find(Game.self, id: snapshot.manifest.rootIdentifier, context: importedContext) else { throw GameTransferError.missingFile }
                let roundTrip = try GameTransferArchive.snapshot(restored)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                var expectedGames = snapshot.manifest.games, actualGames = roundTrip.manifest.games
                // Property-list dictionaries preserve values, but their serialized key order can vary.
                for index in expectedGames.indices {
                    if let expected = expectedGames[index].settings, let actual = actualGames[index].settings {
                        let first = try PropertyListSerialization.propertyList(from: expected, format: nil) as! NSDictionary
                        let second = try PropertyListSerialization.propertyList(from: actual, format: nil) as! NSDictionary
                        guard first.isEqual(second) else { throw GameTransferError.invalidPackage }
                    } else if (expectedGames[index].settings == nil) != (actualGames[index].settings == nil) {
                        throw GameTransferError.invalidPackage
                    }
                    expectedGames[index].settings = nil; actualGames[index].settings = nil
                }
                guard try encoder.encode(actualGames) == encoder.encode(expectedGames) else {
                    try encoder.encode(snapshot.manifest.games).write(to: fm.temporaryDirectory.appendingPathComponent("transfer-expected.json"))
                    try encoder.encode(roundTrip.manifest.games).write(to: fm.temporaryDirectory.appendingPathComponent("transfer-actual.json"))
                    throw NSError(domain: "TransferTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Round-trip metadata differs"])
                }
                let secondURL = try await GameTransferCoordinator.work { try GameTransferArchive.create(roundTrip) }
                defer { try? fm.removeItem(at: secondURL.deletingLastPathComponent()) }
                let second = try await GameTransferCoordinator.work { try GameTransferArchive.prepare(secondURL) }
                defer { try? fm.removeItem(at: second.directory) }
                guard try encoder.encode(second.manifest.files) == encoder.encode(prepared.manifest.files) else { throw GameTransferError.invalidPackage }
                // Re-import into an installed game: matching metadata is restored, extra local saves survive.
                restored.name = "Edited after import"
                let extra = SaveState(context: importedContext); extra.game = restored; extra.type = .general
                try Data("keep-local".utf8).write(to: extra.fileURL)
                try importedContext.save()
                let extraID = extra.identifier
                try await install(prepared, container: container); importedContext.reset()
                guard let merged = try GameTransferArchive.find(Game.self, id: snapshot.manifest.rootIdentifier, context: importedContext),
                      merged.name == "Transfer Custom Title", merged.saveStates.contains(where: { $0.identifier == extraID }) else { throw GameTransferError.invalidPackage }
                // Correct ZIP with a tampered payload must fail checksum verification before installation.
                let badURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".deltatransfer")
                defer { try? fm.removeItem(at: badURL) }
                do {
                    let archive = try Archive(url: badURL, accessMode: .create)
                    let header = prepared.directory.appendingPathComponent("manifest.json")
                    try encoder.encode(prepared.manifest).write(to: header)
                    try archive.addEntry(with: "manifest.json", fileURL: header)
                    for file in prepared.manifest.files {
                        let source = prepared.directory.appendingPathComponent(file.path)
                        if file.path == "Games/" + prepared.manifest.games[0].filename {
                            var bytes = try Data(contentsOf: source); bytes[0] ^= 1
                            let altered = prepared.directory.appendingPathComponent("altered")
                            try bytes.write(to: altered); try archive.addEntry(with: file.path, fileURL: altered)
                        } else { try archive.addEntry(with: file.path, fileURL: source) }
                    }
                }
                var rejected = false
                do { let invalid = try GameTransferArchive.prepare(badURL); try? fm.removeItem(at: invalid.directory) }
                catch { rejected = true }
                guard rejected else { throw GameTransferError.invalidPackage }
                let exported = try QualitySmokeDriver.directory().appendingPathComponent("Transfer.deltatransfer")
                try fm.copyItem(at: url, to: exported)
                record(passed: true, detail: "Fresh export/import preserves all metadata and file hashes for console + Java; all five state types/thumbnails, artwork, settings, enabled cheat, custom skin, preview/secondary links, battery/RMS/receipt; existing-game merge keeps extra saves; tampered payload rejected.")
            } catch { record(passed: false, detail: error.localizedDescription) }
        }
    }
    private static func install(_ prepared: GameTransferArchive.Prepared, container: NSPersistentContainer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GameTransferArchive.install(prepared, container: container) { continuation.resume(with: $0) }
        }
    }
    private static func record(passed: Bool, detail: String) {
        do {
            let directory = try QualitySmokeDriver.directory()
            let data = try JSONSerialization.data(withJSONObject: ["passed": passed, "detail": detail], options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent("transfer.json"), options: .atomic)
            print("[TRANSFER] \(passed ? "PASS" : "FAIL"): \(detail)")
        } catch { print("[TRANSFER] Could not write result") }
    }
}
#endif
