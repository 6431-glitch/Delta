import Foundation
import DeltaDomain

/// Weak registration avoids making device integrations own gameplay lifetime.
@MainActor public final class ActiveSessionRegistry
{
    private final class Entry
    {
        let gameIdentifier: String
        weak var session: (any EmulationSession)?
        init(gameIdentifier: String, session: any EmulationSession)
        {
            self.gameIdentifier = gameIdentifier
            self.session = session
        }
    }
    private var entries = [UUID: Entry]()
    public init() {}
    public func register(gameIdentifier: String, session: any EmulationSession) -> UUID
    {
        let token = UUID()
        entries[token] = Entry(gameIdentifier: gameIdentifier, session: session)
        return token
    }
    public func remove(_ token: UUID) { entries[token] = nil }
    public func session(gameIdentifier: String) -> (any EmulationSession)?
    {
        entries = entries.filter { $0.value.session != nil }
        return entries.values.first { $0.gameIdentifier == gameIdentifier && ($0.session?.state == .running || $0.session?.state == .paused) }?.session
    }
}
