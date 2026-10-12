//
//  J2MENumpadView.swift
//  J2MEEmulator
//
//  Reusable numpad control: 0-9, *, # + soft keys + command buttons.
//

import UIKit

class J2MENumpadView: UIView {

    static let KEY_SOFT_LEFT: Int32  = -6
    static let KEY_SOFT_RIGHT: Int32 = -7

    var onKey: ((Int32, Int32) -> Void)?
    func cancelKeys() {
        for case let button as UIButton in subviews { up(button) }
    }
    private var timers: [Int: Timer] = [:]
    private var pressed: Set<Int> = []
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    deinit { timers.values.forEach { $0.invalidate() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let numpad: [(String, Int32)] = [
            ("1", 49), ("2", 50), ("3", 51),
            ("4", 52), ("5", 53), ("6", 54),
            ("7", 55), ("8", 56), ("9", 57),
            ("*", 42), ("0", 48), ("#", 35),
        ]
        for (title, code) in numpad {
            let btn = J2MEAuroraButton(type: .system)
            btn.setTitle(title, for: .normal)
            J2MEAuroraKey.style(btn)
            btn.accessibilityLabel = title == "*" ? "Star" : title == "#" ? "Hash" : title
            btn.tag = Int(code)
            btn.addTarget(self, action: #selector(down(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(up(_:)),
                          for: [.touchUpInside, .touchUpOutside, .touchCancel])
            addSubview(btn)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height

        let cols: CGFloat = 3
        let numRows: CGFloat = 4
        let gap: CGFloat = 8

        let btnW = (w - gap * (cols - 1)) / cols
        let btnH = (h - gap * (numRows - 1)) / numRows

        for sub in subviews {
            guard let btn = sub as? UIButton else { continue }
            let code = Int32(btn.tag)

            let (col, row): (Int, Int)
            switch code {
            case 49: (col, row) = (0, 0)
            case 50: (col, row) = (1, 0)
            case 51: (col, row) = (2, 0)
            case 52: (col, row) = (0, 1)
            case 53: (col, row) = (1, 1)
            case 54: (col, row) = (2, 1)
            case 55: (col, row) = (0, 2)
            case 56: (col, row) = (1, 2)
            case 57: (col, row) = (2, 2)
            case 42: (col, row) = (0, 3) // *
            case 48: (col, row) = (1, 3) // 0
            case 35: (col, row) = (2, 3) // #
            default: continue
            }
            btn.frame = CGRect(
                x: CGFloat(col) * (btnW + gap),
                y: CGFloat(row) * (btnH + gap),
                width: btnW, height: btnH)
        }


    }

    // MARK: - Key events with repeat

    @objc private func down(_ sender: UIButton) {
        let code = sender.tag
        guard pressed.insert(code).inserted else { return }
        haptic.impactOccurred(intensity: 0.5)
        onKey?(Int32(J2ME_INPUT_KEY_PRESSED), Int32(code))
        J2MEAuroraKey.highlight(sender, true)
        timers[code] = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self, self.pressed.contains(code) else { return }
            self.timers[code] = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard self?.pressed.contains(code) == true else { return }
                self?.onKey?(Int32(J2ME_INPUT_KEY_REPEATED), Int32(code))
            }
        }
    }

    @objc private func up(_ sender: UIButton) {
        guard pressed.remove(sender.tag) != nil else { return }
        onKey?(Int32(J2ME_INPUT_KEY_RELEASED), Int32(sender.tag))
        J2MEAuroraKey.highlight(sender, false)
        timers.removeValue(forKey: sender.tag)?.invalidate()
    }

    // Canvas commands are exposed by the game menu, never over numeric keys.
    func updateCommands() { }
}

/// Shared Aurora surface for UIKit controls; lightweight materials avoid a blur per key.
enum J2MEAuroraKey {
    static let surface = UIColor(red: 0.16, green: 0.16, blue: 0.23, alpha: 0.78)
    static let purple = UIColor(red: 0.67, green: 0.24, blue: 0.94, alpha: 1)
    static func style(_ button: UIButton) {
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.tintColor = .white
        button.backgroundColor = surface
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.layer.borderColor = UIColor(white: 1, alpha: 0.20).cgColor
        button.layer.borderWidth = 1
        button.isExclusiveTouch = false
    }
    static func highlight(_ button: UIButton, _ active: Bool) {
        button.backgroundColor = active ? purple : surface
        button.layer.borderColor = (active ? purple : UIColor(white: 1, alpha: 0.20)).cgColor
    }
}

final class J2MEAuroraButton: UIButton {
    private let sheen = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        sheen.colors = [UIColor(white: 1, alpha: 0.10).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        layer.insertSublayer(sheen, at: 0)
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.frame = bounds
        CATransaction.commit()
    }
}
