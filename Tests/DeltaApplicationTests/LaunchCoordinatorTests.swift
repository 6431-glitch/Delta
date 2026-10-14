import XCTest
import DeltaDomain
@testable import DeltaApplication

@MainActor private final class Library: LaunchRepository, SaveReadiness
{
    var game: LaunchGame? = LaunchGame(identifier: "game", systemIdentifier: "com.rileytestut.delta.game.nes", fileURL: URL(fileURLWithPath: "/fixture.nes"))
    var ready = true
    var failure: Error?
    func launchGame(identifier: String) -> LaunchGame? { game?.identifier == identifier ? game : nil }
    func savesAreReady(gameIdentifier: String) throws -> Bool {
        if let failure { throw failure }
        return ready
    }
}

final class LaunchCoordinatorTests: XCTestCase
{
    @MainActor func testPreflightUsesRepositoryAndReadinessWithoutPresentation() async throws
    {
        let library = Library()
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: library, saves: library, isReadable: { _ in true }, validateRuntime: { _ in })
        XCTAssertEqual(try coordinator.prepare(gameIdentifier: "game").system.runtime, .deltaCore)
        library.game = LaunchGame(identifier: "game", systemIdentifier: "page.ducnguyen.delta.j2me", fileURL: URL(fileURLWithPath: "/fixture.jar"))
        XCTAssertEqual(try coordinator.prepare(gameIdentifier: "game").system.runtime, .javaME)
        library.ready = false
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "game")) { XCTAssertEqual($0 as? EmulationError, .savesUnavailable) }
    }

    @MainActor func testUnknownMissingAndUnreadableGamesNeverConfigureRuntime() async throws
    {
        let library = Library()
        var configured = false
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: library, saves: library, isReadable: { _ in false }, validateRuntime: { _ in configured = true })
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "missing")) { XCTAssertEqual($0 as? EmulationError, .gameNotFound) }
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "game")) { XCTAssertEqual($0 as? EmulationError, .missingGameFile) }
        library.game = LaunchGame(identifier: "game", systemIdentifier: "test.unknown", fileURL: URL(fileURLWithPath: "/fixture"))
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "game")) { XCTAssertEqual($0 as? EmulationError, .unsupportedSystem("test.unknown")) }
        XCTAssertFalse(configured)
    }

    @MainActor func testFirmwareLaunchDoesNotRequireAnArtificialROMFile() async throws
    {
        let library = Library()
        library.game = LaunchGame(identifier: "game", systemIdentifier: "com.rileytestut.delta.game.ds", fileURL: URL(fileURLWithPath: "/virtual.bios"), requiresContentFile: false)
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: library, saves: library, isReadable: { _ in false }, validateRuntime: { _ in })
        XCTAssertEqual(try coordinator.prepare(gameIdentifier: "game").system.runtime, .deltaCore)
    }

    @MainActor func testReadinessFailureAndRuntimeConfigurationFailurePropagate() async throws
    {
        let library = Library()
        library.failure = EmulationError.runtimeFailed
        let coordinator = LaunchCoordinator(registry: BuiltInSystems.registry, repository: library, saves: library, isReadable: { _ in true }, validateRuntime: { _ in throw EmulationError.missingRequiredFiles })
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "game")) { XCTAssertEqual($0 as? EmulationError, .runtimeFailed) }
        library.failure = nil
        XCTAssertThrowsError(try coordinator.prepare(gameIdentifier: "game")) { XCTAssertEqual($0 as? EmulationError, .missingRequiredFiles) }
    }
}
