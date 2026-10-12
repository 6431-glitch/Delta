// swift-tools-version: 5.9
import PackageDescription

// Transport-independent tests for the CloudKit sync contracts. The iOS app
// continues to build through Delta.xcworkspace.
let package = Package(
    name: "DeltaSyncContracts",
    platforms: [.macOS(.v13)],
    products: [],
    targets: [
        .target(name: "DeltaSyncContracts", path: "Delta/Syncing", exclude: ["iCloudService.swift", "SyncManager.swift", "SyncResultViewController.swift", "SyncValidationError.swift", "SyncResultsViewController.storyboard"], sources: ["iCloudSyncState.swift"]),
        .testTarget(name: "DeltaSyncContractsTests", dependencies: ["DeltaSyncContracts"], path: "Tests/iCloudSyncTests")
    ]
)
