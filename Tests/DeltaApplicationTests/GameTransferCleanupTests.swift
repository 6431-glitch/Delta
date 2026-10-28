import Foundation
import XCTest
@testable import DeltaApplication

final class GameTransferCleanupTests: XCTestCase {
    func testExportCompletionAndReleaseCleanOnlyOwnedWorkspace() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try GameTransferTemporaryFiles.createWorkspace(in: root)
        let second = try GameTransferTemporaryFiles.createWorkspace(in: root)
        var lifetime: GameTransferExportLifetime? = .init(directory: first, root: root)
        lifetime?.finish(); lifetime?.finish()
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        lifetime = .init(directory: second, root: root)
        lifetime = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        let recovery = root.appendingPathComponent("Recovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        GameTransferTemporaryFiles.discardWorkspace(recovery, in: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.path))
    }
    func testIncomingOwnershipPreservesUserFilesAndActiveExports() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let temporary = root.appendingPathComponent("tmp"), inbox = root.appendingPathComponent("Documents/Inbox")
        let workspaces = temporary.appendingPathComponent("DeltaTransfers")
        let originals = root.appendingPathComponent("Files")
        for directory in [temporary, inbox, workspaces, originals] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        for (directory, owned) in [(temporary, true), (inbox, true), (workspaces, false), (originals, false)] {
            let file = directory.appendingPathComponent("game.deltatransfer")
            try Data([1]).write(to: file)
            XCTAssertEqual(GameTransferTemporaryFiles.isIncomingCopy(file, temporaryRoot: temporary, inboxRoot: inbox, workspaceRoot: workspaces), owned)
        }
        let link = temporary.appendingPathComponent("link.deltatransfer")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: originals.appendingPathComponent("game.deltatransfer"))
        XCTAssertFalse(GameTransferTemporaryFiles.isIncomingCopy(link, temporaryRoot: temporary, inboxRoot: inbox, workspaceRoot: workspaces))
    }
    func testRestartSnapshotDoesNotSweepLaterWorkspaces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let abandoned = try GameTransferTemporaryFiles.createWorkspace(in: root)
        let snapshot = GameTransferTemporaryFiles.interruptedWorkspaces(in: root)
        let active = try GameTransferTemporaryFiles.createWorkspace(in: root)
        for directory in snapshot { GameTransferTemporaryFiles.discardWorkspace(directory, in: root) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
    }
}
