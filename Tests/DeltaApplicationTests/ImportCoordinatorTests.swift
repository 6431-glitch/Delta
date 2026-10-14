import XCTest
import DeltaDomain
@testable import DeltaApplication

private struct Inspector: GameContentInspector
{
    var failure = false
    func inspect(_ url: URL) throws -> ImportInspection
    {
        if failure { throw ImportCoordinator.Failure.invalidContent }
        return ImportInspection(displayName: "MIDlet", configurationData: Data("{}".utf8))
    }
}

final class ImportCoordinatorTests: XCTestCase
{
    func testMetadataHandlersAreSelectedByDescriptor()
    {
        let coordinator = ImportCoordinator(registry: BuiltInSystems.registry, inspectors: ["page.ducnguyen.delta.j2me": Inspector()], isReadable: { _ in true })
        XCTAssertEqual(try coordinator.inspect(URL(fileURLWithPath: "/fixture.JAR")).displayName, "MIDlet")
        XCTAssertNil(try coordinator.inspect(URL(fileURLWithPath: "/fixture.gba")).displayName)
    }
    func testUnsupportedUnreadableAndInvalidContentNeverProducesAnImport()
    {
        let coordinator = ImportCoordinator(registry: BuiltInSystems.registry, inspectors: ["page.ducnguyen.delta.j2me": Inspector(failure: true)], isReadable: { $0.path != "/missing.jar" })
        for (path, failure) in [("/fixture.exe", ImportCoordinator.Failure.unsupportedContent), ("/missing.jar", .unreadableContent), ("/fixture.jar", .invalidContent)]
        {
            XCTAssertThrowsError(try coordinator.inspect(URL(fileURLWithPath: path))) { XCTAssertEqual($0 as? ImportCoordinator.Failure, failure) }
        }
    }
}
