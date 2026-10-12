//
//  J2MEGameViewController.swift
//  J2MEEmulator
//
//  Aurora J2ME gameplay overlay: adaptive portrait and landscape controls.
//  Engine lifecycle and native form/list presentation remain vendor-compatible.
//

import UIKit

// MARK: - Layout mode (extensible for future layouts)

enum J2MEGameLayoutMode {
    case ngage // Kept for call-site compatibility; layout adapts to view dimensions.
}

// MARK: - J2MEGameViewController

class J2MEGameViewController: UIViewController {
    static var isSessionActive = false
    var saveDirectory: URL!
    var gameIdentifier = ""
    var preferences = J2MEPreferences()
    var onPreferencesChanged: ((J2MEPreferences) -> Void)?
    var onSessionClosed: ((@escaping (Result<Void, Error>) -> Void) -> Void)?
    private let input = J2MEInputRouter()
    private var userPaused = false
    private var inactive = false
    private var editingControls = false
    private var controlOverlays: [UIView] = []
    private let pauseLabel = UILabel()
    private var baselineFrames: [String: CGRect] = [:]
    private var editStart: [ObjectIdentifier: CGRect] = [:]

    private var runtimeError: String?
    private var runtimeFinished = false
    private var runtimeTerminated = false
    private var exiting = false
    private var didFinishSession = false

    let jarPath: String
    let appName: String
    let appIcon: UIImage
    let canvasWidth: Int
    let canvasHeight: Int
    let render3dScale: Int
    let fpsLimit: Int
    let layoutMode: J2MEGameLayoutMode

    private let emulatorView = J2MEEmulatorView()
    private let glowContainer = UIView()
    private let glowContentView = UIView()
    private lazy var formView = J2MEFormView()
    private lazy var listView = J2MEListView()
    private let backButton = J2MEAuroraButton(type: .system)
    private let lskButton = J2MEAuroraButton(type: .system)
    private let rskButton = J2MEAuroraButton(type: .system)
    private let softKeyHaptic = UIImpactFeedbackGenerator(style: .light)
    private(set) var placeholderIconView: UIImageView?

    // Controls — created based on layoutMode
    private var joystickView: J2MEJoystickView?
    private let menuButton = J2MEAuroraButton(type: .system)
    private let auroraGradient = CAGradientLayer()
    private var didStart = false
    private var numpadView: J2MENumpadView?

    init(jarPath: String, appName: String, appIcon: UIImage,
         canvasWidth: Int = 240, canvasHeight: Int = 320,
         render3dScale: Int = 3, fpsLimit: Int = 0,
         layoutMode: J2MEGameLayoutMode = .ngage) {
        self.jarPath = jarPath
        self.appName = appName
        self.appIcon = appIcon
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.render3dScale = render3dScale
        self.fpsLimit = fpsLimit
        self.layoutMode = layoutMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
        alertTimeoutWork?.cancel()
    }

    private var alertTimeoutWork: DispatchWorkItem?

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientation.current.mask
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.025, green: 0.025, blue: 0.07, alpha: 1)

        emulatorView.canvasWidth = canvasWidth
        emulatorView.canvasHeight = canvasHeight

        switch layoutMode {
        case .ngage: setupNGageLayout()
        }

        // Placeholder icon — visible until first game frame
        let iconIV = UIImageView(image: appIcon)
        iconIV.contentMode = .center
        iconIV.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconIV)
        NSLayoutConstraint.activate([
            iconIV.centerXAnchor.constraint(equalTo: emulatorView.centerXAnchor),
            iconIV.centerYAnchor.constraint(equalTo: emulatorView.centerYAnchor),
        ])
        placeholderIconView = iconIV
        view.bringSubviewToFront(backButton)

        // Fade out placeholder on first rendered frame
        emulatorView.onFirstFrame = { [weak self] in
            guard let icon = self?.placeholderIconView else { return }
            UIView.animate(withDuration: 0.2) {
                icon.alpha = 0
            } completion: { _ in
                icon.removeFromSuperview()
                self?.placeholderIconView = nil
            }
        }

        // Mirror game frames to glow layer
        emulatorView.onFrame = { [weak self] cgImage in
            self?.glowContentView.layer.contents = cgImage
        }

        NotificationCenter.default.addObserver(self, selector: #selector(suspendForInactivity), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(activateSession), name: UIApplication.didBecomeActiveNotification, object: nil)
        input.preferences = preferences
        input.onPause = { [weak self] in self?.togglePause() }
        input.startControllers()
        pauseLabel.text = "Paused"
        pauseLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        pauseLabel.textColor = .white
        pauseLabel.textAlignment = .center
        pauseLabel.backgroundColor = J2MEAuroraKey.surface
        pauseLabel.layer.cornerRadius = 14; pauseLabel.clipsToBounds = true
        pauseLabel.isHidden = true
        view.addSubview(pauseLabel)
        inactive = UIApplication.shared.applicationState != .active
        updatePause()
        refreshMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(finishIfReady), name: UIApplication.didBecomeActiveNotification, object: nil)

        // Register native callbacks
        setGlobalJ2MEEmulatorView(emulatorView)
        j2me_render_set_flush_callback(j2meFlushCallback)
        j2me_ui_set_callback(j2meGameUICallback)
        activeJ2MEGameViewController = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        if !didStart { didStart = true; startGame() }
    }

    // MARK: - Adaptive Aurora layout

    private func setupNGageLayout() {
        let joystick = J2MEJoystickView()
        let numpad = J2MENumpadView()
        joystickView = joystick
        numpadView = numpad
        joystick.onKey = { [weak self] type, code in self?.input.send(type: type, logical: code, source: "joystick") }
        numpad.onKey = { [weak self] type, code in self?.input.send(type: type, logical: code, source: "touch-\(code)") }
        auroraGradient.colors = [UIColor(red: 0.12, green: 0.045, blue: 0.24, alpha: 1).cgColor,
                                 UIColor(red: 0.025, green: 0.025, blue: 0.07, alpha: 1).cgColor]
        auroraGradient.startPoint = CGPoint(x: 0, y: 0)
        auroraGradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(auroraGradient, at: 0)
        // Subtle game-colored ambience, updated with the existing framebuffer callback.
        glowContentView.alpha = 0.18
        glowContentView.layer.magnificationFilter = .linear
        glowContainer.isUserInteractionEnabled = false
        glowContainer.clipsToBounds = true
        glowContainer.addSubview(glowContentView)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        glowContainer.addSubview(blur)
        for v in [glowContainer, emulatorView, joystick, numpad, lskButton, rskButton, formView, listView, backButton, menuButton] {
            view.addSubview(v)
        }
        formView.isHidden = true
        listView.isHidden = true
        for (button, title, code) in [(lskButton, "L", -6), (rskButton, "R", -7)] {
            J2MEAuroraKey.style(button)
            button.setTitle(title, for: .normal)
            button.tag = code
            button.accessibilityLabel = title == "L" ? "Left soft key" : "Right soft key"
            button.addTarget(self, action: #selector(softKeyDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(softKeyUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        for (button, symbol, label) in [(backButton, "xmark", "Exit game"), (menuButton, "ellipsis", "Game menu")] {
            J2MEAuroraKey.style(button)
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)), for: .normal)
            button.accessibilityLabel = label
            button.layer.cornerRadius = 22
        }
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = UIMenu(children: [UIAction(title: "Exit Game", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in self?.backTapped() }])
        emulatorView.layer.cornerRadius = 14
        emulatorView.clipsToBounds = true
        emulatorView.layer.borderWidth = 1
        emulatorView.layer.borderColor = UIColor(white: 1, alpha: 0.22).cgColor
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        auroraGradient.frame = view.bounds
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let ratio = CGFloat(canvasWidth) / CGFloat(max(canvasHeight, 1))
        let landscape = view.bounds.width > view.bounds.height
        backButton.frame = CGRect(x: safe.minX + 12, y: safe.minY + 8, width: 44, height: 44)
        menuButton.frame = CGRect(x: safe.maxX - 56, y: safe.minY + 8, width: 44, height: 44)
        if landscape {
            let height = min(safe.height - 16, (safe.width - 320) / ratio)
            let width = height * ratio
            emulatorView.frame = CGRect(x: safe.midX - width / 2, y: safe.midY - height / 2, width: width, height: height)
            let left = CGRect(x: safe.minX + 12, y: safe.minY + 64, width: emulatorView.frame.minX - safe.minX - 28, height: safe.height - 72)
            let right = CGRect(x: emulatorView.frame.maxX + 16, y: safe.minY + 64, width: safe.maxX - emulatorView.frame.maxX - 28, height: safe.height - 72)
            let pad = min(left.width, left.height - 56, 200)
            joystickView?.frame = CGRect(x: left.midX - pad / 2, y: left.midY - (pad + 52) / 2, width: pad, height: pad)
            let softWidth = (pad - 16) / 2
            lskButton.frame = CGRect(x: left.midX - pad / 2, y: (joystickView?.frame.maxY ?? left.minY) + 8, width: softWidth, height: 44)
            rskButton.frame = CGRect(x: left.midX + 8, y: lskButton.frame.minY, width: softWidth, height: 44)
            let keypadWidth = min(right.width, 224)
            let keypadHeight = min(right.height, 260)
            numpadView?.frame = CGRect(x: right.midX - keypadWidth / 2, y: right.midY - keypadHeight / 2, width: keypadWidth, height: keypadHeight)
        } else {
            let keypadHeight: CGFloat = 200
            let pad: CGFloat = safe.height < 700 ? 132 : 144
            let top = safe.minY + 60
            let available = safe.maxY - top - keypadHeight - pad - 32
            let height = min(available, (safe.width - 32) / ratio)
            emulatorView.frame = CGRect(x: safe.midX - height * ratio / 2, y: top, width: height * ratio, height: height)
            let controlsY = emulatorView.frame.maxY + 12
            joystickView?.frame = CGRect(x: safe.midX - pad / 2, y: controlsY, width: pad, height: pad)
            let softWidth = min(80, (safe.width - pad - 48) / 2)
            lskButton.frame = CGRect(x: safe.minX + 16, y: controlsY + 8, width: softWidth, height: 44)
            rskButton.frame = CGRect(x: safe.maxX - 16 - softWidth, y: controlsY + 8, width: softWidth, height: 44)
            numpadView?.frame = CGRect(x: safe.minX + 16, y: controlsY + pad + 12, width: safe.width - 32, height: keypadHeight)
        }
        baselineFrames = Dictionary(uniqueKeysWithValues: controls.map { ($0.0, $0.1.frame) })
        for (name, control) in controls {
            if let placement = preferences.placements[orientationKey + name] {
                let base = control.frame
                let scale = CGFloat(min(1.5, max(0.6, placement.scale)))
                let width = min(safe.width, max(44, base.width * scale))
                let height = min(safe.height, max(44, base.height * scale))
                control.frame = CGRect(x: safe.minX + CGFloat(placement.x) * safe.width - width / 2,
                                       y: safe.minY + CGFloat(placement.y) * safe.height - height / 2,
                                       width: width, height: height)
                control.frame.origin.x = min(safe.maxX - width, max(safe.minX, control.frame.minX))
                control.frame.origin.y = min(safe.maxY - height, max(safe.minY, control.frame.minY))
            }
            control.alpha = editingControls ? 1 : CGFloat(preferences.opacity)
            control.isUserInteractionEnabled = !editingControls
        }
        numpadView?.isHidden = !formView.isHidden || !listView.isHidden || (preferences.hideKeypad && !editingControls)
        pauseLabel.frame = CGRect(x: emulatorView.frame.midX - 100, y: emulatorView.frame.midY - 24, width: 200, height: 48)
        if editingControls { rebuildEditor() }
        glowContainer.frame = view.bounds
        glowContentView.frame = glowContainer.bounds
        glowContainer.subviews.last?.frame = glowContainer.bounds
        formView.frame = view.bounds
        listView.frame = view.bounds
        placeholderIconView?.center = emulatorView.center
    }

    // MARK: - Soft keys

    @objc private func softKeyDown(_ sender: UIButton) {
        softKeyHaptic.impactOccurred(intensity: 0.6)
        input.send(type: Int32(J2ME_INPUT_KEY_PRESSED), logical: Int32(sender.tag), source: "soft-\(sender.tag)")
        J2MEAuroraKey.highlight(sender, true)
    }

    @objc private func softKeyUp(_ sender: UIButton) {
        input.send(type: Int32(J2ME_INPUT_KEY_RELEASED), logical: Int32(sender.tag), source: "soft-\(sender.tag)")
        J2MEAuroraKey.highlight(sender, false)
    }

    // ============================================================
    // MARK: - Game lifecycle
    // ============================================================

    private func startGame() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runMIDlet()
            DispatchQueue.main.async {
                guard let self else { return }
                self.runtimeTerminated = true
                self.input.enabled = false
                self.input.stopControllers()
                self.joystickView?.cancelKeys(); self.numpadView?.cancelKeys()
                let complete: (Result<Void, Error>) -> Void = { [weak self] result in
                    guard let self else { return }
                    if case .failure(let error) = result { self.runtimeError = [self.runtimeError, "Could not sync Java saves: \(error.localizedDescription)"].compactMap { $0 }.joined(separator: "\n") }
                    self.runtimeFinished = true
                    self.finishIfReady()
                }
                if let closed = self.onSessionClosed { closed(complete) } else { complete(.success(())) }
                setGlobalJ2MEEmulatorView(nil)
                activeJ2MEGameViewController = nil
                self.finishIfReady()
            }
        }
    }

    // Dismissing while backgrounded makes the Library request orientation updates
    // on an inactive scene. Wait until foreground before returning to its UI.
    @objc private func finishIfReady() {
        guard runtimeFinished, !didFinishSession, UIApplication.shared.applicationState == .active else { return }
        didFinishSession = true
        let presenter = presentingViewController
        dismiss(animated: true) {
            J2MEGameViewController.isSessionActive = false
            if let error = self.runtimeError, let presenter { J2MELibrary.showError(error, from: presenter) }
        }
    }

    private func runMIDlet() {
        let started = Date()
        let sessionPreferences = preferences
        var diagnosticResult: Int32 = -1
        defer {
            J2MEDiagnostics.write(id: gameIdentifier, name: appName, screen: "\(canvasWidth) × \(canvasHeight)", preferences: sessionPreferences, result: diagnosticResult, error: runtimeError, duration: Date().timeIntervalSince(started))
        }
        guard let resRoot = Bundle.main.resourcePath else { runtimeError = "Runtime resources are missing."; return }
        let saveRoot = saveDirectory.path
        do { try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true) }
        catch { runtimeError = "Could not create this game's save folder: \(error.localizedDescription)"; return }

        let initResult = jvm_bridge_init(resRoot, saveRoot, jarPath,
                                         Int32(canvasWidth),
                                         Int32(canvasHeight),
                                         Int32(render3dScale),
                                         Int32(fpsLimit))
        diagnosticResult = initResult
        guard initResult == 0 else {
            runtimeError = "The Java runtime could not start (\(initResult))."
            jvm_bridge_destroy()
            return
        }

        for (key, value) in sessionPreferences.properties { delta_j2me_set_property(key, value) }
        let runResult = jvm_bridge_run_midlet(jarPath)
        diagnosticResult = runResult
        let javaError = String(cString: delta_j2me_get_property("delta.j2me.error"))
        if !javaError.isEmpty { runtimeError = "Java compatibility error: " + javaError }
        if runResult != 0 && runtimeError == nil { runtimeError = "This MIDlet could not run (\(runResult)). It may require unsupported phone APIs." }
        print("[Swift] MIDlet run result: \(runResult)")
        jvm_bridge_destroy()
    }

    @objc private func backTapped() {
        exiting = true
        backButton.isEnabled = false
        onPreferencesChanged?(preferences)
        input.enabled = false; input.releaseAll()
        joystickView?.cancelKeys(); numpadView?.cancelKeys()
        jvm_bridge_request_stop()
        // Wake paused Java threads so the event loop can observe the stop request.
        delta_j2me_set_paused(0)
    }

    // MARK: - Pause and touch layout editor

    @objc private func suspendForInactivity() { inactive = true; updatePause() }
    @objc private func activateSession() { inactive = false; updatePause(); finishIfReady() }
    private func togglePause() { guard !runtimeTerminated, !exiting else { return }; userPaused.toggle(); updatePause(); refreshMenu() }
    private func updatePause() {
        guard !runtimeTerminated, !exiting else { return }
        let paused = inactive || userPaused || editingControls
        if paused {
            joystickView?.cancelKeys(); numpadView?.cancelKeys(); input.releaseAll()
        }
        input.enabled = !paused
        emulatorView.isUserInteractionEnabled = !paused
        formView.isUserInteractionEnabled = !paused
        listView.isUserInteractionEnabled = !paused
        delta_j2me_set_paused(paused ? 1 : 0)
        delta_j2me_audio_pause(paused ? 1 : 0)
        pauseLabel.isHidden = !paused || editingControls
    }
    private var orientationKey: String { view.bounds.width > view.bounds.height ? "landscape." : "portrait." }
    private var controls: [(String, UIView)] {
        [("joystick", joystickView), ("keypad", numpadView), ("left", lskButton), ("right", rskButton)].compactMap { name, view in view.map { (name, $0) } }
    }
    private func refreshMenu() {
        var actions: [UIMenuElement] = []
        if !editingControls {
            for index in 0..<j2me_ui_get_command_count() {
                let label = String(cString: j2me_ui_get_command_label(index))
                let id = j2me_ui_get_command_id(index)
                actions.append(UIAction(title: label) { [weak self] _ in
                    guard self?.input.enabled == true else { return }
                    j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), id)
                })
            }
        }
        actions.append(UIAction(title: userPaused ? "Resume Game" : "Pause Game", image: UIImage(systemName: userPaused ? "play" : "pause")) { [weak self] _ in self?.togglePause() })
        actions.append(UIAction(title: editingControls ? "Done Editing Layout" : "Edit Touch Layout", image: UIImage(systemName: "hand.draw")) { [weak self] _ in
            guard let self else { return }
            self.editingControls.toggle()
            self.onPreferencesChanged?(self.preferences)
            self.updatePause(); self.view.setNeedsLayout(); self.refreshMenu()
            if !self.editingControls { self.controlOverlays.forEach { $0.removeFromSuperview() }; self.controlOverlays.removeAll() }
        })
        if editingControls {
            actions.append(UIAction(title: "Reset This Layout", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                guard let self else { return }
                self.preferences.placements = self.preferences.placements.filter { !$0.key.hasPrefix(self.orientationKey) }
                self.view.setNeedsLayout()
            })
        }
        actions.append(UIAction(title: "Exit Game", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in self?.backTapped() })
        menuButton.menu = UIMenu(children: actions)
        backButton.accessibilityLabel = "Exit game"
    }
    private func rebuildEditor() {
        // Keep recognizer views stable across layout passes, including touch-down
        // before a pan reaches .began. Recreating them cancels the gesture.
        for (index, pair) in controls.enumerated() {
            if index < controlOverlays.count {
                let overlay = controlOverlays[index]
                let active = overlay.gestureRecognizers?.contains { $0.state == .began || $0.state == .changed } == true
                if !active { overlay.frame = pair.1.frame }
                continue
            }
            let overlay = UILabel(frame: pair.1.frame)
            overlay.text = pair.0.capitalized + "\nDrag / Pinch / Tap"
            overlay.numberOfLines = 2; overlay.textAlignment = .center
            overlay.font = .systemFont(ofSize: 12, weight: .bold); overlay.textColor = .white
            overlay.backgroundColor = J2MEAuroraKey.purple.withAlphaComponent(0.35)
            overlay.layer.borderColor = J2MEAuroraKey.purple.cgColor; overlay.layer.borderWidth = 2; overlay.layer.cornerRadius = 14
            overlay.tag = index; overlay.isUserInteractionEnabled = true
            overlay.accessibilityTraits = .button
            overlay.accessibilityHint = "Tap to enter position and size, or drag and pinch."
            overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(editNumbers(_:))))
            overlay.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(editPan(_:))))
            overlay.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(editPinch(_:))))
            view.addSubview(overlay); controlOverlays.append(overlay)
        }
        view.bringSubviewToFront(menuButton); view.bringSubviewToFront(backButton)
    }
    @objc private func editNumbers(_ gesture: UITapGestureRecognizer) {
        guard let overlay = gesture.view else { return }
        let (name, control) = controls[overlay.tag]
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let current = preferences.placements[orientationKey + name] ?? .init(
            x: Double((control.frame.midX - safe.minX) / safe.width),
            y: Double((control.frame.midY - safe.minY) / safe.height), scale: 1)
        let alert = UIAlertController(title: name.capitalized, message: "Position as a percentage of the safe area. Size: 60–150%.", preferredStyle: .alert)
        for (label, value) in [("Horizontal %", current.x * 100), ("Vertical %", current.y * 100), ("Size %", current.scale * 100)] {
            alert.addTextField { $0.placeholder = label; $0.accessibilityLabel = label; $0.text = String(Int(value.rounded())); $0.keyboardType = .numberPad }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields, let x = Double(fields[0].text ?? ""), let y = Double(fields[1].text ?? ""), let scale = Double(fields[2].text ?? ""), (0...100).contains(x), (0...100).contains(y), (60...150).contains(scale) else { return }
            self.preferences.placements[self.orientationKey + name] = .init(x: x / 100, y: y / 100, scale: scale / 100)
            self.onPreferencesChanged?(self.preferences)
            self.view.setNeedsLayout()
        })
        present(alert, animated: true)
    }
    @objc private func editPan(_ gesture: UIPanGestureRecognizer) {
        guard let overlay = gesture.view else { return }
        let id = ObjectIdentifier(overlay)
        if gesture.state == .began { editStart[id] = overlay.frame }
        let start = editStart[id] ?? overlay.frame
        let translation = gesture.translation(in: view)
        overlay.frame = start.offsetBy(dx: translation.x, dy: translation.y)
        savePlacement(overlay)
        if gesture.state == .ended || gesture.state == .cancelled { editStart[id] = nil; view.setNeedsLayout() }
    }
    @objc private func editPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let overlay = gesture.view else { return }
        let id = ObjectIdentifier(overlay)
        if gesture.state == .began { editStart[id] = overlay.frame }
        let start = editStart[id] ?? overlay.frame
        let center = CGPoint(x: start.midX, y: start.midY)
        overlay.bounds.size = CGSize(width: max(44, start.width * gesture.scale), height: max(44, start.height * gesture.scale))
        overlay.center = center
        savePlacement(overlay)
        if gesture.state == .ended || gesture.state == .cancelled { editStart[id] = nil; view.setNeedsLayout() }
    }
    private func savePlacement(_ overlay: UIView) {
        let (name, control) = controls[overlay.tag]
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let base = baselineFrames[name] ?? control.frame
        let scale = min(1.5, max(0.6, overlay.frame.width / max(1, base.width)))
        let width = min(safe.width, max(44, base.width * scale)), height = min(safe.height, max(44, base.height * scale))
        let x = min(safe.maxX - width / 2, max(safe.minX + width / 2, overlay.center.x))
        let y = min(safe.maxY - height / 2, max(safe.minY + height / 2, overlay.center.y))
        overlay.frame = CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
        control.frame = overlay.frame
        preferences.placements[orientationKey + name] = .init(x: Double((x - safe.minX) / safe.width), y: Double((y - safe.minY) / safe.height), scale: Double(scale))
    }

    // ============================================================
    // MARK: - View switching
    // ============================================================

    func showCanvasView() {
        emulatorView.isHidden = false
        joystickView?.isHidden = false
        numpadView?.isHidden = preferences.hideKeypad && !editingControls
        formView.isHidden = true
        listView.isHidden = true
        lskButton.isHidden = false
        rskButton.isHidden = false
        refreshMenu()
    }

    func showFormView() {
        lskButton.isHidden = true
        rskButton.isHidden = true
        formView.buildFromNativeData()
        formView.isHidden = false
        emulatorView.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        listView.isHidden = true
    }

    func showListView() {
        lskButton.isHidden = true
        rskButton.isHidden = true
        listView.buildFromNativeData()
        listView.isHidden = false
        emulatorView.isHidden = true
        joystickView?.isHidden = true
        numpadView?.isHidden = true
        formView.isHidden = true
    }

    func showAlert() {
        let title = String(cString: j2me_ui_get_form_title())
        let text = String(cString: j2me_ui_get_alert_text())

        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)

        alertTimeoutWork?.cancel()
        alertTimeoutWork = nil

        let cmdCount = j2me_ui_get_command_count()
        if cmdCount == 0 {
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.alertTimeoutWork?.cancel()
                j2me_input_post_key(Int32(J2ME_UI_ALERT_DISMISSED), 0)
            })
        } else {
            for i in 0..<cmdCount {
                let label = String(cString: j2me_ui_get_command_label(Int32(i)))
                let cmdId = j2me_ui_get_command_id(Int32(i))
                alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                    self?.alertTimeoutWork?.cancel()
                    j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), cmdId)
                })
            }
        }

        present(alert, animated: true)

        let timeout = j2me_ui_get_alert_timeout()
        if timeout > 0 {
            let work = DispatchWorkItem { [weak alert] in
                alert?.dismiss(animated: true) {
                    j2me_input_post_key(Int32(J2ME_UI_ALERT_DISMISSED), 0)
                }
            }
            alertTimeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeout) / 1000.0, execute: work)
        }
    }
}

// MARK: - Game UI callback (global)

private(set) weak var activeJ2MEGameViewController: J2MEGameViewController?

let j2meGameUICallback: @convention(c) (Int32, UnsafePointer<CChar>?) -> Void = { action, data in
    DispatchQueue.main.async {
        guard let vc = activeJ2MEGameViewController else { return }
        switch action {
        case Int32(J2ME_UI_ACTION_SHOW_CANVAS):  vc.showCanvasView()
        case Int32(J2ME_UI_ACTION_SHOW_FORM):    vc.showFormView()
        case Int32(J2ME_UI_ACTION_SHOW_LIST):    vc.showListView()
        case Int32(J2ME_UI_ACTION_SHOW_ALERT):   vc.showAlert()
        default: break
        }
    }
}
