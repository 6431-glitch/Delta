import Foundation
import DeltaDomain

/// Owns one asynchronous preparation result. Late callbacks cannot present a cancelled launch.
@MainActor public final class LaunchPreparation
{
    public enum State: Equatable { case pending, completed, cancelled }
    public let identifier = UUID()
    public private(set) var state: State = .pending
    private var completion: ((UUID, Result<Void, Error>) -> Void)?

    public init(completion: @escaping (UUID, Result<Void, Error>) -> Void)
    {
        self.completion = completion
    }
    public func complete(_ result: Result<Void, Error>)
    {
        guard state == .pending else { return }
        state = .completed
        deliver(result)
    }
    public func cancel()
    {
        guard state == .pending else { return }
        state = .cancelled
        deliver(.failure(EmulationError.cancelled))
    }
    private func deliver(_ result: Result<Void, Error>)
    {
        let callback = completion
        completion = nil
        callback?(identifier, result)
    }
}
