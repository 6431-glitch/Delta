import Foundation
import DeltaCore

/// App composition. Domain/application code never resolves global services.
@MainActor enum EmulationServices
{
    static let ownership = SessionOwnership()
    static let javaScope = "runtime.javaME"
    static var isJavaActive: Bool { ownership.isActive(scope: javaScope) }

    static func prepare(_ game: Game) throws -> PreparedLaunch
    {
        let adapter = ManagedLaunchAdapter(game: game)
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: adapter, saves: adapter,
            isReadable: { FileManager.default.isReadableFile(atPath: $0.path) },
            validateRuntime: { _ in
                guard System(gameType: game.type)?.descriptor.runtime == .javaME || Delta.core(for: game.type) != nil else {
                    throw EmulationError.unsupportedSystem(game.type.rawValue)
                }
                guard CoreConfigurationAdapter.requiredFilesAvailable(for: game) else { throw EmulationError.missingRequiredFiles }
            })
        return try coordinator.prepare(gameIdentifier: game.identifier)
    }
}

/// Short-lived bridge. All managed reads occur synchronously on the caller's main context.
@MainActor private struct ManagedLaunchAdapter: LaunchRepository, SaveReadiness
{
    let game: Game
    func launchGame(identifier: String) -> LaunchGame?
    {
        guard !game.isDeleted, game.identifier == identifier else { return nil }
        return LaunchGame(identifier: identifier, systemIdentifier: game.type.rawValue, fileURL: game.fileURL, requiresContentFile: game.identifier != Game.melonDSBIOSIdentifier && game.identifier != Game.melonDSDSiBIOSIdentifier)
    }

    func savesAreReady(gameIdentifier: String) throws -> Bool
    {
        guard game.identifier == gameIdentifier else { throw EmulationError.gameNotFound }
        guard let coordinator = SyncManager.shared.coordinator, coordinator.isSyncing, let save = game.gameSave else { return true }
        guard let record = try coordinator.recordController.fetchRecords(for: [save]).first else { return true }
        return !(record.isSyncingEnabled && !record.isConflicted && (record.localStatus == nil || record.remoteStatus == .updated))
    }
}
