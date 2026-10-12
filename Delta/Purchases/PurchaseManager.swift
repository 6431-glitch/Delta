import Foundation

/// Feature access for this build. All app features are available without a purchase.
final class PurchaseManager {
    static let shared = PurchaseManager()
    private init() {}

    var supportsExternalPurchases: Bool { false }

    @MainActor
    var isActivePatron: Bool {
        DatabaseManager.shared.patreonAccount()?.hasBetaAccess ?? false
    }

    @MainActor
    var isExperimentalFeaturesAvailable: Bool { true }

    @MainActor
    var supportsExperimentalFeatures: Bool { true }

    @MainActor
    var isPatronIconsAvailable: Bool { true }
}
