import XCTest
@testable import DeltaDomain

final class SystemRegistryTests: XCTestCase
{
    func testPersistedIdentitiesAndRecognition() throws
    {
        let registry = BuiltInSystems.registry
        XCTAssertEqual(registry.systems.count, 8)
        for system in registry.systems
        {
            for fileExtension in system.fileExtensions
            {
                XCTAssertEqual(registry.system(fileExtension: fileExtension.uppercased()), system)
            }
        }
        XCTAssertEqual(registry.system(fileExtension: "gb")?.identifier, "com.rileytestut.delta.game.gbc")
        XCTAssertEqual(registry.system(fileExtension: "JAR")?.identifier, "page.ducnguyen.delta.j2me")
        XCTAssertNil(registry.system(fileExtension: "zip"))
        XCTAssertNil(registry.system(identifier: "unknown"))
    }

    func testDuplicateAndAmbiguousRegistrationsFail() throws
    {
        let system = BuiltInSystems.descriptors[0]
        XCTAssertThrowsError(try SystemRegistry([system, system])) { error in
            XCTAssertEqual(error as? SystemRegistry.RegistrationError, .duplicateIdentifier(system.identifier))
        }
        let conflicting = SystemDescriptor(identifier: "test.other", preferenceKey: "other", name: "Other", shortName: "Other", displayName: "Other", year: 2026, fileExtensions: ["NES"], runtime: .deltaCore, capabilities: [])
        XCTAssertThrowsError(try SystemRegistry([system, conflicting])) { error in
            XCTAssertEqual(error as? SystemRegistry.RegistrationError, .ambiguousExtension("nes"))
        }
        let preferenceConflict = SystemDescriptor(identifier: "test.preference", preferenceKey: "nes", name: "Other", shortName: "Other", displayName: "Other", year: 2026, fileExtensions: [], runtime: .deltaCore, capabilities: [])
        XCTAssertThrowsError(try SystemRegistry([system, preferenceConflict]))
    }

    func testEngineCapabilitiesAndPolicyRemainDistinct()
    {
        let nes = BuiltInSystems.registry.system(fileExtension: "nes")!
        XCTAssertTrue(nes.allows(.saveStates))
        XCTAssertFalse(nes.allows(.saveStates, restrictedBy: [.saveStates]))
        XCTAssertTrue(nes.capabilities.contains(.saveStates))
        let java = BuiltInSystems.registry.system(fileExtension: "jar")!
        XCTAssertEqual(java.runtime, .javaME)
        XCTAssertFalse(java.allows(.saveStates))
        XCTAssertFalse(java.allows(.fastForward))
    }

    func testAdditionalSystemNeedsOnlyRegistration() throws
    {
        let fake = SystemDescriptor(identifier: "test.fake", preferenceKey: "fake", name: "Fake", shortName: "Fake", displayName: "Fake", year: 2026, fileExtensions: ["fake"], runtime: .deltaCore, capabilities: [.saveStates])
        let registry = try SystemRegistry(BuiltInSystems.descriptors + [fake])
        XCTAssertEqual(registry.system(fileExtension: "FAKE"), fake)
        XCTAssertEqual(registry.system(identifier: fake.identifier)?.capabilities, [.saveStates])
    }
}
