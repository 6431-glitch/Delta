import Foundation
import DeltaDomain

public struct ImportInspection: Sendable
{
    public let displayName: String?
    public let artworkData: Data?
    /// Encoded adapter-owned configuration; persistence need not understand its engine schema.
    public let configurationData: Data?
    public init(displayName: String? = nil, artworkData: Data? = nil, configurationData: Data? = nil)
    {
        self.displayName = displayName
        self.artworkData = artworkData
        self.configurationData = configurationData
    }
}

public protocol GameContentInspector
{
    func inspect(_ url: URL) throws -> ImportInspection
}

public struct ImportCoordinator
{
    public enum Failure: Error, Equatable
    {
        case unsupportedContent
        case unreadableContent
        case invalidContent
    }

    private let registry: SystemRegistry
    private let inspectors: [String: any GameContentInspector]
    private let isReadable: (URL) -> Bool

    public init(registry: SystemRegistry, inspectors: [String: any GameContentInspector], isReadable: @escaping (URL) -> Bool)
    {
        self.registry = registry
        self.inspectors = inspectors
        self.isReadable = isReadable
    }

    public func inspect(_ url: URL) throws -> ImportInspection
    {
        guard let system = registry.system(fileExtension: url.pathExtension) else { throw Failure.unsupportedContent }
        guard isReadable(url) else { throw Failure.unreadableContent }
        return try inspectors[system.identifier]?.inspect(url) ?? ImportInspection()
    }
}
