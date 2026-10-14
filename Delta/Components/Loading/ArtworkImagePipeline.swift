import UIKit
import Nuke

/// Views, collection prefetch operations and export must use the same cache.
enum ArtworkImagePipeline {
    static let shared = ImagePipeline(configuration: .withDataCache(name: "page.ducnguyen.Delta.artwork", sizeLimit: 150 * 1024 * 1024))

    private static let lock = NSLock()
    private static var revisions: [URL: UUID] = [:]

    static func request(for url: URL) -> ImageRequest {
        lock.lock()
        let revision = revisions[url]
        lock.unlock()
        var request = ImageRequest(url: url)
        if let revision { request.userInfo[.imageIdKey] = url.absoluteString + "#" + revision.uuidString }
        return request
    }

    static func invalidate(_ url: URL) {
        lock.lock()
        let previous = revisions.updateValue(UUID(), forKey: url)
        lock.unlock()
        var oldRequest = ImageRequest(url: url)
        if let previous { oldRequest.userInfo[.imageIdKey] = url.absoluteString + "#" + previous.uuidString }
        // A new identity also prevents coalescing with an in-flight old file read.
        shared.cache.removeCachedImage(for: oldRequest)
    }

    static func cachedImage(for url: URL) -> UIImage? {
        shared.cache.cachedImage(for: request(for: url))?.image
    }
}
