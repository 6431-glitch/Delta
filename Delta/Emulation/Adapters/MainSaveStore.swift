import Foundation
import CoreData

/// Existing save metadata/file contracts, with engine writing injected by the caller.
enum MainSaveStore
{
    static func checkpoint(objectID id: NSManagedObjectID, context: NSManagedObjectContext,
                           writeState: (SaveState) -> Bool, copyState: (SaveState, SaveState) -> Bool)
    {
        context.performAndWait {
            do {
                guard let game = try context.existingObject(with: id) as? Game else { return }
                let request = SaveState.fetchRequest(for: game, type: .main)
                request.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.modifiedDate), ascending: false)]
                let existing = try context.fetch(request)
                let main = existing.first ?? SaveState(context: context)
                main.game = game; main.type = .main; main.name = String(localized: "Main Save")
                // Cloud conflicts must not leave several active main slots.
                for duplicate in existing.dropFirst() { duplicate.type = .general }
                guard writeState(main) else { if main.isInserted { context.delete(main) }; return }
                let limit = SaveState.autosaveLimit(for: game)
                let historyRequest = SaveState.fetchRequest(for: game, type: .auto)
                historyRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(SaveState.modifiedDate), ascending: false)]
                if limit > 0 {
                    let history = SaveState(context: context)
                    history.game = game; history.type = .auto
                    if !copyState(history, main) { context.delete(history) }
                }
                let history = try context.fetch(historyRequest)
                for old in history.dropFirst(limit) { context.delete(old) }
                try context.save()
            } catch { print("Main Save failed: \(error)") }
        }
    }
}
