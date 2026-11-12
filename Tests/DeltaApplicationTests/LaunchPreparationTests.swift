import XCTest
import DeltaDomain
@testable import DeltaApplication

final class LaunchPreparationTests: XCTestCase
{
    @MainActor func testCancellationAndLateSuccessCannotPresentOrReleaseNewOwnership() async throws
    {
        let ownership = SessionOwnership()
        let lease = try ownership.acquire(scope: "java")
        var presentations = 0, completions = 0
        let preparation = LaunchPreparation { _, result in
            completions += 1
            if case .success = result { presentations += 1 }
            else { ownership.release(lease) }
        }
        preparation.cancel(); preparation.cancel()
        let next = try ownership.acquire(scope: "java")
        preparation.complete(.success(()))
        preparation.complete(.failure(EmulationError.runtimeFailed))
        XCTAssertEqual(preparation.state, .cancelled)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(presentations, 0)
        XCTAssertTrue(ownership.isActive(scope: "java"))
        ownership.release(next)
    }

    @MainActor func testSuccessFailureAndReentrantCompletionAreDeliveredOnce() async throws
    {
        var count = 0
        var operation: LaunchPreparation?
        operation = LaunchPreparation { _, _ in count += 1; operation?.complete(.success(())) }
        operation!.complete(.failure(EmulationError.runtimeFailed))
        operation!.cancel()
        operation!.complete(.success(()))
        XCTAssertEqual(count, 1)
        XCTAssertEqual(operation!.state, .completed)
    }
}
