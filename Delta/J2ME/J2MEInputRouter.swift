import UIKit
import GameController

/// Aggregate keys by input source so disconnects/cancelled touches cannot leave a key down.
final class J2MEInputRouter {
    var preferences = J2MEPreferences()
    var enabled = true
    private var state = J2MEInputState()
    private var repeats: [String: Timer] = [:]
    private var controllers: [GCController] = []
    private var observers: [NSObjectProtocol] = []
    var onPause: (() -> Void)?
    func send(type: Int32, logical: Int32, source: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        let code = Int32(preferences.key(Int(logical)))
        if type == Int32(J2ME_INPUT_KEY_PRESSED) {
            guard enabled else { return }
            if state.press(source: source, code: code) { j2me_input_post_key(type, code) }
        } else if type == Int32(J2ME_INPUT_KEY_RELEASED) {
            repeats.removeValue(forKey: source)?.invalidate()
            if let previous = state.release(source: source) { j2me_input_post_key(type, previous) }
        } else if enabled, let previous = state.held[source] {
            j2me_input_post_key(type, previous)
        }
    }
    func releaseAll() {
        for code in state.releaseAll() { j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), code) }
        repeats.values.forEach { $0.invalidate() }; repeats.removeAll()
    }
    func startControllers() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.connectControllers() })
        }
        connectControllers()
    }
    func stopControllers() {
        observers.forEach(NotificationCenter.default.removeObserver); observers.removeAll()
        releaseAll()
        for controller in controllers { controller.extendedGamepad?.valueChangedHandler = nil; controller.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
        controllers.removeAll()
    }
    private func connectControllers() {
        releaseAll()
        for controller in controllers { controller.extendedGamepad?.valueChangedHandler = nil; controller.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
        controllers = GCController.controllers()
        for controller in controllers {
            guard let pad = controller.extendedGamepad else { continue }
            controller.handlerQueue = .main
            let prefix = "controller-\(ObjectIdentifier(controller))-"
            pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.onPause?() } }
            pad.valueChangedHandler = { [weak self] pad, _ in
                guard let self else { return }
                let inputs: [(String, Bool, Int)] = [
                    ("up", pad.dpad.up.isPressed || pad.leftThumbstick.yAxis.value > 0.45, 50),
                    ("down", pad.dpad.down.isPressed || pad.leftThumbstick.yAxis.value < -0.45, 56),
                    ("left", pad.dpad.left.isPressed || pad.leftThumbstick.xAxis.value < -0.45, 52),
                    ("right", pad.dpad.right.isPressed || pad.leftThumbstick.xAxis.value > 0.45, 54),
                    ("A", pad.buttonA.isPressed, 53), ("B", pad.buttonB.isPressed, 48),
                    ("X", pad.buttonX.isPressed, 49), ("Y", pad.buttonY.isPressed, 51),
                    ("L1", pad.leftShoulder.isPressed, -6), ("R1", pad.rightShoulder.isPressed, -7),
                    ("L2", pad.leftTrigger.isPressed, 42), ("R2", pad.rightTrigger.isPressed, 35)]
                for (name, pressed, defaultKey) in inputs {
                    let source = prefix + name
                    let key = self.preferences.controllerKeys[name] ?? defaultKey
                    if pressed && self.state.held[source] == nil {
                        self.send(type: Int32(J2ME_INPUT_KEY_PRESSED), logical: Int32(key), source: source)
                        guard self.state.held[source] != nil else { continue }
                        var elapsed: Double = 0
                        self.repeats[source] = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                            elapsed += 0.08
                            if elapsed >= 0.4 { self?.send(type: Int32(J2ME_INPUT_KEY_REPEATED), logical: Int32(key), source: source) }
                        }
                    } else if !pressed { self.send(type: Int32(J2ME_INPUT_KEY_RELEASED), logical: Int32(key), source: source) }
                }
            }
        }
    }
}
