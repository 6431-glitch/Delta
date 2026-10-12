import Foundation

@main
struct ScreenDetectionTests {
    static func main() {
        var count = 0
        func check(_ result: J2MEScreenProfile, _ w: Int, _ h: Int, _ source: J2MEScreenProfile.Source, _ reason: String) {
            precondition(result == J2MEScreenProfile(w: w, h: h, source: source), "\(reason): \(result)")
            count += 1
        }
        func detect(_ filename: String, _ manifest: [String: String] = [:], _ jad: [String: String] = [:]) -> J2MEScreenProfile {
            J2MEScreenProfile.detect(filename: filename, manifest: manifest, descriptor: jad)
        }
        check(detect("game.jar"), 240, 320, .fallback, "No evidence")
        check(detect("Pool_176x220_EN.jar"), 176, 220, .filename, "Delimited filename")
        check(detect("Game [320X240].JAR"), 320, 240, .filename, "Landscape uppercase")
        check(detect("Game (128×160).jar"), 128, 160, .filename, "Unicode separator")
        check(detect("game_176x220_240x320.jar"), 240, 320, .fallback, "Conflicting filename sizes")
        check(detect("game_176x220_176x220.jar"), 176, 220, .filename, "Repeated matching size")
        check(detect("game_v130.jar"), 240, 320, .fallback, "Version is not resolution")
        check(detect("game_9999x9999.jar"), 240, 320, .fallback, "Reject oversized dimensions")
        check(detect("game_0x220.jar"), 240, 320, .fallback, "Reject zero")
        check(detect("abc176x220def.jar"), 240, 320, .fallback, "Avoid embedded token false positives")
        let native = ["Nokia-MIDlet-Original-Display-Size": "176, 208"]
        check(detect("game_240x320.jar", native), 176, 208, .manifest, "Metadata overrides filename")
        check(detect("game.jar", native, ["Nokia-MIDlet-Original-Display-Size": "240,400"]), 240, 400, .descriptor, "JAD override")
        check(detect("game.jar", ["Nokia-MIDlet-Target-Display-Size": "480,800"]), 240, 320, .fallback, "Target scaling is not native resolution")
        check(detect("game_128x160.jar", ["Nokia-MIDlet-Original-Display-Size": "-1,220"]), 128, 160, .filename, "Invalid metadata uses filename")
        check(detect("game.jar", ["MIDlet-Screen-Width": "320", "MIDlet-Screen-Height": "240"]), 320, 240, .manifest, "Explicit paired dimensions")
        check(detect("game.jar", ["MIDlet-Screen-Width": "176"]), 240, 320, .fallback, "Incomplete pair")
        let folded = J2MEScreenProfile.attributes("Nokia-MIDlet-Original-Display-Size: 176,\r\n 220\r\nMIDlet-Name: Demo\r\n")
        check(detect("game.jar", folded), 176, 220, .manifest, "CRLF folded metadata")
        check(detect("game.jar", ["NOKIA-MIDLET-ORIGINAL-DISPLAY-SIZE": "128,128"]), 128, 128, .manifest, "Case-insensitive hints")
        print("Passed \(count) screen detection regression checks")
    }
}
