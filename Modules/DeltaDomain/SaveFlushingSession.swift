import Foundation

@MainActor public protocol SaveFlushingSession: EmulationSession
{
    func flushSave(to url: URL)
}
