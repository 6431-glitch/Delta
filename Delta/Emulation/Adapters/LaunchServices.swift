import Foundation
import CoreData
import Harmony
import DeltaCore

/// App composition. Domain/application code never resolves global services.
@MainActor enum EmulationServices
{
    static let ownership = SessionOwnership()
    static let javaScope = "runtime.javaME"
    static var isJavaActive: Bool { ownership.isActive(scope: javaScope) }

    static func prepare(_ game: Game) throws -> PreparedLaunch
    {
        guard let context = game.managedObjectContext else { throw EmulationError.gameNotFound }
        let adapter = ManagedLaunchAdapter(context: context, sync: SyncManager.shared.coordinator)
        let systemIdentifier = game.type.rawValue
        let runtimeAvailable = System(gameType: game.type)?.descriptor.runtime == .javaME || Delta.core(for: game.type) != nil
        let requiredFilesAvailable = CoreConfigurationAdapter.requiredFilesAvailable(for: game)
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: adapter, saves: adapter,
            isReadable: { FileManager.default.isReadableFile(atPath: $0.path) },
            validateRuntime: { _ in
                guard runtimeAvailable else {
                    throw EmulationError.unsupportedSystem(systemIdentifier)
                }
                guard requiredFilesAvailable else { throw EmulationError.missingRequiredFiles }
            })
        return try coordinator.prepare(gameIdentifier: game.identifier)
    }
}

/// Short-lived bridge. All managed reads occur synchronously on the caller's main context.
@MainActor private struct ManagedLaunchAdapter: LaunchRepository, SaveReadiness
{
    let context: NSManagedObjectContext
    let sync: SyncCoordinator?

    private func fetch(_ identifier: String) throws -> Game?
    {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "identifier == %@", identifier)
        return try context.fetch(request).first
    }

    func launchGame(identifier: String) throws -> LaunchGame?
    {
        guard let game = try fetch(identifier), !game.isDeleted else { return nil }
        return LaunchGame(identifier: identifier, systemIdentifier: game.type.rawValue, fileURL: game.fileURL,
                          requiresContentFile: CoreStorageAdapter.firmware(game.identifier) == nil)
    }

    func savesAreReady(gameIdentifier: String) throws -> Bool
    {
        guard let game = try fetch(gameIdentifier), !game.isDeleted else { throw EmulationError.gameNotFound }
        guard let sync, sync.isSyncing, let save = game.gameSave else { return true }
        guard let record = try sync.recordController.fetchRecords(for: [save]).first else { return true }
        return !(record.isSyncingEnabled && !record.isConflicted && (record.localStatus == nil || record.remoteStatus == .updated))
    }
}
