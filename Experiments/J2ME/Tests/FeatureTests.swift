import Foundation

@main struct FeatureTests {
    static func main() throws {
        var checks = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); checks += 1 }
        func rejects(_ body: () throws -> Void, _ label: String) {
            do { try body(); fatalError(label) } catch { checks += 1 }
        }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("rms")
        try fm.createDirectory(at: folder.appendingPathComponent("game"), withIntermediateDirectories: true)
        let record = Data([0, 1, 0xff, 0x35])
        try record.write(to: folder.appendingPathComponent("game/record.bin"))
        let settings: [String: Any] = ["j2me.screenWidth": 176, "j2me.originalFilename": "Game.jar", "other": "excluded"]
        let backup = try J2MEBackup.capture(gameID: "game-1", settings: settings, directory: folder)
        check(backup.files["game/record.bin"] == record, "Capture nested binary RMS")
        let prefs = try JSONSerialization.jsonObject(with: backup.settings) as! [String: Any]
        check(prefs["other"] == nil, "Only Java preferences")
        check(prefs["j2me.screenWidth"] as? Int == 176, "Screen preserved")
        let encoded = try backup.encoded()
        check(encoded == (try backup.encoded()), "Stable encoding for sync hash")
        let archive = root.appendingPathComponent("save.j2mebackup")
        try encoded.write(to: archive)
        let decoded = try J2MEBackup.read(archive, gameID: "game-1")
        check(decoded.files == backup.files, "Backup round trip")
        rejects({ _ = try J2MEBackup.read(archive, gameID: "another-game") }, "Wrong game rejected")
        try Data([9]).write(to: folder.appendingPathComponent("stale"))
        try decoded.restore(to: folder)
        check(!fm.fileExists(atPath: folder.appendingPathComponent("stale").path), "Import replaces stale RMS")
        check(try Data(contentsOf: folder.appendingPathComponent("game/record.bin")) == record, "Restore bytes")
        for path in ["../escape", "/absolute", "a/../b", "a//b", "a\\b", "a/", "", "a\0b"] {
            check(!J2MEBackup.validPath(path), "Reject unsafe path \(path)")
        }
        check(J2MEBackup.validPath("日本語/data.dat"), "Unicode filenames")
        let conflict = J2MEBackup(version: 1, gameID: "game-1", settings: backup.settings, files: ["a": record, "a/b": record])
        rejects({ try conflict.restore(to: folder) }, "File-directory conflict rejected")
        check(try Data(contentsOf: folder.appendingPathComponent("game/record.bin")) == record, "Failed restore preserves saves")
        let wrongVersion = J2MEBackup(version: 99, gameID: "game-1", settings: backup.settings, files: [:])
        rejects({ try wrongVersion.validate(gameID: "game-1") }, "Unknown version")
        try fm.createSymbolicLink(at: folder.appendingPathComponent("link"), withDestinationURL: root)
        rejects({ _ = try J2MEBackup.capture(gameID: "game-1", settings: settings, directory: folder) }, "Symlink rejected")
        try fm.removeItem(at: folder.appendingPathComponent("link"))
        let empty = J2MEBackup(version: 1, gameID: "game-1", settings: backup.settings, files: [:])
        try empty.restore(to: folder)
        check(try fm.contentsOfDirectory(atPath: folder.path).isEmpty, "Reset publishes empty data")
        var config = J2MEPreferences(); config.phone = .nokia; config.fps = 30; config.opacity = 0.5
        config.keyOverrides["53"] = -10
        config.placements["portrait.keypad"] = .init(x: 0.6, y: 0.7, scale: 1.2)
        let restored = J2MEPreferences(settings: ["j2me.preferences": config.json])
        check(restored.phone == .nokia && restored.fps == 30, "Preferences round trip")
        check(restored.key(50) == -1, "Nokia directional keys")
        check(restored.key(53) == -10, "Explicit Fire override")
        check(restored.key(49) == 49, "Unmapped number remains numeric")
        check(restored.placements["portrait.keypad"]?.scale == 1.2, "Layout round trip")
        check(restored.properties["delta.key.fire"] == "-10", "Canvas game action mapping")
        config.fps = 999; config.scale3D = 90; config.opacity = -1; config.keyOverrides["53"] = Int.max
        let validated = J2MEPreferences(settings: ["j2me.preferences": config.json])
        check(validated.fps == 0 && validated.scale3D == 3 && validated.opacity == 0.2, "Preference bounds")
        check(validated.key(53) == -5, "Out of range key removed")
        check(J2MEPreferences(settings: ["j2me.preferences": "broken"]).phone == .generic, "Corrupt preferences fallback")
        var keys = J2MEInputState()
        check(keys.press(source: "touch", code: 53), "First Fire press delivered")
        check(!keys.press(source: "pad", code: 53), "Second source does not duplicate key down")
        check(keys.release(source: "touch") == nil, "Cancelling touch keeps controller Fire held")
        check(keys.release(source: "pad") == 53, "Last source emits release")
        check(keys.release(source: "pad") == nil, "No duplicate release")
        _ = keys.press(source: "left", code: 52); _ = keys.press(source: "right", code: 54)
        check(keys.releaseAll() == [52, 54] && keys.held.isEmpty, "Pause/disconnect releases all held keys")
        print("Passed \(checks) Java ME feature checks")
    }
}
