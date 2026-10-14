import Foundation
import DeltaCore
import MelonDSDeltaCore

/// Native artifact lookup stays in the adapter; managed models consume neutral descriptions.
enum CoreStorageAdapter
{
    struct FirmwareLaunch
    {
        let identifier: String
        let name: String
        let filename: String
        let requiredFiles: [URL]
        let syncFiles: [StorageArtifact]
    }

    static func firmware(_ identifier: String) -> FirmwareLaunch?
    {
        let bridge = MelonDSEmulatorBridge.shared
        switch identifier
        {
        case Game.melonDSBIOSIdentifier:
            return FirmwareLaunch(identifier: identifier, name: NSLocalizedString("Home Screen", comment: ""), filename: "nds.bios",
                requiredFiles: [bridge.bios7URL, bridge.bios9URL, bridge.firmwareURL],
                syncFiles: [StorageArtifact(identifier: "bios7", fileURL: bridge.bios7URL), StorageArtifact(identifier: "bios9", fileURL: bridge.bios9URL), StorageArtifact(identifier: "firmware", fileURL: bridge.firmwareURL)])
        case Game.melonDSDSiBIOSIdentifier:
            // Preserve the existing policy: NAND is required locally but excluded from sync.
            return FirmwareLaunch(identifier: identifier, name: NSLocalizedString("Home Screen (DSi)", comment: ""), filename: "dsi.bios",
                requiredFiles: [bridge.dsiBIOS7URL, bridge.dsiBIOS9URL, bridge.dsiFirmwareURL, bridge.dsiNANDURL],
                syncFiles: [StorageArtifact(identifier: "bios7", fileURL: bridge.dsiBIOS7URL), StorageArtifact(identifier: "bios9", fileURL: bridge.dsiBIOS9URL), StorageArtifact(identifier: "firmware", fileURL: bridge.dsiFirmwareURL)])
        default: return nil
        }
    }

    static func firmwareLaunches(for core: DeltaCoreProtocol) -> [FirmwareLaunch]
    {
        guard core == MelonDS.core else { return [] }
        var identifiers = [Game.melonDSBIOSIdentifier]
        #if BETA
        identifiers.append(Game.melonDSDSiBIOSIdentifier)
        #endif
        return identifiers.compactMap(firmware)
    }

    static func snapshot(_ game: Game) -> GameStorageSnapshot
    {
        let artwork = game.artworkURL.flatMap { $0.isFileURL ? $0 : nil } ?? DatabaseManager.artworkURL(for: game)
        return GameStorageSnapshot(gameURL: game.fileURL, saveURL: game.gameSaveURL, artworkURL: artwork, backdropURL: game.backdropURL)
    }

    static func gameFiles(_ game: Game) -> Set<StorageArtifact>
    {
        return StorageArtifactPolicy.gameFiles(snapshot(game), content: firmware(game.identifier)?.syncFiles)
    }

    static func saveFiles(_ game: Game) -> Set<StorageArtifact>
    {
        return StorageArtifactPolicy.saveFiles(snapshot(game), hasRTC: System(gameType: game.type)?.rawValue == "gbc")
    }

    static func runtimeDirectories(_ game: Game) -> [URL]
    {
        guard System(gameType: game.type)?.descriptor.storage == .directoryArchive else { return [] }
        return [javaSaveDirectory(identifier: game.identifier)]
    }

    static func javaSaveDirectory(identifier: String) -> URL
    {
        return DatabaseManager.gamesDirectoryURL.appendingPathComponent("J2ME", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
    }
}
