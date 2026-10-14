import Foundation

/// Value-only transfer to the native interpreter queue. No UIKit/model/controller reads occur here.
enum JavaRuntimeAdapter
{
    struct Request: Sendable {
        let resourceRoot: String?
        let saveDirectory: URL
        let jarPath: String
        let gameIdentifier: String
        let appName: String
        let canvasWidth: Int
        let canvasHeight: Int
        let render3dScale: Int
        let fpsLimit: Int
        let preferences: J2MEPreferences
    }
    struct Outcome: Sendable { let error: String? }
    static func run(_ request: Request) -> Outcome {
        var runtimeError: String?
        let started = Date()
        let sessionPreferences = request.preferences
        var diagnosticResult: Int32 = -1
        defer {
            J2MEDiagnostics.write(id: request.gameIdentifier, name: request.appName, screen: "\(request.canvasWidth) × \(request.canvasHeight)", preferences: sessionPreferences, result: diagnosticResult, error: runtimeError, duration: Date().timeIntervalSince(started))
        }
        guard let resRoot = request.resourceRoot else { runtimeError = "Runtime resources are missing."; return Outcome(error: runtimeError) }
        let saveRoot = request.saveDirectory.path
        do { try FileManager.default.createDirectory(at: request.saveDirectory, withIntermediateDirectories: true) }
        catch { runtimeError = "Could not create this game's save folder: \(error.localizedDescription)"; return Outcome(error: runtimeError) }

        // HD JARs retain logical Canvas/image sizes for collision and movement.
        // Only their backing pixels and the framebuffer use the denser scale.
        let artworkAttributes = J2MEJARMetadata.read(from: request.jarPath)?.attributes ?? [:]
        let requestedScale = Int(artworkAttributes["Delta-J2ME-Render-Scale"] ?? "1") ?? 1
        let requestedAssetScale = Int(artworkAttributes["Delta-J2ME-Asset-Scale"] ?? "1") ?? 1
        let outputScale = min(max(1, min(3, requestedScale)), max(1, 2048 / max(request.canvasWidth, request.canvasHeight)))
        delta_j2me_configure_2d(Int32(outputScale), Int32(max(1, min(3, requestedAssetScale))))
        let initResult = jvm_bridge_init(resRoot, saveRoot, request.jarPath,
                                         Int32(request.canvasWidth),
                                         Int32(request.canvasHeight),
                                         Int32(request.render3dScale),
                                         Int32(request.fpsLimit))
        defer { jvm_bridge_destroy() }
        diagnosticResult = initResult
        guard initResult == 0 else {
            runtimeError = "The Java runtime could not start (\(initResult))."
            return Outcome(error: runtimeError)
        }

        for (key, value) in sessionPreferences.properties { delta_j2me_set_property(key, value) }
        let runResult = jvm_bridge_run_midlet(request.jarPath)
        diagnosticResult = runResult
        let javaError = String(cString: delta_j2me_get_property("delta.j2me.error"))
        if !javaError.isEmpty { runtimeError = "Java compatibility error: " + javaError }
        if runResult != 0 && runtimeError == nil { runtimeError = "This MIDlet could not run (\(runResult)). It may require unsupported phone APIs." }
        print("[Swift] MIDlet run result: \(runResult)")
        return Outcome(error: runtimeError)
    }

}
