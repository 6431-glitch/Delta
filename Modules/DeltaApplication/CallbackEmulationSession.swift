import Foundation
#if canImport(DeltaDomain)
import DeltaDomain
#endif

/// Native callbacks finish asynchronously; lease release follows save checkpoint and dismissal.
@MainActor public final class CallbackEmulationSession: EmulationSession
{
    private let lifecycle = SessionLifecycle()
    private let startRuntime: () -> Void
    private let pauseRuntime: (Bool) -> Void
    private let stopRuntime: () -> Void
    public var state: SessionState { lifecycle.state }

    public init(start: @escaping () -> Void, pause: @escaping (Bool) -> Void, stop: @escaping () -> Void)
    {
        startRuntime = start
        pauseRuntime = pause
        stopRuntime = stop
    }

    public func start() throws
    {
        guard state == .idle else { if state == .running { return }; throw EmulationError.invalidTransition(state, .running) }
        try lifecycle.transition(to: .running)
        startRuntime()
    }
    public func pause() throws
    {
        if state == .paused { return }
        try lifecycle.transition(to: .paused)
        pauseRuntime(true)
    }
    public func resume() throws
    {
        if state == .running { return }
        try lifecycle.transition(to: .running)
        pauseRuntime(false)
    }
    public func stop() throws
    {
        if state == .stopping || state == .stopped || state == .failed { return }
        try lifecycle.transition(to: .stopping)
        stopRuntime()
    }
    public func finish(failed: Bool)
    {
        if state == .stopped || state == .failed { return }
        if state != .stopping { try? lifecycle.transition(to: .stopping) }
        try? lifecycle.transition(to: failed ? .failed : .stopped)
    }
}
