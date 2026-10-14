import Foundation
import DeltaCore

@MainActor final class DeltaCoreSessionAdapter: EmulationSession
{
    let core: EmulatorCore
    init(core: EmulatorCore) { self.core = core }
    var state: SessionState {
        switch core.state
        {
        case .running: return .running
        case .paused: return .paused
        case .stopped: return .stopped
        @unknown default: return .failed
        }
    }
    func start() throws { if state != .running, !core.start() { throw EmulationError.runtimeFailed } }
    func pause() throws { if state == .running, !core.pause() { throw EmulationError.runtimeFailed } }
    func resume() throws { if state == .paused, !core.resume() { throw EmulationError.runtimeFailed } }
    func stop() throws { if state != .stopped, !core.stop() { throw EmulationError.runtimeFailed } }
}

