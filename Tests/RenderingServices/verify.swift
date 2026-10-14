import Foundation
import AVFoundation

// Host doubles let the production factory/presentation adapter run without UIKit or a GPU.
public final class RingBuffer {}
public protocol AudioRendering: AnyObject { var audioBuffer: RingBuffer { get } }
public final class AudioManager {
    public let audioBuffer = RingBuffer()
    public var frameDuration = 1.0 / 60.0
    public var rate = 1.0
    public var isEnabled = true
    public var respectsSilentMode = true
    public var mixesWithOtherAudio = false
    public var pausesOtherAudio = false
    public func start() {}
    public func stop() {}
    public var audioFormat: AVAudioFormat
    public init(audioFormat: AVAudioFormat) { self.audioFormat = audioFormat }
}
public struct VideoFormat {}
public final class Scene { var hasKeyboardFocus = false }
public final class Window { var windowScene: Scene? }
public final class GameView: NSObject { var window: Window? }
public final class VideoManager {
    var views = Set<GameView>()
    public var gameViews: Set<GameView> { views }
    public init(videoFormat: VideoFormat, options: [EmulatorCore.Option: Any]) {}
    func add(_ view: GameView) { views.insert(view) }
    func remove(_ view: GameView) { views.remove(view) }
}
public final class EmulatorCore {
    public enum Option: Hashable { case test }
    public let videoManager: VideoManager
    init(videoManager: VideoManager) { self.videoManager = videoManager }
}

@main struct RenderingChecks {
    static func main() {
        let audio = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        var configured = false
        let custom = EmulatorRenderingServices(makeAudio: { AudioManager(audioFormat: $0) }, makeVideo: { format, options in
            configured = options[.test] as? Bool == true
            return VideoManager(videoFormat: format, options: options)
        }, acceptsInput: { _ in false })
        precondition(custom.makeAudio(audio).audioFormat === audio)
        let video = custom.makeVideo(VideoFormat(), [.test: true])
        precondition(configured && !custom.acceptsInput(video))
        precondition(EmulatorRenderingServices.apple.acceptsInput(video))
        let core = EmulatorCore(videoManager: video)
        let view = GameView()
        core.add(view); core.add(view)
        precondition(core.gameViews.count == 1)
        precondition(!EmulatorRenderingServices.apple.acceptsInput(video))
        let scene = Scene(); scene.hasKeyboardFocus = true
        let window = Window(); window.windowScene = scene; view.window = window
        precondition(EmulatorRenderingServices.apple.acceptsInput(video))
        scene.hasKeyboardFocus = false
        precondition(!EmulatorRenderingServices.apple.acceptsInput(video))
        core.remove(view)
        precondition(core.gameViews.isEmpty && video.gameViews.isEmpty)
        print("Rendering services: injected construction/options, shared attachment, duplicate attachment, focused/unfocused/empty input policy passed.")
    }
}
