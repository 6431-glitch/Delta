import XCTest
import DeltaDomain
@testable import DeltaApplication

final class ActiveSessionRegistryTests: XCTestCase
{
    @MainActor func testRegistrationIsWeakAndFiltersInactiveSessions() async throws
    {
        let registry = ActiveSessionRegistry()
        var session: CallbackEmulationSession? = CallbackEmulationSession(start: {}, pause: { _ in }, stop: {})
        let token = registry.register(gameIdentifier: "game", session: session!)
        XCTAssertNil(registry.session(gameIdentifier: "game"))
        try session!.start()
        XCTAssertTrue(registry.session(gameIdentifier: "game") === session)
        try session!.pause()
        XCTAssertTrue(registry.session(gameIdentifier: "game") === session)
        XCTAssertNil(registry.session(gameIdentifier: "other"))
        session = nil
        XCTAssertNil(registry.session(gameIdentifier: "game"))
        registry.remove(token)
    }
    @MainActor func testRemovingOldRegistrationDoesNotRemoveReplacement() async throws
    {
        let registry = ActiveSessionRegistry()
        let first = CallbackEmulationSession(start: {}, pause: { _ in }, stop: {})
        let old = registry.register(gameIdentifier: "game", session: first)
        let second = CallbackEmulationSession(start: {}, pause: { _ in }, stop: {})
        try second.start()
        _ = registry.register(gameIdentifier: "game", session: second)
        registry.remove(old)
        XCTAssertTrue(registry.session(gameIdentifier: "game") === second)
    }
}
