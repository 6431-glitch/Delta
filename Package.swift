// swift-tools-version: 5.9
import PackageDescription

// Transport-independent tests for the CloudKit sync contracts. The iOS app
// continues to build through Delta.xcworkspace.
let package = Package(
    name: "DeltaSyncContracts",
    platforms: [.macOS(.v13)],
    products: [],
    targets: [
        .target(name: "DeltaApplication", dependencies: ["DeltaDomain"], path: "Modules/DeltaApplication"),
        .testTarget(name: "DeltaApplicationTests", dependencies: ["DeltaApplication", "DeltaDomain"], path: "Tests/DeltaApplicationTests"),
        .target(name: "DeltaDomain", path: "Modules/DeltaDomain"),
        .testTarget(name: "DeltaDomainTests", dependencies: ["DeltaDomain"], path: "Tests/DeltaDomainTests"),
        .target(name: "DeltaSyncContracts", path: "Delta/Syncing", exclude: ["iCloudService.swift", "SyncManager.swift", "SyncResultViewController.swift", "SyncValidationError.swift", "SyncResultsViewController.storyboard"], sources: ["iCloudSyncState.swift"]),
        .testTarget(name: "DeltaSyncContractsTests", dependencies: ["DeltaSyncContracts"], path: "Tests/iCloudSyncTests")
    ]
)
