import Foundation
import XCTest
@testable import DeltaApplication

final class GameTransferTests: XCTestCase {
    let id = String(repeating: "a", count: 40)
    func fixture() -> GameTransferManifest {
        let game = GameTransferManifest.GameRecord(identifier: id, gameType: "com.rileytestut.delta.game.gba", filename: id + ".gba", name: "Custom Name", isFavorite: true, collectionIndex: 2001)
        var manifest = GameTransferManifest(rootIdentifier: id, games: [game])
        manifest.files = [.init(path: "Games/" + id + ".gba", byteCount: 512, sha256: String(repeating: "b", count: 64))]
        return manifest
    }
    func testMetadataAndSettingsRoundTrip() throws {
        var manifest = fixture()
        manifest.games[0].settings = try PropertyListSerialization.data(fromPropertyList: ["fastForwardSpeed": 2.0, "j2me.preferences": "{\"fps\":30}", "nested": ["enabled": true], "data": Data([1,2,3])], format: .binary, options: 0)
        manifest.games[0].states = [.init(identifier: "state", filename: "state", name: "Boss", type: 3, creationDate: Date(timeIntervalSince1970: 1), modifiedDate: Date(timeIntervalSince1970: 2), coreIdentifier: "core", coreVersion: "1", tagsRaw: "|boss|", sortPosition: 4)]
        manifest.games[0].previewStateIdentifier = "state"
        manifest.games[0].cheats = [.init(identifier: "cheat", name: "Coins", code: "1234", type: "code", isEnabled: true, symbolName: "star", creationDate: Date(), modifiedDate: Date())]
        manifest.files.append(.init(path: "Save States/" + id + "/state", byteCount: 42, sha256: String(repeating: "c", count: 64)))
        try manifest.validate()
        let decoded = try JSONDecoder().decode(GameTransferManifest.self, from: JSONEncoder().encode(manifest))
        XCTAssertEqual(decoded.games[0].settings, manifest.games[0].settings)
        XCTAssertEqual(decoded.games[0].states[0].tagsRaw, "|boss|")
        XCTAssertEqual(decoded.games[0].states[0].coreVersion, "1")
        XCTAssertTrue(decoded.games[0].isFavorite)
        XCTAssertTrue(decoded.games[0].cheats[0].isEnabled)
        try decoded.validate()
    }
    func testRejectsMissingContentTraversalUnrelatedAndDuplicateFiles() throws {
        var missing = fixture(); missing.files = []; XCTAssertThrowsError(try missing.validate())
        for path in ["../escape", "/absolute", "Games/../escape", "Games\\escape", "Games//escape", "Games/other.sav", "Accounts/token"] {
            var manifest = fixture()
            manifest.files.append(.init(path: path, byteCount: 0, sha256: String(repeating: "b", count: 64)))
            XCTAssertThrowsError(try manifest.validate(), path)
        }
        var duplicate = fixture(); duplicate.files.append(duplicate.files[0]); XCTAssertThrowsError(try duplicate.validate())
        var caseDuplicate = fixture(); caseDuplicate.files.append(.init(path: caseDuplicate.files[0].path.uppercased(), byteCount: 0, sha256: String(repeating: "b", count: 64))); XCTAssertThrowsError(try caseDuplicate.validate())
    }
    func testRejectsInvalidVersionSizesSettingsAndRelationships() throws {
        var version = fixture(); version.version = 2; XCTAssertThrowsError(try version.validate())
        var oversized = fixture(); oversized.files[0].byteCount = 3 * 1024 * 1024 * 1024; XCTAssertThrowsError(try oversized.validate())
        var settings = fixture(); settings.games[0].settings = Data([0]); XCTAssertThrowsError(try settings.validate())
        var secondary = fixture(); secondary.games[0].secondaryIdentifier = "missing"; XCTAssertThrowsError(try secondary.validate())
        var preview = fixture(); preview.games[0].previewStateIdentifier = "missing"; XCTAssertThrowsError(try preview.validate())
    }
    func testJavaRuntimeFilesAndSecondaryCartridgeAreAllowed() throws {
        var manifest = fixture()
        let secondaryID = String(repeating: "c", count: 40)
        manifest.games[0].secondaryIdentifier = secondaryID
        manifest.games.append(.init(identifier: secondaryID, gameType: "page.ducnguyen.delta.j2me", filename: secondaryID + ".jar", name: "Secondary", isFavorite: false, collectionIndex: 2000))
        for path in ["Games/" + secondaryID + ".jar", "Games/" + secondaryID + ".sav", "Games/J2ME/" + secondaryID + "/rms/store", "Games/J2ME/" + secondaryID + ".receipt"] {
            manifest.files.append(.init(path: path, byteCount: 1, sha256: String(repeating: "d", count: 64)))
        }
        try manifest.validate()
    }
    func testLibraryWithMoreThanEightGamesRoundTripsAndRejectsDuplicates() throws {
        var manifest = fixture()
        for index in 1...11 {
            let identifier = String(format: "%040x", index)
            manifest.games.append(.init(identifier: identifier, gameType: "com.rileytestut.delta.game.gba", filename: identifier + ".gba", name: "Game \(index)", isFavorite: false, collectionIndex: 2001))
            manifest.files.append(.init(path: "Games/" + identifier + ".gba", byteCount: 1, sha256: String(repeating: "b", count: 64)))
        }
        try manifest.validate()
        let decoded = try JSONDecoder().decode(GameTransferManifest.self, from: JSONEncoder().encode(manifest))
        XCTAssertEqual(decoded.games.count, 12)
        try decoded.validate()
        manifest.games.append(manifest.games[1])
        XCTAssertThrowsError(try manifest.validate())
    }
    func testFileRollbackRestoresOverwritesAndRemovesNewFiles() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let root = temporary.appendingPathComponent("database"), source = temporary.appendingPathComponent("incoming")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("save")
        try Data("old".utf8).write(to: target); try Data("new".utf8).write(to: source)
        let transaction = try GameTransferFileTransaction(root: root, recoveryDirectory: temporary.appendingPathComponent("recovery"))
        try transaction.install(from: source, path: "save")
        try transaction.install(from: source, path: "nested/new")
        XCTAssertEqual(try Data(contentsOf: target), Data("new".utf8))
        XCTAssertThrowsError(try transaction.install(from: source, path: "../outside"))
        try transaction.rollback()
        XCTAssertEqual(try Data(contentsOf: target), Data("old".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("nested/new").path))
    }
    func testRejectsDestinationSymlinkWithoutTouchingOutsideFile() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let root = temporary.appendingPathComponent("database"), outside = temporary.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)
        let transaction = try GameTransferFileTransaction(root: root, recoveryDirectory: temporary.appendingPathComponent("recovery"))
        XCTAssertThrowsError(try transaction.install(from: outside, path: "link"))
        XCTAssertEqual(try Data(contentsOf: outside), Data("old".utf8))
        transaction.commit()
    }
}
