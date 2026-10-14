import Foundation
import DeltaCore
import GBADeltaCore
import GBCDeltaCore
import MelonDSDeltaCore

/// Vendor configuration stays beside the engine adapter, outside library presentation.
enum CoreConfigurationAdapter
{
    static func configure(_ core: EmulatorCore?, game: Game, preview: Bool = false)
    {
        guard let core else { return }
        if !preview, let bridge = core.deltaCore.emulatorBridge as? GBCEmulatorBridge
        {
            let palettes = Settings.preferredGBColorPalette?.palettes
            bridge.backgroundPalette = palettes?.0
            bridge.spritePalette = palettes?.1
            bridge.foregroundPalette = palettes?.2
        }
        if let bridge = core.deltaCore.emulatorBridge as? MelonDSEmulatorBridge
        {
            bridge.systemType = game.identifier == Game.melonDSDSiBIOSIdentifier ? .dsi : .ds
            bridge.isJITEnabled = ProcessInfo.processInfo.isJITAvailable
            if !preview
            {
                bridge.isWFCEnabled = true
                bridge.gbaGameURL = game.secondaryGame?.fileURL
                bridge.wfcDNS = Settings.preferredWFCServer
            }
        }
    }

    static func requiredFilesAvailable(for game: Game) -> Bool
    {
        guard game.type == .ds, Settings.preferredCore(for: .ds) == MelonDS.core else { return true }
        guard let firmware = CoreStorageAdapter.firmware(game.identifier) else { return true }
        return firmware.requiredFiles.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    static let gyroActivated = GBA.didActivateGyroNotification
    static let gyroDeactivated = GBA.didDeactivateGyroNotification
    static let onlineConnected = MelonDS.didConnectToWFCNotification
    static let onlineDisconnected = MelonDS.didDisconnectFromWFCNotification
    static func supportsJIT(_ core: EmulatorCore?) -> Bool { core?.deltaCore == MelonDS.core }

    static func renderingOptions(for game: GameProtocol) -> [EmulatorCore.Option: Any]
    {
        if let game = game as? Game, game.type == .n64
        {
            return game.settings[.openGLES2] as? Bool == true ? [.openGLES2: true] : [:]
        }
        var options: [EmulatorCore.Option: Any] = [.metal: ExperimentalFeatures.shared.metal.isEnabled]
        if #available(iOS 18, macOS 15, *), ProcessInfo.processInfo.isiOSAppOnMac { options[.metal] = true }
        return options
    }

    static func enableJIT(_ core: EmulatorCore, pause: () -> Void, resume: () -> Void)
    {
        guard let bridge = core.deltaCore.emulatorBridge as? MelonDSEmulatorBridge, !bridge.isJITEnabled else { return }
        guard core.state != .stopped else { bridge.isJITEnabled = true; return }
        let videoEnabled = core.videoManager.isEnabled
        core.videoManager.isEnabled = false
        defer { core.videoManager.isEnabled = videoEnabled }
        let wasRunning = core.state == .running
        if wasRunning { pause() }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let state = core.saveSaveState(to: file)
        core.stop()
        bridge.isJITEnabled = true
        core.start()
        core.pause()
        do { try core.load(state) }
        catch { print("Failed to restore state after enabling JIT: \(error)") }
        if wasRunning { resume() }
    }

    static var firmwareExists: Bool { FileManager.default.fileExists(atPath: MelonDSEmulatorBridge.shared.firmwareURL.path) }
    static func setWirelessServer(_ server: String, for core: EmulatorCore?)
    {
        (core?.deltaCore.emulatorBridge as? MelonDSEmulatorBridge)?.wfcDNS = server
    }
}
