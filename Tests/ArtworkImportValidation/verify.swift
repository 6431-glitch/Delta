import Foundation

@main struct Checks {
    static func main() {
        let games: Set<String> = ["first", "second"]
        let cases: [([(String?, String)], Bool)] = [
            ([], false),
            ([(nil, "cover")], false),
            ([("deleted", "cover")], false),
            ([("first", "cover")], true),
            ([("first", "cover"), ("first", "backdrop")], true),
            ([("first", "cover"), ("first", "cover")], false),
            ([("first", "backdrop"), ("first", "backdrop")], false),
            ([("first", "cover"), ("second", "cover")], true),
            ([("first", "cover"), (nil, "backdrop")], false),
            ([("first", "unknown")], false)
        ]
        for (index, entry) in cases.enumerated() {
            precondition(ArtworkImportValidation.canApply(assignments: entry.0, availableGames: games) == entry.1, "Assignment contract \(index) failed")
        }
        print("10 artwork assignment checks passed")
    }
}
