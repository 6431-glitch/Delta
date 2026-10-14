import Foundation

/// Every imported image must have a distinct, existing game/asset destination.
enum ArtworkImportValidation {
    static func canApply(assignments: [(game: String?, asset: String)], availableGames: Set<String>) -> Bool {
        guard !assignments.isEmpty else { return false }
        var covers = Set<String>()
        var backdrops = Set<String>()
        for assignment in assignments {
            guard let game = assignment.game, availableGames.contains(game) else { return false }
            switch assignment.asset {
            case "cover": guard covers.insert(game).inserted else { return false }
            case "backdrop": guard backdrops.insert(game).inserted else { return false }
            default: return false
            }
        }
        return true
    }
}
