import XCTest
@testable import DeltaDomain

final class SessionLifecycleTests: XCTestCase
{
    @MainActor func testLifecycleIncludesAsynchronousStopAndIdempotentCleanup() async throws
    {
        let lifecycle = SessionLifecycle()
        XCTAssertThrowsError(try lifecycle.transition(to: .paused))
        try lifecycle.transition(to: .running)
        try lifecycle.transition(to: .paused)
        try lifecycle.transition(to: .running)
        try lifecycle.transition(to: .stopping)
        XCTAssertThrowsError(try lifecycle.transition(to: .running))
        try lifecycle.transition(to: .stopped)
        try lifecycle.transition(to: .stopped)
        XCTAssertThrowsError(try lifecycle.transition(to: .running))
    }

    @MainActor func testFailureIsTerminal() async throws
    {
        let lifecycle = SessionLifecycle()
        try lifecycle.transition(to: .failed)
        XCTAssertThrowsError(try lifecycle.transition(to: .running))
        try lifecycle.transition(to: .failed)
    }

    @MainActor func testLeaseCannotReleaseAnotherSessionOrStartTwice() async throws
    {
        let ownership = SessionOwnership()
        let first = try ownership.acquire(scope: "java")
        XCTAssertThrowsError(try ownership.acquire(scope: "java"))
        ownership.release(first)
        let second = try ownership.acquire(scope: "java")
        ownership.release(first)
        XCTAssertTrue(ownership.isActive(scope: "java"))
        ownership.release(second)
        XCTAssertFalse(ownership.isActive(scope: "java"))
        _ = try ownership.acquire(scope: "nes")
        _ = try ownership.acquire(scope: "gba")
        XCTAssertTrue(ownership.isActive(scope: "nes"))
    }
}
