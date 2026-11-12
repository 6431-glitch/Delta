// Five separate phone navigation keys. The legacy type name preserves saved control placement.
import UIKit

final class J2MEJoystickView: UIView {
    var onKey: ((Int32, Int32) -> Void)?
    private var timers: [Int: Timer] = [:]
    private var pressed: Set<Int> = []
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    deinit { timers.values.forEach { $0.invalidate() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        for (label, symbol, code) in [("Up", "chevron.up", 50), ("Down", "chevron.down", 56),
                                      ("Left", "chevron.left", 52), ("Right", "chevron.right", 54),
                                      ("Select", "circle.fill", 53)] {
            let button = J2MEAuroraButton(type: .system)
            J2MEAuroraKey.style(button)
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
            button.accessibilityLabel = label
            button.tag = code
            button.addTarget(self, action: #selector(down(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(up(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    func cancelKeys() {
        for case let button as UIButton in subviews { up(button) }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(bounds.width, bounds.height)
        let gap: CGFloat = 4
        let side = (size - gap * 2) / 3
        let origin = CGPoint(x: (bounds.width - size) / 2, y: (bounds.height - size) / 2)
        for case let button as UIButton in subviews {
            let position: (CGFloat, CGFloat)
            switch button.tag {
            case 50: position = (1, 0)
            case 56: position = (1, 2)
            case 52: position = (0, 1)
            case 54: position = (2, 1)
            default: position = (1, 1)
            }
            button.frame = CGRect(x: origin.x + position.0 * (side + gap), y: origin.y + position.1 * (side + gap), width: side, height: side)
            button.layer.cornerRadius = min(16, side / 3)
        }
    }

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

}
