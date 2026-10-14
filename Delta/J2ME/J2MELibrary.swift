import DeltaDomain
import UIKit
import DeltaCore

/// Library metadata lives in Game.gameSettings, preserving preferences across local relaunches.
@MainActor enum J2MELibrary {
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
        guard !EmulationServices.isJavaActive else {
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
    nonisolated static func saveDirectory(identifier: String) -> URL {
        CoreStorageAdapter.javaSaveDirectory(identifier: identifier)
    }
    static func launch(_ game: Game, from presenter: UIViewController) {
        guard !EmulationServices.isJavaActive else {
            showError("A Java game is already running. Exit it before starting another.", from: presenter)
            return
        }
        guard FileManager.default.isReadableFile(atPath: game.fileURL.path) else {
            showError("The game file is not available on this device yet.", from: presenter)
            return
        }
        guard savesAreReady(game, from: presenter) else { return }
        let lease: SessionOwnership.Lease
        do { lease = try EmulationServices.ownership.acquire(scope: EmulationServices.javaScope) }
        catch { showError(error.localizedDescription, from: presenter); return }
        J2MESaveStore.restoreIfNeeded(game) { result in
            do { try result.get() }
            catch {
                EmulationServices.ownership.release(lease)
                showError("Could not restore Java saves: \(error.localizedDescription)", from: presenter)
                return
            }
            guard !game.isDeleted, presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else {
                EmulationServices.ownership.release(lease)
                return
            }
            presentGame(game, lease: lease, from: presenter)
        }
    }
    private static func presentGame(_ game: Game, lease: SessionOwnership.Lease, from presenter: UIViewController) {
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
        let persistence = JavaGamePersistenceAdapter(game: game)
        controller.onPreferencesChanged = { persistence.updatePreferences($0) }
        controller.onSessionClosed = { completion in persistence.checkpoint(completion: completion) }
        controller.saveDirectory = saveDirectory(identifier: game.identifier)
        controller.modalPresentationStyle = .fullScreen
        controller.sessionLease = lease
        game.playedDate = Date()
        game.managedObjectContext?.saveWithErrorLogging()
        presenter.present(controller, animated: true)
    }
    private static func savesAreReady(_ game: Game, from presenter: UIViewController) -> Bool {
        do { _ = try EmulationServices.prepare(game); return true }
        catch { showError(error.localizedDescription, from: presenter); return false }
    }
    static func showError(_ message: String, from presenter: UIViewController) {
        let alert = UIAlertController(title: "Java ME", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}
