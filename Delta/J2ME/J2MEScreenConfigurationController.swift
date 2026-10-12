import UIKit

final class J2MEScreenConfigurationController: UITableViewController {
    private var current: J2MEScreenProfile
    private let automatic: J2MEScreenProfile
    private let presets: [(label: String, w: Int, h: Int)]
    private let save: (((w: Int, h: Int)?) -> Void)
    private let gameName: String

    init(gameName: String, current: J2MEScreenProfile, automatic: J2MEScreenProfile,
         presets: [(label: String, w: Int, h: Int)],
         save: @escaping (((w: Int, h: Int)?) -> Void)) {
        self.gameName = gameName
        self.current = current
        self.automatic = automatic
        self.presets = presets
        self.save = save
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen Configuration"
        overrideUserInterfaceStyle = .dark
        view.tintColor = J2MEAuroraKey.purple
        tableView.backgroundColor = UIColor(red: 0.055, green: 0.035, blue: 0.105, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 3 : presets.count
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? gameName : "Phone screen presets"
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "Automatic uses \(automatic.source.rawValue.lowercased()). Saved for this game. Changes apply on its next launch. The game keeps its aspect ratio in portrait and landscape." : nil
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = J2MEAuroraKey.surface
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Automatic"
                cell.detailTextLabel?.text = "\(automatic.w) × \(automatic.h)"
                cell.accessoryType = current.source == .manual ? .none : .checkmark
            case 1:
                cell.textLabel?.text = "Custom size…"
                cell.detailTextLabel?.text = "\(current.w) × \(current.h)"
                cell.accessoryType = .disclosureIndicator
            default: cell.textLabel?.text = "Use 240 × 320"
            }
        } else {
            let preset = presets[indexPath.row]
            cell.textLabel?.text = preset.label
            cell.accessoryType = current.source == .manual && preset.w == current.w && preset.h == current.h ? .checkmark : .none
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0 {
            current = automatic
            save(nil)
            tableView.reloadData()
            return
        }
        if indexPath.section == 0 && indexPath.row == 1 { showCustomSize(); return }
        let size: (w: Int, h: Int)
        if indexPath.section == 0 { size = (240, 320) }
        else { let preset = presets[indexPath.row]; size = (preset.w, preset.h) }
        apply(size)
    }
    private func apply(_ size: (w: Int, h: Int)) {
        current = J2MEScreenProfile(w: size.w, h: size.h, source: .manual)
        save(size)
        tableView.reloadData()
    }
    private func showCustomSize() {
        let alert = UIAlertController(title: "Custom Screen Size",
            message: "Width and height in pixels (64–1024 each).", preferredStyle: .alert)
        for (label, value) in [("Width", current.w), ("Height", current.h)] {
            alert.addTextField { field in
                field.placeholder = label
                field.accessibilityLabel = label
                field.text = String(value)
                field.keyboardType = .numberPad
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            guard let fields = alert?.textFields,
                  let w = Int(fields[0].text ?? ""), let h = Int(fields[1].text ?? ""),
                  (64...1024).contains(w), (64...1024).contains(h) else {
                let error = UIAlertController(title: "Invalid Screen Size",
                    message: "Enter whole numbers between 64 and 1024 for both dimensions.", preferredStyle: .alert)
                error.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(error, animated: true)
                return
            }
            self.apply((w, h))
        })
        present(alert, animated: true)
    }
}
