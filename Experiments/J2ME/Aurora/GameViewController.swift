//
//  GameViewController.swift
//  J2MEEmulator
//
//  Aurora J2ME gameplay overlay: adaptive portrait and landscape controls.
//  Engine lifecycle and native form/list presentation remain vendor-compatible.
//

import UIKit

// MARK: - Layout mode (extensible for future layouts)

enum GameLayoutMode {
    case ngage // Kept for call-site compatibility; layout adapts to view dimensions.
}

// MARK: - GameViewController

class GameViewController: UIViewController {

    let jarPath: String
    let appName: String
    let appIcon: UIImage
    let canvasWidth: Int
    let canvasHeight: Int
    let render3dScale: Int
    let fpsLimit: Int
    let layoutMode: GameLayoutMode

    private let emulatorView = EmulatorView()
    private let glowContainer = UIView()
    private let glowContentView = UIView()
    private lazy var formView = FormView()
    private lazy var listView = J2MEListView()
    private let backButton = AuroraButton(type: .system)
    private let lskButton = AuroraButton(type: .system)
    private let rskButton = AuroraButton(type: .system)
    private let softKeyHaptic = UIImpactFeedbackGenerator(style: .light)
    private(set) var placeholderIconView: UIImageView?

    // Controls — created based on layoutMode
    private var joystickView: JoystickView?
    private let menuButton = AuroraButton(type: .system)
    private let auroraGradient = CAGradientLayer()
    private var didStart = false
    private var numpadView: NumpadView?

    init(jarPath: String, appName: String, appIcon: UIImage,
         canvasWidth: Int = 240, canvasHeight: Int = 320,
         render3dScale: Int = 3, fpsLimit: Int = 0,
         layoutMode: GameLayoutMode = .ngage) {
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
        setGlobalEmulatorView(nil)
        alertTimeoutWork?.cancel()
    }

    private var alertTimeoutWork: DispatchWorkItem?

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .allButUpsideDown
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

        // Register native callbacks
        setGlobalEmulatorView(emulatorView)
        j2me_render_set_flush_callback(flushCallback)
        j2me_ui_set_callback(gameUICallback)
        activeGameViewController = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        if !didStart { didStart = true; startGame() }
    }

    // MARK: - Adaptive Aurora layout

    private func setupNGageLayout() {
        let joystick = JoystickView()
        let numpad = NumpadView()
        joystickView = joystick
        numpadView = numpad
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
            AuroraKey.style(button)
            button.setTitle(title, for: .normal)
            button.tag = code
            button.accessibilityLabel = title == "L" ? "Left soft key" : "Right soft key"
            button.addTarget(self, action: #selector(softKeyDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(softKeyUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        for (button, symbol, label) in [(backButton, "xmark", "Exit game"), (menuButton, "ellipsis", "Game menu")] {
            AuroraKey.style(button)
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
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_PRESSED), Int32(sender.tag))
        AuroraKey.highlight(sender, true)
    }

    @objc private func softKeyUp(_ sender: UIButton) {
        j2me_input_post_key(Int32(J2ME_INPUT_KEY_RELEASED), Int32(sender.tag))
        AuroraKey.highlight(sender, false)
    }

    // ============================================================
    // MARK: - Game lifecycle
    // ============================================================

    private func startGame() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runMIDlet()
            DispatchQueue.main.async {
                self?.dismiss(animated: true)
            }
        }
    }

    private func runMIDlet() {
        guard let resRoot = Bundle.main.resourcePath else { return }
        let docs = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()

        // Per-game save directory: Documents/Games Data/{jarFilename}/
        let jarFileName = URL(fileURLWithPath: jarPath).deletingPathExtension().lastPathComponent
        let gameId = jarFileName.replacingOccurrences(of: "[^a-zA-Z0-9._-]",
                                                       with: "_", options: .regularExpression)
        let saveRoot = docs + "/Games Data/" + gameId
        try? FileManager.default.createDirectory(atPath: saveRoot, withIntermediateDirectories: true)

        let initResult = jvm_bridge_init(resRoot, saveRoot, jarPath,
                                         Int32(canvasWidth),
                                         Int32(canvasHeight),
                                         Int32(render3dScale),
                                         Int32(fpsLimit))
        guard initResult == 0 else {
            print("[Swift] ERROR: JVM init failed with code \(initResult)")
            return
        }

        let runResult = jvm_bridge_run_midlet(jarPath)
        print("[Swift] MIDlet run result: \(runResult)")
        jvm_bridge_destroy()
    }

    @objc private func backTapped() {
        backButton.isEnabled = false
        jvm_bridge_request_stop()
    }

    // ============================================================
    // MARK: - View switching
    // ============================================================

    func showCanvasView() {
        emulatorView.isHidden = false
        joystickView?.isHidden = false
        numpadView?.isHidden = false
        formView.isHidden = true
        listView.isHidden = true
        lskButton.isHidden = false
        rskButton.isHidden = false
        var actions: [UIMenuElement] = []
        for index in 0..<j2me_ui_get_command_count() {
            let label = String(cString: j2me_ui_get_command_label(index))
            let id = j2me_ui_get_command_id(index)
            actions.append(UIAction(title: label) { _ in j2me_input_post_key(Int32(J2ME_UI_COMMAND_ACTION), id) })
        }
        actions.append(UIAction(title: "Exit Game", image: UIImage(systemName: "xmark"), attributes: .destructive) { [weak self] _ in self?.backTapped() })
        menuButton.menu = UIMenu(children: actions)
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

private(set) weak var activeGameViewController: GameViewController?

let gameUICallback: @convention(c) (Int32, UnsafePointer<CChar>?) -> Void = { action, data in
    DispatchQueue.main.async {
        guard let vc = activeGameViewController else { return }
        switch action {
        case Int32(J2ME_UI_ACTION_SHOW_CANVAS):  vc.showCanvasView()
        case Int32(J2ME_UI_ACTION_SHOW_FORM):    vc.showFormView()
        case Int32(J2ME_UI_ACTION_SHOW_LIST):    vc.showListView()
        case Int32(J2ME_UI_ACTION_SHOW_ALERT):   vc.showAlert()
        default: break
        }
    }
}
