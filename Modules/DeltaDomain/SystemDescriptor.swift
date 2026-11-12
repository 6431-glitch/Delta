import Foundation

public enum RuntimeKind: String, Codable, Sendable
{
    case deltaCore
    case javaME
}

public enum StorageKind: String, Codable, Sendable
{
    case singleSaveFile
    case directoryArchive
}

public enum EmulationCapability: String, Codable, Hashable, Sendable
{
    case saveStates
    case cheats
    case fastForward
    case colorPalette
    case wirelessNetworking
    case secondaryCartridge
}

/// Stable identity and engine support. UI/account policy may further restrict a capability.
public struct SystemDescriptor: Equatable, Sendable
{
    public let identifier: String
    public let preferenceKey: String
    public let name: String
    public let shortName: String
    public let displayName: String
    public let year: Int
    public let fileExtensions: Set<String>
    public let runtime: RuntimeKind
    public let capabilities: Set<EmulationCapability>

    public init(identifier: String, preferenceKey: String, name: String, shortName: String,
                displayName: String, year: Int, fileExtensions: Set<String>, runtime: RuntimeKind,
                capabilities: Set<EmulationCapability>)
    {
        self.identifier = identifier
        self.preferenceKey = preferenceKey
        self.name = name
        self.shortName = shortName
        self.displayName = displayName
        self.year = year
        self.fileExtensions = Set(fileExtensions.map { $0.lowercased() })
        self.runtime = runtime
        self.capabilities = capabilities
    }

    public var storage: StorageKind { runtime == .javaME ? .directoryArchive : .singleSaveFile }

    public func allows(_ capability: EmulationCapability, restrictedBy policy: Set<EmulationCapability> = []) -> Bool
    {
        return capabilities.contains(capability) && !policy.contains(capability)
    }
}

public struct SystemRegistry: Sendable
{
    public enum RegistrationError: Error, Equatable
    {
        case duplicateIdentifier(String)
        case duplicatePreferenceKey(String)
        case ambiguousExtension(String)
    }

    public let systems: [SystemDescriptor]
    private let byIdentifier: [String: SystemDescriptor]
    private let byExtension: [String: SystemDescriptor]

    public init(_ systems: [SystemDescriptor]) throws
    {
        var identifiers = [String: SystemDescriptor]()
        var extensions = [String: SystemDescriptor]()
        var preferences = Set<String>()
        for system in systems
        {
            guard identifiers[system.identifier] == nil else { throw RegistrationError.duplicateIdentifier(system.identifier) }
            guard preferences.insert(system.preferenceKey).inserted else { throw RegistrationError.duplicatePreferenceKey(system.preferenceKey) }
            for fileExtension in system.fileExtensions
            {
                guard extensions[fileExtension] == nil else { throw RegistrationError.ambiguousExtension(fileExtension) }
                extensions[fileExtension] = system
            }
            identifiers[system.identifier] = system
        }
        self.systems = systems
        self.byIdentifier = identifiers
        self.byExtension = extensions
    }

    public func system(identifier: String) -> SystemDescriptor?
    {
        return byIdentifier[identifier]
    }

    public func system(fileExtension: String) -> SystemDescriptor?
    {
        return byExtension[fileExtension.lowercased()]
    }
}

public enum BuiltInSystems
{
    // Preserve persisted GameType values, preference keys, names, and ordering.
    public static let descriptors: [SystemDescriptor] = [
        console("nes", name: "Nintendo", shortName: "NES", displayName: "NES", year: 1985, extensions: ["nes"]),
        console("genesis", name: "Sega Genesis", shortName: "Genesis (Beta)", displayName: "Sega Genesis", year: 1989, extensions: ["gen", "bin", "md", "smd"]),
        console("snes", name: "Super Nintendo", shortName: "SNES", displayName: "Super Nintendo", year: 1990, extensions: ["smc", "sfc", "fig"]),
        console("n64", name: "Nintendo 64", shortName: "N64", displayName: "Nintendo 64", year: 1996, extensions: ["n64", "z64"]),
        console("gbc", name: "Game Boy Color", shortName: "GBC", displayName: "Game Boy Color", year: 1998, extensions: ["gbc", "gb"], extra: [.colorPalette]),
        console("gba", name: "Game Boy Advance", shortName: "GBA", displayName: "Game Boy Advance", year: 2001, extensions: ["gba"]),
        console("ds", name: "Nintendo DS", shortName: "DS", displayName: "Nintendo DS", year: 2004, extensions: ["ds", "nds"], extra: [.wirelessNetworking, .secondaryCartridge]),
        SystemDescriptor(identifier: "page.ducnguyen.delta.j2me", preferenceKey: "j2me", name: "Java ME", shortName: "J2ME", displayName: "Java ME", year: 2000, fileExtensions: ["jar"], runtime: .javaME, capabilities: [])
    ]

    /// Registration errors here indicate invalid checked-in composition, never game content.
    public static let registry: SystemRegistry = {
        do { return try SystemRegistry(descriptors) }
        catch { preconditionFailure("Invalid built-in system descriptors: \(error)") }
    }()

    private static func console(_ key: String, name: String, shortName: String, displayName: String,
                                year: Int, extensions: Set<String>, extra: Set<EmulationCapability> = []) -> SystemDescriptor
    {
        return SystemDescriptor(identifier: "com.rileytestut.delta.game." + key, preferenceKey: key,
                                name: name, shortName: shortName, displayName: displayName, year: year,
                                fileExtensions: extensions, runtime: .deltaCore,
                                capabilities: Set([.saveStates, .cheats, .fastForward]).union(extra))
    }
}
