import Foundation
import CoreData
import DeltaDomain
import DeltaApplication
import OperatorKit

/// Stateless adapter: managed objects stay on their context, active sessions are addressed by ID.
final class OperatorLibraryAdapter: OperatorLibraryService, Sendable
{
    func importROM(at url: URL) async throws -> String
    {
        return try await withCheckedThrowingContinuation { continuation in
            DatabaseManager.shared.importGames(at: [url]) { games, errors in
                if let game = games.first { continuation.resume(returning: game.identifier) }
                else { continuation.resume(throwing: errors.first ?? OperatorError.commandFailed) }
            }
        }
    }
    func saveURL(gameIdentifier: String) async -> URL?
    {
        return await MainActor.run { fetch(gameIdentifier, context: DatabaseManager.shared.viewContext)?.gameSaveURL }
    }
    func contains(gameIdentifier: String) async -> Bool
    {
        return await MainActor.run { fetch(gameIdentifier, context: DatabaseManager.shared.viewContext) != nil }
    }
    func delete(gameIdentifier: String, placeholderName: String, invalidateCache: @escaping () -> Void)
    {
        let remove: (NSManagedObjectContext) -> Void = { context in
            guard let game = self.fetch(gameIdentifier, context: context) else { return }
            if game.name == placeholderName { invalidateCache() }
            try? FileManager.default.removeItem(at: game.gameSaveURL)
            context.delete(game)
            try? context.save()
        }
        if Thread.isMainThread { remove(DatabaseManager.shared.viewContext) }
        else { DatabaseManager.shared.performBackgroundTask { remove($0) } }
    }
    @MainActor func flushSave(gameIdentifier: String)
    {
        guard let game = fetch(gameIdentifier, context: DatabaseManager.shared.viewContext),
              let session = EmulationServices.sessions.session(gameIdentifier: gameIdentifier) as? any SaveFlushingSession else { return }
        session.flushSave(to: game.gameSaveURL)
    }
    private func fetch(_ identifier: String, context: NSManagedObjectContext) -> Game?
    {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "identifier == %@", identifier)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
