import XCTest
@testable import DeltaDomain

final class StorageArtifactTests: XCTestCase
{
    private let snapshot = GameStorageSnapshot(gameURL: URL(fileURLWithPath: "/library/game.gbc"), saveURL: URL(fileURLWithPath: "/library/game.sav"), artworkURL: URL(fileURLWithPath: "/library/artwork.png"), backdropURL: URL(fileURLWithPath: "/library/backdrop.png"))

    func testROMAndArtworkIdentifiersRemainCompatible()
    {
        let files = StorageArtifactPolicy.gameFiles(snapshot)
        XCTAssertEqual(Set(files.map(\.identifier)), ["game", "artwork", "backdrop"])
        XCTAssertEqual(files.first { $0.identifier == "game" }?.fileURL, snapshot.gameURL)
    }
    func testFirmwareReplacesVirtualROMAndExcludesUnlistedNAND()
    {
        let firmware = [StorageArtifact(identifier: "bios7", fileURL: URL(fileURLWithPath: "/bios7.bin")), StorageArtifact(identifier: "bios9", fileURL: URL(fileURLWithPath: "/bios9.bin")), StorageArtifact(identifier: "firmware", fileURL: URL(fileURLWithPath: "/firmware.bin"))]
        let files = StorageArtifactPolicy.gameFiles(snapshot, content: firmware)
        XCTAssertEqual(Set(files.map(\.identifier)), ["bios7", "bios9", "firmware", "artwork", "backdrop"])
        XCTAssertFalse(files.contains { $0.fileURL == snapshot.gameURL })
    }
    func testRTCAndJavaArchiveUseExistingSavePaths()
    {
        let gbc = StorageArtifactPolicy.saveFiles(snapshot, hasRTC: true)
        XCTAssertEqual(gbc.first { $0.identifier == "gameTimeSave" }?.fileURL.path, "/library/game.rtc")
        let archive = StorageArtifactPolicy.saveFiles(snapshot, hasRTC: false)
        XCTAssertEqual(archive, [StorageArtifact(identifier: "gameSave", fileURL: snapshot.saveURL)])
    }
    func testRemoteBackdropIsNotTreatedAsAFileArtifact()
    {
        let remote = GameStorageSnapshot(gameURL: snapshot.gameURL, saveURL: snapshot.saveURL, artworkURL: snapshot.artworkURL, backdropURL: URL(string: "https://example.com/backdrop.png"))
        XCTAssertFalse(StorageArtifactPolicy.gameFiles(remote).contains { $0.identifier == "backdrop" })
    }
}
