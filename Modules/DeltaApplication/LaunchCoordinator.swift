import Foundation
import DeltaDomain

public struct LaunchGame: Equatable, Sendable
{
    public let identifier: String
    public let systemIdentifier: String
    public let fileURL: URL
    public let requiresContentFile: Bool
    public init(identifier: String, systemIdentifier: String, fileURL: URL, requiresContentFile: Bool = true)
    {
        self.identifier = identifier
        self.systemIdentifier = systemIdentifier
        self.fileURL = fileURL
        self.requiresContentFile = requiresContentFile
    }
}

@MainActor public protocol LaunchRepository
{
    func launchGame(identifier: String) throws -> LaunchGame?
}

@MainActor public protocol SaveReadiness
{
    func savesAreReady(gameIdentifier: String) throws -> Bool
}

public struct PreparedLaunch: Sendable
{
    public let game: LaunchGame
    public let system: SystemDescriptor
}

/// Both library and deep links use this preflight; UI routes and native policy remain adapters.
@MainActor public final class LaunchCoordinator
{
    private let registry: SystemRegistry
    private let repository: any LaunchRepository
    private let saves: any SaveReadiness
    private let isReadable: (URL) -> Bool
    private let validateRuntime: (LaunchGame) throws -> Void

    public init(registry: SystemRegistry, repository: any LaunchRepository, saves: any SaveReadiness,
                isReadable: @escaping (URL) -> Bool, validateRuntime: @escaping (LaunchGame) throws -> Void)
    {
        self.registry = registry
        self.repository = repository
        self.saves = saves
        self.isReadable = isReadable
        self.validateRuntime = validateRuntime
    }

    public func prepare(gameIdentifier: String) throws -> PreparedLaunch
    {
        guard let game = try repository.launchGame(identifier: gameIdentifier) else { throw EmulationError.gameNotFound }
        guard let system = registry.system(identifier: game.systemIdentifier) else { throw EmulationError.unsupportedSystem(game.systemIdentifier) }
        guard !game.requiresContentFile || isReadable(game.fileURL) else { throw EmulationError.missingGameFile }
        guard try saves.savesAreReady(gameIdentifier: game.identifier) else { throw EmulationError.savesUnavailable }
        try validateRuntime(game)
        return PreparedLaunch(game: game, system: system)
    }
}
