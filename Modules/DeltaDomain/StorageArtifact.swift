import Foundation

/// IDs are part of the existing sync contract; adapters supply host paths.
public struct StorageArtifact: Hashable, Sendable
{
    public let identifier: String
    public let fileURL: URL
    public init(identifier: String, fileURL: URL)
    {
        self.identifier = identifier
        self.fileURL = fileURL
    }
}

public struct GameStorageSnapshot: Sendable
{
    public let gameURL: URL
    public let saveURL: URL
    public let artworkURL: URL
    public let backdropURL: URL?
    public init(gameURL: URL, saveURL: URL, artworkURL: URL, backdropURL: URL?)
    {
        self.gameURL = gameURL
        self.saveURL = saveURL
        self.artworkURL = artworkURL
        self.backdropURL = backdropURL
    }
}

public enum StorageArtifactPolicy
{
    public static func gameFiles(_ game: GameStorageSnapshot, content: [StorageArtifact]? = nil) -> Set<StorageArtifact>
    {
        var artifacts = Set(content ?? [StorageArtifact(identifier: "game", fileURL: game.gameURL)])
        artifacts.insert(StorageArtifact(identifier: "artwork", fileURL: game.artworkURL))
        if let backdrop = game.backdropURL, backdrop.isFileURL
        {
            artifacts.insert(StorageArtifact(identifier: "backdrop", fileURL: backdrop))
        }
        return artifacts
    }

    public static func saveFiles(_ game: GameStorageSnapshot, hasRTC: Bool) -> Set<StorageArtifact>
    {
        var artifacts: Set<StorageArtifact> = [StorageArtifact(identifier: "gameSave", fileURL: game.saveURL)]
        if hasRTC
        {
            artifacts.insert(StorageArtifact(identifier: "gameTimeSave", fileURL: game.saveURL.deletingPathExtension().appendingPathExtension("rtc")))
        }
        return artifacts
    }
}
