import Foundation

public enum SessionState: String, Sendable
{
    case idle, running, paused, stopping, stopped, failed
}

public enum EmulationError: Error, Equatable, LocalizedError
{
    case cancelled
    case capabilityUnavailable(EmulationCapability)
    case gameNotFound
    case unsupportedSystem(String)
    case missingGameFile
    case savesUnavailable
    case missingRequiredFiles
    case sessionBusy
    case invalidTransition(SessionState, SessionState)
    case runtimeFailed

    public var errorDescription: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The launch was cancelled.", comment: "Emulation lifecycle error")
        case .capabilityUnavailable: return NSLocalizedString("This action is not supported by the current runtime.", comment: "Emulation lifecycle error")
        case .gameNotFound: return NSLocalizedString("The game is no longer in the library.", comment: "Emulation lifecycle error")
        case .unsupportedSystem: return NSLocalizedString("This game's system is not available.", comment: "Emulation lifecycle error")
        case .missingGameFile: return NSLocalizedString("The game file is not available on this device yet.", comment: "Emulation lifecycle error")
        case .savesUnavailable: return NSLocalizedString("Wait for this game's saves to finish downloading before opening it.", comment: "Emulation lifecycle error")
        case .missingRequiredFiles: return NSLocalizedString("Required system files are missing.", comment: "Emulation lifecycle error")
        case .sessionBusy: return NSLocalizedString("A game is already running in this runtime.", comment: "Emulation lifecycle error")
        case .invalidTransition: return NSLocalizedString("The requested operation is unavailable in the current session state.", comment: "Emulation lifecycle error")
        case .runtimeFailed: return NSLocalizedString("The game runtime could not complete the operation.", comment: "Emulation lifecycle error")
        }
    }
}

/// Lifecycle calls belong to the UI/session executor; engine callbacks stay in their adapter.
@MainActor public protocol EmulationSession: AnyObject
{
    var state: SessionState { get }
    func start() throws
    func pause() throws
    func resume() throws
    /// May complete asynchronously. `stopping` owns native state until cleanup finishes.
    func stop() throws
}

@MainActor public final class SessionLifecycle
{
    public private(set) var state: SessionState = .idle
    public init() {}

    public func transition(to next: SessionState) throws
    {
        if state == next { return }
        let allowed: Bool
        switch (state, next)
        {
        case (.idle, .running), (.running, .paused), (.paused, .running),
             (.idle, .stopping), (.running, .stopping), (.paused, .stopping),
             (.stopping, .stopped), (.stopping, .failed),
             (.idle, .failed), (.running, .failed), (.paused, .failed): allowed = true
        default: allowed = false
        }
        guard allowed else { throw EmulationError.invalidTransition(state, next) }
        state = next
    }
}

/// Explicit exclusive ownership for native engines with process-global state.
@MainActor public final class SessionOwnership
{
    public struct Lease: Equatable, Sendable
    {
        public let scope: String
        public let token: UUID
    }

    private var leases = [String: Lease]()
    public init() {}
    public func isActive(scope: String) -> Bool { leases[scope] != nil }

    public func acquire(scope: String) throws -> Lease
    {
        guard leases[scope] == nil else { throw EmulationError.sessionBusy }
        let lease = Lease(scope: scope, token: UUID())
        leases[scope] = lease
        return lease
    }

    public func release(_ lease: Lease)
    {
        guard leases[lease.scope] == lease else { return }
        leases[lease.scope] = nil
    }
}
