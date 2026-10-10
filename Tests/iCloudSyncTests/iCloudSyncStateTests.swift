import XCTest
import CoreData
@testable import DeltaSyncContracts

final class iCloudSyncStateTests: XCTestCase {
    func testManagedObjectSuccessAndFailureCallbacksReturnToContextQueue() async throws {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        let success = expectation(description: "Success delivered on context queue")
        let failure = expectation(description: "Failure delivered on context queue")
        Task.detached {
            iCloudSyncState.deliver(Result<Int, CocoaError>.success(7), on: context) { result in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(try? result.get(), 7)
                success.fulfill()
            }
            iCloudSyncState.deliver(Result<Int, CocoaError>.failure(CocoaError(.userCancelled)), on: context) { result in
                XCTAssertTrue(Thread.isMainThread)
                if case .failure(let error) = result {
                    XCTAssertEqual(error.code, .userCancelled)
                } else {
                    XCTFail("Expected original failure")
                }
                failure.fulfill()
            }
        }
        await fulfillment(of: [success, failure], timeout: 5)
    }

    func testPrivateContextCallbackCanMutateReturnedManagedObject() async throws {
        let entity = NSEntityDescription()
        entity.name = "SyncRecord"
        entity.managedObjectClassName = "NSManagedObject"
        let status = NSAttributeDescription()
        status.name = "status"
        status.attributeType = .integer16AttributeType
        entity.properties = [status]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let completed = expectation(description: "Harmony-style status mutation")
        Task.detached {
            let record = await context.perform {
                NSEntityDescription.insertNewObject(forEntityName: "SyncRecord", into: context)
            }
            iCloudSyncState.deliver(Result<NSManagedObject, CocoaError>.success(record), on: context) { result in
                do {
                    let returned = try result.get()
                    returned.setValue(Int16(1), forKey: "status")
                    try context.save()
                    XCTAssertEqual(returned.value(forKey: "status") as? Int16, 1)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                completed.fulfill()
            }
        }
        await fulfillment(of: [completed], timeout: 5)
    }

    func testLargePayloadSplitsAndReassemblesWithoutLosingBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data((0..<19).map(UInt8.init))
        let source = directory.appendingPathComponent("source.gba")
        try original.write(to: source)
        let chunks = try iCloudSyncState.split(source, into: directory, chunkSize: 8)
        XCTAssertEqual(try chunks.map { try Data(contentsOf: $0).count }, [8, 8, 3])
        let target = directory.appendingPathComponent("assembled")
        try iCloudSyncState.assemble(chunks, at: target)
        XCTAssertEqual(try Data(contentsOf: target), original)
        XCTAssertThrowsError(try iCloudSyncState.split(source, into: directory, chunkSize: 0))
        let failed = directory.appendingPathComponent("failed")
        XCTAssertThrowsError(try iCloudSyncState.assemble([directory.appendingPathComponent("missing")], at: failed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
    }
    func testIdentifiersDoNotCollideForAmbiguousComponentsOrKinds() throws {
        let first = try iCloudSyncState.identifier(kind: "file", components: ["ab", "c"])
        XCTAssertEqual(first, try iCloudSyncState.identifier(kind: "file", components: ["ab", "c"]))
        XCTAssertNotEqual(first, try iCloudSyncState.identifier(kind: "file", components: ["a", "bc"]))
        XCTAssertNotEqual(first, try iCloudSyncState.identifier(kind: "record", components: ["ab", "c"]))
        XCTAssertFalse(first.contains("/"))
    }
    func testHistoricalVersionIsSelectedExactlyAndMissingVersionNeverFallsBack() throws {
        let old = iCloudSyncState.Revision(identifier: "old", date: Date(timeIntervalSince1970: 1))
        let new = iCloudSyncState.Revision(identifier: "new", date: Date(timeIntervalSince1970: 2))
        let history = [new, old]
        XCTAssertEqual(try iCloudSyncState.revision(in: history, requested: nil), new)
        XCTAssertEqual(try iCloudSyncState.revision(in: history, requested: "old"), old)
        XCTAssertThrowsError(try iCloudSyncState.revision(in: history, requested: "missing"))
        XCTAssertThrowsError(try iCloudSyncState.revision(in: [], requested: nil))
        XCTAssertEqual(try JSONDecoder().decode([iCloudSyncState.Revision].self, from: JSONEncoder().encode(history)), history)
    }
    func testChangeTokenCannotBeReusedForAnotherAccount() throws {
        let envelope = iCloudSyncState.Token(account: "one", serverToken: Data([1, 2, 3]))
        let decoded = try JSONDecoder().decode(iCloudSyncState.Token.self, from: JSONEncoder().encode(envelope))
        XCTAssertEqual(try decoded.token(for: "one"), Data([1, 2, 3]))
        XCTAssertThrowsError(try decoded.token(for: "two"))
        XCTAssertThrowsError(try JSONDecoder().decode(iCloudSyncState.Token.self, from: Data([0xff])))
    }
}
