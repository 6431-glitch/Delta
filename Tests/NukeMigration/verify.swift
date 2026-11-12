import AppKit
import Nuke

@main struct Checks {
    static func png(width: Int) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: width, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for x in 0..<width { for y in 0..<width {
            let offset = y * bitmap.bytesPerRow + x * 4
            bitmap.bitmapData![offset] = 0xaa; bitmap.bitmapData![offset + 1] = 0x33
            bitmap.bitmapData![offset + 2] = 0xcc; bitmap.bitmapData![offset + 3] = 0xff
        } }
        return bitmap.representation(using: .png, properties: [:])!
    }
    static func load(_ url: URL) async throws -> NSImage {
        try await ArtworkImagePipeline.shared.image(for: ArtworkImagePipeline.request(for: url))
    }
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let url = root.appendingPathComponent("cover.png")
        try png(width: 8).write(to: url, options: .atomic)
        let original = ArtworkImagePipeline.request(for: url)
        let first = try await load(url)
        precondition(first.size.width == 8, "Local PNG loads")
        precondition(ArtworkImagePipeline.cachedImage(for: url)?.size.width == 8, "Export shares memory cache")
        try png(width: 16).write(to: url, options: .atomic)
        ArtworkImagePipeline.invalidate(url)
        let next = ArtworkImagePipeline.request(for: url)
        precondition(original.userInfo[.imageIdKey] as? String != next.userInfo[.imageIdKey] as? String, "Overwrite changes request identity")
        precondition(ArtworkImagePipeline.cachedImage(for: url) == nil, "Overwrite evicts old cache")
        let replaced = try await load(url)
        precondition(replaced.size.width == 16, "Same URL reloads replacement bytes")
        precondition(ArtworkImagePipeline.cachedImage(for: url)?.size.width == 16, "Export sees replacement")
        let invalid = root.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: invalid)
        do { _ = try await load(invalid); fatalError("Invalid image accepted") } catch {}
        do { _ = try await load(root.appendingPathComponent("missing.png")); fatalError("Missing image accepted") } catch {}
        try png(width: 32).write(to: root.appendingPathComponent("remote.png"), options: .atomic)
        let remote = URL(string: "http://127.0.0.1:\(CommandLine.arguments[2])/remote.png")!
        ArtworkImagePipeline.invalidate(remote)
        let downloaded = try await load(remote)
        precondition(downloaded.size.width == 32, "Remote image loads")
        ArtworkImagePipeline.shared.configuration.imageCache?.removeAll()
        precondition(ArtworkImagePipeline.cachedImage(for: remote)?.size.width == 32, "Export reads disk cache with memory empty")
        let fromDisk = try await load(remote)
        precondition(fromDisk.size.width == 32, "Disk cache loads")
        ArtworkImagePipeline.invalidate(remote)
        precondition(ArtworkImagePipeline.cachedImage(for: remote) == nil, "Remote invalidation removes cached export")
        let slow = URL(string: "http://127.0.0.1:\(CommandLine.arguments[2])/slow.png")!
        var cancelledCallback = false
        let task = ArtworkImagePipeline.shared.loadImage(with: slow) { _ in cancelledCallback = true }
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        try await Task.sleep(nanoseconds: 400_000_000)
        precondition(!cancelledCallback, "Cancellation suppresses stale callbacks")
        precondition(ArtworkImagePipeline.cachedImage(for: slow) == nil, "Cancelled load does not cache an image")
        do { _ = try await load(URL(string: "http://127.0.0.1:\(CommandLine.arguments[2])/404.png")!); fatalError("HTTP failure accepted") } catch {}
        ArtworkImagePipeline.shared.configuration.dataCache?.removeAll()
        print("Passed 15 Nuke loading, overwrite, invalid/missing image, memory/disk cache and export checks")
    }
}
