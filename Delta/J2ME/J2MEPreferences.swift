import Foundation

/// Compatibility hints, not a claim to emulate every API on these handsets.
enum J2MEPhone: String, CaseIterable, Codable {
    case generic, nokia, sonyEricsson
    var title: String { switch self { case .generic: return "Generic MIDP"; case .nokia: return "Nokia"; case .sonyEricsson: return "Sony Ericsson" } }
    var platform: String { switch self { case .generic: return "Delta/MIDP-2.0"; case .nokia: return "Nokia6230i/03.88"; case .sonyEricsson: return "SonyEricssonK800i/R1" } }
    var size: (Int, Int) { self == .nokia ? (208, 208) : (240, 320) }
    var fire: Int { self == .nokia ? -5 : self == .sonyEricsson ? -5 : 53 }
}

struct J2MEControlPlacement: Codable {
    var x: Double
    var y: Double
    var scale: Double
}

struct J2MEPreferences: Codable {
    var phone: J2MEPhone = .generic
    var fps: Int = 0
    var scale3D: Int = 3
    var opacity: Double = 0.85
    var hideKeypad = false
    var keyOverrides: [String: Int] = [:]
    var controllerKeys: [String: Int] = [:]
    var placements: [String: J2MEControlPlacement] = [:]

    init() {}
    init(settings: [String: Any]) {
        self = (settings["j2me.preferences"] as? String).flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
        fps = [0, 15, 30, 60].contains(fps) ? fps : 0
        scale3D = min(3, max(1, scale3D))
        opacity = opacity.isFinite ? min(1, max(0.2, opacity)) : 0.85
        keyOverrides = keyOverrides.filter { (-32768...32767).contains($0.value) }
        controllerKeys = controllerKeys.filter { (-32768...32767).contains($0.value) }
        placements = placements.filter { $0.value.x.isFinite && $0.value.y.isFinite && $0.value.scale.isFinite }
    }
    var json: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "{}" }
    func key(_ logical: Int) -> Int {
        if let override = keyOverrides[String(logical)] { return override }
        guard phone != .generic else { return logical }
        return [50: -1, 56: -2, 52: -3, 54: -4, 53: phone.fire][logical] ?? logical
    }
    var properties: [String: String] {
        var result = ["microedition.platform": phone.platform]
        for (name, logical) in [("up", 50), ("down", 56), ("left", 52), ("right", 54), ("fire", 53)] {
            result["delta.key." + name] = String(key(logical))
        }
        return result
    }
    static let controllerDefaults = ["A": 53, "B": 48, "X": 49, "Y": 51, "L1": -6, "R1": -7, "L2": 42, "R2": 35]
}
