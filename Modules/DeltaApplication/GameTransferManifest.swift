import Foundation
import OSLog

/// Portable metadata only. No managed object archives, account state, or absolute sandbox URLs.
public struct GameTransferManifest: Codable, Sendable {
    public var version = 1
    public var rootIdentifier: String
    public var games: [GameRecord]
    public var files: [FileRecord] = []

    public init(rootIdentifier: String, games: [GameRecord]) { self.rootIdentifier = rootIdentifier; self.games = games }
    public struct FileRecord: Codable, Sendable {
        public var path: String
        public var byteCount: UInt64
        public var sha256: String
        public init(path: String, byteCount: UInt64, sha256: String) { self.path = path; self.byteCount = byteCount; self.sha256 = sha256 }
    }
    public struct Artwork: Codable, Sendable {
        public var file: String?
        public var remoteURL: String?
        public init(file: String? = nil, remoteURL: String? = nil) { self.file = file; self.remoteURL = remoteURL }
    }
    public struct GameRecord: Codable, Sendable {
        public var identifier: String
        public var gameType: String
        public var filename: String
        public var name: String
        public var isFavorite: Bool
        public var playedDate: Date?
        public var settings: Data?
        public var artwork: Artwork?
        public var backdrop: Artwork?
        public var collectionIndex: Int16
        public var secondaryIdentifier: String?
        public var previewStateIdentifier: String?
        public var saveModifiedDate: Date?
        public var states: [State] = []
        public var cheats: [Cheat] = []
        public var skins: [Skin] = []
        public init(identifier: String, gameType: String, filename: String, name: String, isFavorite: Bool, collectionIndex: Int16) {
            self.identifier = identifier; self.gameType = gameType; self.filename = filename
            self.name = name; self.isFavorite = isFavorite; self.collectionIndex = collectionIndex
        }
    }
    public struct State: Codable, Sendable {
        public var identifier: String
        public var filename: String
        public var name: String?
        public var type: Int16
        public var creationDate: Date
        public var modifiedDate: Date
        public var coreIdentifier: String?
        public var coreVersion: String?
        public var tagsRaw: String?
        public var sortPosition: Double
        public init(identifier: String, filename: String, name: String?, type: Int16, creationDate: Date, modifiedDate: Date, coreIdentifier: String?, coreVersion: String?, tagsRaw: String?, sortPosition: Double) {
            self.identifier = identifier; self.filename = filename; self.name = name; self.type = type
            self.creationDate = creationDate; self.modifiedDate = modifiedDate; self.coreIdentifier = coreIdentifier
            self.coreVersion = coreVersion; self.tagsRaw = tagsRaw; self.sortPosition = sortPosition
        }
    }
    public struct Cheat: Codable, Sendable {
        public var identifier: String
        public var name: String
        public var code: String
        public var type: String
        public var isEnabled: Bool
        public var symbolName: String?
        public var creationDate: Date
        public var modifiedDate: Date
        public init(identifier: String, name: String, code: String, type: String, isEnabled: Bool, symbolName: String?, creationDate: Date, modifiedDate: Date) {
            self.identifier = identifier; self.name = name; self.code = code; self.type = type
            self.isEnabled = isEnabled; self.symbolName = symbolName; self.creationDate = creationDate; self.modifiedDate = modifiedDate
        }
    }
    public struct Skin: Codable, Sendable {
        public var relationship: String
        public var identifier: String
        public var name: String
        public var filename: String
        public var isStandard: Bool
        public var configurations: Int16
        public init(relationship: String, identifier: String, name: String, filename: String, isStandard: Bool, configurations: Int16) {
            self.relationship = relationship; self.identifier = identifier; self.name = name; self.filename = filename
            self.isStandard = isStandard; self.configurations = configurations
        }
    }
    public static let skinRelationships: Set<String> = ["preferredPortraitSkin", "preferredLandscapeSkin", "preferredSplitViewPortraitSkin", "preferredSplitViewLandscapeSkin", "preferredExternalControllerPortraitSkin", "preferredExternalControllerLandscapeSkin"]
    public static func safePath(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("\\") && !path.contains(":") && !path.contains("\0") && !path.hasPrefix("/") &&
        path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }
    public func validate() throws {
        func require(_ condition: Bool, line: Int = #line) throws {
            if !condition {
                Logger(subsystem: "com.rileytestut.Delta", category: "Transfer").error("Manifest validation failed at rule line \(line, privacy: .public); version=\(version, privacy: .public), games=\(games.count, privacy: .public), files=\(files.count, privacy: .public)")
                throw GameTransferError.invalidPackage
            }
        }
        try require(version == 1 && !games.isEmpty && games.count <= 1000 && games.contains { $0.identifier == rootIdentifier })
        try require(Set(games.map(\.identifier)).count == games.count && files.count <= 20000)
        let ids = Set(games.map(\.identifier))
        var required = Set<String>(), allowedSkins = Set<String>(), artworkPaths = Set<String>()
        var stateIDs = Set<String>(), cheatIDs = Set<String>()
        for game in games {
            try require(game.identifier.count == 40 && game.identifier.allSatisfy { "0123456789abcdef".contains($0) })
            try require(Self.safePath(game.filename) && !game.filename.contains("/") && game.filename.hasPrefix(game.identifier + "."))
            try require(!game.gameType.isEmpty && !game.gameType.contains("/") && Self.safePath(game.gameType))
            try require(!game.name.isEmpty && game.name.count <= 4096 && (game.settings?.count ?? 0) <= 4 * 1024 * 1024)
            try require(game.secondaryIdentifier.map { ids.contains($0) } ?? true)
            if let settings = game.settings {
                let value = try PropertyListSerialization.propertyList(from: settings, format: nil)
                try require(value is [String: Any])
            }
            required.insert("Games/" + game.filename)
            try require(Set(game.states.map { $0.filename.lowercased() }).count == game.states.count)
            for (asset, kind) in [(game.artwork, "cover"), (game.backdrop, "backdrop")] {
                if let file = asset?.file {
                    try require(Self.safePath(file) && !file.dropFirst("Games/".count).contains("/") && file.hasPrefix("Games/" + game.identifier + "-transfer-" + kind + "."))
                    required.insert(file); artworkPaths.insert(file)
                }
                if let remote = asset?.remoteURL {
                    try require(URL(string: remote).map { ["https", "http"].contains($0.scheme?.lowercased() ?? "") && $0.host != nil } ?? false)
                }
            }
            for state in game.states {
                try require(!state.identifier.isEmpty && stateIDs.insert(state.identifier).inserted)
                try require(Self.safePath(state.filename) && !state.filename.contains("/") && (0...4).contains(state.type) && state.sortPosition.isFinite)
                required.insert("Save States/" + game.identifier + "/" + state.filename)
            }
            try require(game.previewStateIdentifier.map { id in game.states.contains { $0.identifier == id } } ?? true)
            for cheat in game.cheats { try require(!cheat.identifier.isEmpty && cheatIDs.insert(cheat.identifier).inserted && !cheat.type.isEmpty) }
            try require(Set(game.skins.map(\.relationship)).count == game.skins.count)
            for skin in game.skins {
                try require(Self.skinRelationships.contains(skin.relationship) && !skin.identifier.isEmpty && Self.safePath(skin.filename) && !skin.filename.contains("/"))
                if !skin.isStandard { let path = "Controller Skins/" + game.gameType + "/" + skin.filename; required.insert(path); allowedSkins.insert(path) }
            }
        }
        var paths = Set<String>(), foldedPaths = Set<String>(), total: UInt64 = 0
        for file in files {
            try require(Self.safePath(file.path) && paths.insert(file.path).inserted && foldedPaths.insert(file.path.lowercased()).inserted)
            try require(file.byteCount <= 2 * 1024 * 1024 * 1024 && file.sha256.count == 64 && file.sha256.allSatisfy { "0123456789abcdef".contains($0) })
            total += file.byteCount
            try require(total <= 8 * 1024 * 1024 * 1024)
            let owned = games.contains { game in
                let id = game.identifier
                return (file.path.hasPrefix("Games/" + id + ".") && !file.path.dropFirst(6).contains("/")) ||
                    file.path.hasPrefix("Save States/" + id + "/") || file.path.hasPrefix("Games/J2ME/" + id + "/") ||
                    file.path == "Games/J2ME/" + id + ".receipt" || file.path == "Games/J2ME/" + id + "-recovery.j2mebackup"
            }
            try require(owned || allowedSkins.contains(file.path) || artworkPaths.contains(file.path))
        }
        try require(required.isSubset(of: paths))
    }
}

public enum GameTransferError: LocalizedError {
    case invalidPackage, unsupportedVersion, gameInUse, missingFile, incompatibleGame, busy, emptyLibrary
    public var errorDescription: String? {
        switch self {
        case .invalidPackage: return String(localized: "This game transfer is incomplete, damaged, or contains unsupported data.")
        case .unsupportedVersion: return String(localized: "This game transfer requires a newer version of Delta.")
        case .gameInUse: return String(localized: "Close the game in every window before transferring or restoring it.")
        case .missingFile: return String(localized: "Download all of this game's files before transferring it.")
        case .incompatibleGame: return String(localized: "This transfer conflicts with an existing game, save state, or controller skin.")
        case .emptyLibrary: return String(localized: "Your library has no games to transfer.")
        case .busy: return String(localized: "Another game transfer is still in progress.")
        }
    }
}
