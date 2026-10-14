import DeltaDomain
import Foundation
import CoreData

/// The runtime retains stable identity/context, not a live managed object across its lifetime.
@MainActor final class JavaGamePersistenceAdapter
{
    private let objectID: NSManagedObjectID
    private let context: NSManagedObjectContext?
    init(game: Game)
    {
        objectID = game.objectID
        context = game.managedObjectContext
    }
    private func game() -> Game?
    {
        guard let game = try? context?.existingObject(with: objectID) as? Game, !game.isDeleted else { return nil }
        return game
    }
    func updatePreferences(_ preferences: J2MEPreferences)
    {
        guard let game = game() else { return }
        var settings = game.gameSettings as? [String: Any] ?? [:]
        settings["j2me.preferences"] = preferences.json
        game.gameSettings = settings as NSDictionary
        game.managedObjectContext?.saveWithErrorLogging()
    }
    func checkpoint(completion: @escaping (Result<Void, Error>) -> Void)
    {
        guard let game = game() else { completion(.failure(EmulationError.gameNotFound)); return }
        J2MESaveStore.checkpoint(game, completion: completion)
    }
}
