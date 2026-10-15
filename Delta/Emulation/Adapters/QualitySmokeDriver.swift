#if DEBUG
import Foundation
import DeltaCore
import AVFoundation

/// Opt-in integration checks on a disposable simulator, never an ordinary app launch.
@MainActor enum QualitySmokeDriver
{
    static var enabled: Bool { ProcessInfo.processInfo.environment["DELTA_QUALITY_SMOKE"] == "1" }
    static func directory() throws -> URL
    {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("QualitySmoke", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func record(runtime: String, passed: Bool, detail: String)
    {
        do {
            let data = try JSONSerialization.data(withJSONObject: ["runtime": runtime, "passed": passed, "detail": detail], options: [.sortedKeys])
            try data.write(to: directory().appendingPathComponent(runtime + ".json"), options: .atomic)
            print("[QUALITY] \(runtime) \(passed ? "PASS" : "FAIL"): \(detail)")
        } catch { print("[QUALITY] Could not write smoke result") }
    }
    static func console(_ controller: GameViewController, attempt: Int = 0)
    {
        guard enabled, ProcessInfo.processInfo.environment["DELTA_QUALITY_SMOKE_INTERACTIVE"] != "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak controller] in
            guard let controller, let core = controller.emulatorCore else { record(runtime: "console", passed: false, detail: "No core"); return }
            do {
                guard core.state == .running else {
                    if attempt < 10 { console(controller, attempt: attempt + 1) }
                    else { record(runtime: "console", passed: false, detail: "Runtime did not finish starting") }
                    return
                }
                let directory = try directory()
                guard let image = core.videoManager.snapshot()?.pngData() else { throw CocoaError(.fileReadCorruptFile) }
                try image.write(to: directory.appendingPathComponent("console-frame.png"))
                guard core.pause() else { throw CocoaError(.fileReadUnknown) }
                let file = directory.appendingPathComponent("console.state")
                let saved = core.saveSaveState(to: file)
                guard (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0 > 0 else { throw CocoaError(.fileReadCorruptFile) }
                guard core.resume(), core.pause() else { throw CocoaError(.fileReadUnknown) }
                try core.load(saved)
                guard core.resume() else { throw CocoaError(.fileReadUnknown) }
                core.stop()
                record(runtime: "console", passed: true, detail: "Import, native frame, pause/resume, save/load and stop")
            } catch {
                if core.state == .running || core.state == .paused { core.stop() }
                record(runtime: "console", passed: false, detail: error.localizedDescription)
            }
        }
    }
}
/// Silent integration backend avoids host audio activation; real audio is a separate device gate.
final class QualitySilentAudio: NSObject, EmulatorAudioManaging
{
    var audioFormat: AVAudioFormat
    var frameDuration = 1.0 / 60.0
    var rate = 1.0
    var isEnabled = true { didSet { audioBuffer.isEnabled = isEnabled; audioBuffer.reset() } }
    var respectsSilentMode = false
    var mixesWithOtherAudio = true
    var pausesOtherAudio = false
    let audioBuffer: RingBuffer
    init(audioFormat: AVAudioFormat)
    {
        self.audioFormat = audioFormat
        audioBuffer = RingBuffer(preferredBufferSize: 256 * 1024)!
        super.init()
    }
    func start() { audioBuffer.reset() }
    func stop() { audioBuffer.reset() }
}
#endif
