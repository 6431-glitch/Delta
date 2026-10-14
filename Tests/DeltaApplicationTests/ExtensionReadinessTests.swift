import XCTest
import DeltaDomain
@testable import DeltaApplication

@MainActor private struct AdditionalAdapter: LaunchRepository, SaveReadiness
{
    let system: SystemDescriptor
    func launchGame(identifier: String) -> LaunchGame? {
        LaunchGame(identifier: identifier, systemIdentifier: system.identifier, fileURL: URL(fileURLWithPath: "/fixture.extra"))
    }
    func savesAreReady(gameIdentifier: String) -> Bool { true }
}

final class ExtensionReadinessTests: XCTestCase
{
    @MainActor func testNewSystemAndReplacementDriverUseUnchangedSharedServices() async throws
    {
        let descriptor = SystemDescriptor(identifier: "test.additional", preferenceKey: "additional", name: "Additional", shortName: "Additional", displayName: "Additional", year: 2026, fileExtensions: ["extra"], runtime: .deltaCore, capabilities: [.saveStates])
        let registry = try SystemRegistry(BuiltInSystems.descriptors + [descriptor])
        let adapter = AdditionalAdapter(system: descriptor)
        let launch = LaunchCoordinator(registry: registry, repository: adapter, saves: adapter, isReadable: { _ in true }, validateRuntime: { _ in })
        let prepared = try launch.prepare(gameIdentifier: "stable-game-id")
        XCTAssertEqual(prepared.system, descriptor)
        XCTAssertTrue(prepared.system.allows(.saveStates))
        let inspector = ImportCoordinator(registry: registry, inspectors: [:], isReadable: { _ in true })
        XCTAssertNil(try inspector.inspect(prepared.game.fileURL).displayName)
        let snapshot = GameStorageSnapshot(gameURL: prepared.game.fileURL, saveURL: URL(fileURLWithPath: "/stable-game-id.sav"), artworkURL: URL(fileURLWithPath: "/cover.png"), backdropURL: nil)
        let artifacts = StorageArtifactPolicy.saveFiles(snapshot, hasRTC: false)
        var configuredDrivers = [String]()
        // Replacing a driver changes composition, not launch/import/storage algorithms or identity.
        for implementation in ["first-core", "replacement-core"] {
            let session = CallbackEmulationSession(start: { configuredDrivers.append(implementation) }, pause: { _ in }, stop: {})
            try session.start(); try session.pause(); try session.resume(); try session.stop()
            session.finish(failed: false)
            XCTAssertEqual(session.state, .stopped)
            XCTAssertEqual(try launch.prepare(gameIdentifier: "stable-game-id").game.identifier, "stable-game-id")
            XCTAssertEqual(StorageArtifactPolicy.saveFiles(snapshot, hasRTC: false), artifacts)
        }
        XCTAssertEqual(configuredDrivers, ["first-core", "replacement-core"])
    }
}
