import UIKit
import DeltaCore
import Harmony

/// Library metadata lives in Game.gameSettings, preserving preferences across local relaunches.
enum J2MELibrary {
    static let presets: [(label: String, w: Int, h: Int)] = [
        ("128 × 128", 128, 128), ("128 × 160", 128, 160), ("176 × 208", 176, 208),
        ("176 × 220", 176, 220), ("240 × 320", 240, 320), ("240 × 400", 240, 400),
        ("320 × 240", 320, 240), ("360 × 640", 360, 640), ("480 × 800", 480, 800)]

    static func automaticScreen(for game: Game) -> J2MEScreenProfile {
        let settings = game.gameSettings as? [String: Any] ?? [:]
        let detected = J2MEScreenProfile.detect(filename: settings["j2me.originalFilename"] as? String ?? game.filename,
                       manifest: J2MEJARMetadata.read(from: game.fileURL.path)?.attributes ?? [:],
                       descriptor: settings["j2me.descriptor"] as? [String: String] ?? [:])
        let phone = J2MEPreferences(settings: settings).phone
        if detected.source == .fallback && phone != .generic {
            return .init(w: phone.size.0, h: phone.size.1, source: .phone)
        }
        return detected
    }
    static func screen(for game: Game, automatic: J2MEScreenProfile) -> J2MEScreenProfile {
        let settings = game.gameSettings as? [String: Any] ?? [:]
        if let w = settings["j2me.screenWidth"] as? Int, let h = settings["j2me.screenHeight"] as? Int,
           J2MEScreenProfile.valid(w, h) { return .init(w: w, h: h, source: .manual) }
        return automatic
    }
    static func configure(_ game: Game, from presenter: UIViewController) {
        guard !J2MEGameViewController.isSessionActive else {
            showError("Exit the Java game before changing settings.", from: presenter); return
        }
        guard savesAreReady(game, from: presenter) else { return }
        J2MESaveStore.restoreIfNeeded(game) { result in
            do { try result.get() }
            catch { showError(error.localizedDescription, from: presenter); return }
            let controller = J2MEGameSettingsController(game: game)
            let navigation = UINavigationController(rootViewController: controller)
            navigation.sheetPresentationController?.detents = [.medium(), .large()]
            presenter.present(navigation, animated: true)
        }
    }
    static func saveDirectory(identifier: String) -> URL {
        DatabaseManager.gamesDirectoryURL.appendingPathComponent("J2ME", isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: true)
    }
    static func launch(_ game: Game, from presenter: UIViewController) {
        guard !J2MEGameViewController.isSessionActive else {
            showError("A Java game is already running. Exit it before starting another.", from: presenter)
            return
        }
        guard FileManager.default.isReadableFile(atPath: game.fileURL.path) else {
            showError("The game file is not available on this device yet.", from: presenter)
            return
        }
        guard savesAreReady(game, from: presenter) else { return }
        J2MEGameViewController.isSessionActive = true
        J2MESaveStore.restoreIfNeeded(game) { result in
            do { try result.get() }
            catch {
                J2MEGameViewController.isSessionActive = false
                showError("Could not restore Java saves: \(error.localizedDescription)", from: presenter)
                return
            }
            presentGame(game, from: presenter)
        }
    }
    private static func presentGame(_ game: Game, from presenter: UIViewController) {
        let automatic = automaticScreen(for: game)
        let profile = screen(for: game, automatic: automatic)
        let metadata = J2MEJARMetadata.read(from: game.fileURL.path)
        let icon = game.artworkURL.flatMap { $0.isFileURL ? UIImage(contentsOfFile: $0.path) : nil }
            ?? metadata?.readIcon(from: game.fileURL.path) ?? UIImage(systemName: "candybarphone")!
        let preferences = J2MEPreferences(settings: game.gameSettings as? [String: Any] ?? [:])
        let controller = J2MEGameViewController(jarPath: game.fileURL.path, appName: game.name,
            appIcon: icon, canvasWidth: profile.w, canvasHeight: profile.h, render3dScale: preferences.scale3D, fpsLimit: preferences.fps)
        controller.preferences = preferences
        controller.gameIdentifier = game.identifier
        controller.onPreferencesChanged = { preferences in
            var settings = game.gameSettings as? [String: Any] ?? [:]
            settings["j2me.preferences"] = preferences.json
            game.gameSettings = settings as NSDictionary
            game.managedObjectContext?.saveWithErrorLogging()
        }
        controller.onSessionClosed = { completion in J2MESaveStore.checkpoint(game, completion: completion) }
        controller.saveDirectory = saveDirectory(identifier: game.identifier)
        controller.modalPresentationStyle = .fullScreen
        J2MEGameViewController.isSessionActive = true
        game.playedDate = Date()
        game.managedObjectContext?.saveWithErrorLogging()
        presenter.present(controller, animated: true)
    }
    private static func savesAreReady(_ game: Game, from presenter: UIViewController) -> Bool {
        guard let coordinator = SyncManager.shared.coordinator, coordinator.isSyncing, let save = game.gameSave else { return true }
        do {
            if let record = try coordinator.recordController.fetchRecords(for: [save]).first,
               record.isSyncingEnabled && !record.isConflicted && (record.localStatus == nil || record.remoteStatus == .updated) {
                showError("Delta Sync is downloading this game's saves. Wait for it to finish before opening the game or its settings.", from: presenter)
                return false
            }
            return true
        } catch { showError(error.localizedDescription, from: presenter); return false }
    }
    static func showError(_ message: String, from presenter: UIViewController) {
        let alert = UIAlertController(title: "Java ME", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
