import XCTest
import DeltaDomain
@testable import DeltaApplication

final class CallbackSessionTests: XCTestCase
{
    @MainActor func testRuntimeStartsOnceAndStopsOnlyOnceUntilCheckpointCompletes() async throws
    {
        var starts = 0, stops = 0
        var pauses = [Bool]()
        let session = CallbackEmulationSession(start: { starts += 1 }, pause: { pauses.append($0) }, stop: { stops += 1 })
        XCTAssertThrowsError(try session.pause())
        try session.start(); try session.start()
        try session.pause(); try session.pause()
        try session.resume(); try session.resume()
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(pauses, [true, false])
        try session.stop(); try session.stop()
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(session.state, .stopping)
        XCTAssertThrowsError(try session.resume())
        session.finish(failed: false)
        session.finish(failed: true)
        XCTAssertEqual(session.state, .stopped)
        try session.stop()
        XCTAssertEqual(stops, 1)
    }

    @MainActor func testSpontaneousRuntimeExitAndFailedCheckpointFinishOwnership() async throws
    {
        let session = CallbackEmulationSession(start: {}, pause: { _ in }, stop: {})
        try session.start()
        session.finish(failed: true)
        XCTAssertEqual(session.state, .failed)
        XCTAssertThrowsError(try session.start())
        session.finish(failed: false)
        XCTAssertEqual(session.state, .failed)
    }
}
