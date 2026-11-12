import Foundation
import CoreGraphics

/// Covers keep their source proportions; banners use their own fill treatment.
enum ArtworkCoverLayout {
    static func aspectRatio(of size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return 1 }
        let ratio = size.width / size.height
        return ratio.isFinite && ratio > 0 ? ratio : 1
    }
    static func fittedSize(aspectRatio: CGFloat, maximum: CGSize) -> CGSize {
        guard maximum.width > 0, maximum.height > 0 else { return .zero }
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        let width = min(maximum.width, maximum.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }
}
