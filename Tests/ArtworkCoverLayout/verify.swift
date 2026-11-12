import Foundation
import CoreGraphics

@main struct CoverLayoutChecks {
    static func main() {
        let box = CGSize(width: 126, height: 171)
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: 1, maximum: box) == CGSize(width: 126, height: 126))
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: 3.0 / 4, maximum: box) == CGSize(width: 126, height: 168))
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: 2.0 / 3, maximum: box) == CGSize(width: 114, height: 171))
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: 4.0 / 3, maximum: box) == CGSize(width: 126, height: 94.5))
        precondition(ArtworkCoverLayout.aspectRatio(of: CGSize(width: 300, height: 400)) == 0.75)
        precondition(ArtworkCoverLayout.aspectRatio(of: .zero) == 1)
        precondition(ArtworkCoverLayout.aspectRatio(of: CGSize(width: CGFloat.infinity, height: 1)) == 1)
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: .nan, maximum: box) == CGSize(width: 126, height: 126))
        precondition(ArtworkCoverLayout.fittedSize(aspectRatio: 1, maximum: .zero) == .zero)
        print("Passed 9 mixed-cover aspect/fit checks")
    }
}
