import UIKit
import UniformTypeIdentifiers

final class J2MEGameSettingsController: UITableViewController, UIDocumentPickerDelegate {
    private let game: Game
    private var preferences: J2MEPreferences
    private var busy = false { didSet {
        tableView.isUserInteractionEnabled = !busy
        navigationItem.rightBarButtonItem?.isEnabled = !busy
    } }
    init(game: Game) {
        self.game = game
        preferences = J2MEPreferences(settings: game.gameSettings as? [String: Any] ?? [:])
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Java ME Settings"
        overrideUserInterfaceStyle = .dark
        tableView.backgroundColor = UIColor(red: 0.055, green: 0.035, blue: 0.105, alpha: 1)
        view.tintColor = J2MEAuroraKey.purple
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preferences = J2MEPreferences(settings: game.gameSettings as? [String: Any] ?? [:]); tableView.reloadData()
    }
    private func save() {
        var settings = game.gameSettings as? [String: Any] ?? [:]
        settings["j2me.preferences"] = preferences.json
        game.gameSettings = settings as NSDictionary
        game.managedObjectContext?.saveWithErrorLogging()
        tableView.reloadData()
        busy = true
        J2MESaveStore.checkpoint(game) { [weak self] result in self?.complete(result) }
    }
    private func complete(_ result: Result<Void, Error>) {
        busy = false
        preferences = J2MEPreferences(settings: game.gameSettings as? [String: Any] ?? [:])
        if case .failure(let error) = result { J2MELibrary.showError(error.localizedDescription, from: self) }
        tableView.reloadData()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 5 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { [2, 5, 2, 5, 2][section] }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { [game.name, "Touch controls", "Performance", "Saves & sync", "Compatibility"][section] }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Presets set the platform hint, default screen size and keys. They do not add unsupported phone APIs. Screen overrides take priority."
        case 1: return "Edit Layout in the game menu: drag controls and pinch to resize. Portrait and landscape layouts save separately. Pair a controller in iOS Settings; Menu pauses the game."
        case 2: return "FPS caps rendering, not the game's own timers. 3D scale affects M3G/MascotCapsule rendering. Lower it to reduce GPU work. Changes apply next launch."
        case 3: return "RMS saves and preferences use Delta Sync (including iCloud when selected). Saves publish after Exit Game. Import and reset keep a recovery backup. These are game saves, not VM save states."
        default: return "Diagnostics include configuration and reported Java errors. They do not include your JAR or saves."
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = J2MEAuroraKey.surface
        cell.accessoryType = .disclosureIndicator
        let row = indexPath.row
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = row == 0 ? "Phone profile" : "Screen configuration"
            let screen = J2MELibrary.screen(for: game, automatic: J2MELibrary.automaticScreen(for: game))
            cell.detailTextLabel?.text = row == 0 ? preferences.phone.title : "\(screen.w) × \(screen.h)"
        case 1:
            cell.textLabel?.text = ["Opacity", "Hide keypad", "Key mapping", "Controller mapping", "Reset touch layouts"][row]
            if row == 0 { cell.detailTextLabel?.text = "\(Int(preferences.opacity * 100))%" }
            if row == 1 {
                let toggle = UISwitch(); toggle.isOn = preferences.hideKeypad
                toggle.addAction(UIAction { [weak self, weak toggle] _ in self?.preferences.hideKeypad = toggle?.isOn ?? false; self?.save() }, for: .valueChanged)
                cell.accessoryView = toggle
            }
        case 2:
            cell.textLabel?.text = row == 0 ? "Frame rate limit" : "3D render scale"
            cell.detailTextLabel?.text = row == 0 ? (preferences.fps == 0 ? "Uncapped" : "\(preferences.fps) FPS") : "\(preferences.scale3D)×"
        case 3:
            cell.textLabel?.text = ["Delta Sync settings", "Export backup", "Import backup", "Restore recovery backup", "Reset game saves"][row]
        default: cell.textLabel?.text = row == 0 ? "Export diagnostics" : "Supported API families"
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, !J2MEGameViewController.isSessionActive else { J2MELibrary.showError("Exit the Java game before changing settings or saves.", from: self); return }
        switch (indexPath.section, indexPath.row) {
        case (0, 0): choose("Phone Profile", values: J2MEPhone.allCases.map { $0.title }) { [weak self] index in
            guard let self else { return }
            self.preferences.phone = J2MEPhone.allCases[index]
            self.preferences.keyOverrides.removeAll()
            self.save()
        }
        case (0, 1):
            let automatic = J2MELibrary.automaticScreen(for: game)
            let controller = J2MEScreenConfigurationController(gameName: game.name, current: J2MELibrary.screen(for: game, automatic: automatic), automatic: automatic, presets: J2MELibrary.presets) { [weak self] size in
                guard let self else { return }
                var settings = self.game.gameSettings as? [String: Any] ?? [:]
                settings["j2me.screenWidth"] = size?.w; settings["j2me.screenHeight"] = size?.h
                self.game.gameSettings = settings as NSDictionary; self.save()
            }
            navigationController?.pushViewController(controller, animated: true)
        case (1, 0): choose("Control Opacity", values: ["25%", "50%", "75%", "100%"]) { [weak self] index in self?.preferences.opacity = [0.25, 0.5, 0.75, 1][index]; self?.save() }
        case (1, 2): mapping(controller: false)
        case (1, 3): mapping(controller: true)
        case (1, 4): preferences.placements.removeAll(); save()
        case (2, 0): choose("Frame Rate", values: ["Uncapped", "15 FPS", "30 FPS", "60 FPS"]) { [weak self] index in self?.preferences.fps = [0, 15, 30, 60][index]; self?.save() }
        case (2, 1): choose("3D Render Scale", values: ["1× Native", "2×", "3×"]) { [weak self] index in self?.preferences.scale3D = index + 1; self?.save() }
        case (3, 0):
            let controller = UIStoryboard(name: "Settings", bundle: nil).instantiateViewController(withIdentifier: "syncingServices")
            navigationController?.pushViewController(controller, animated: true)
        case (3, 1):
            busy = true
            J2MESaveStore.export(game) { [weak self] result in
                guard let self else { return }; self.busy = false
                switch result { case .success(let url): self.share(url); case .failure(let error): J2MELibrary.showError(error.localizedDescription, from: self) }
            }
        case (3, 2):
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            picker.delegate = self; present(picker, animated: true)
        case (3, 3): confirm("Restore Recovery Backup?", message: "Replace current saves with the backup made before your last import or reset.") { [weak self] in
            guard let self else { return }; self.busy = true
            J2MESaveStore.importBackup(J2MESaveStore.recoveryURL(self.game.identifier), game: self.game) { [weak self] in self?.complete($0) }
        }
        case (3, 4): confirm("Reset Game Saves?", message: "This clears this game's RMS progress and syncs the empty save. A recovery backup is kept on this device.") { [weak self] in
            guard let self else { return }; self.busy = true
            J2MESaveStore.reset(self.game) { [weak self] in self?.complete($0) }
        }
        case (4, 0):
            let url = J2MEDiagnostics.url(game.identifier)
            if FileManager.default.fileExists(atPath: url.path) { share(url) }
            else { J2MELibrary.showError("Run this game once to create a session report.", from: self) }
        case (4, 1): J2MELibrary.showError("This engine includes MIDP/CLDC, Nokia UI, Siemens, Sony Ericsson extensions, MascotCapsule and M3G implementations. Coverage varies by game. A phone preset cannot supply a missing class or method.", from: self)
        default: break
        }
    }
    private func mapping(controller: Bool) {
        let labels = controller ? ["A", "B", "X", "Y", "L1", "R1", "L2", "R2"] : ["Up", "Down", "Left", "Right", "Fire", "Left soft key", "Right soft key"]
        let codes = [50, 56, 52, 54, 53, -6, -7]
        choose(controller ? "Controller Mapping" : "Phone Key Mapping", values: labels + ["Reset mapping"]) { [weak self] index in
            guard let self else { return }
            if index == labels.count {
                if controller { self.preferences.controllerKeys.removeAll() } else { self.preferences.keyOverrides.removeAll() }; self.save(); return
            }
            let name = labels[index]
            let current = controller ? (self.preferences.controllerKeys[name] ?? J2MEPreferences.controllerDefaults[name]!) : self.preferences.key(codes[index])
            let alert = UIAlertController(title: name, message: controller ? "Phone key before profile translation: 0–9 = 48–57, * = 42, # = 35, soft keys = -6/-7." : "Raw Java key code (-32768…32767). Common direction/fire codes: -1/-2/-3/-4/-5.", preferredStyle: .alert)
            alert.addTextField { $0.text = String(current); $0.keyboardType = .numbersAndPunctuation }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
                guard let self, let value = Int(alert?.textFields?.first?.text ?? ""), (-32768...32767).contains(value) else { return }
                if controller { self.preferences.controllerKeys[name] = value } else { self.preferences.keyOverrides[String(codes[index])] = value }
                self.save()
            })
            self.present(alert, animated: true)
        }
    }
    private func choose(_ title: String, values: [String], selected: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, value) in values.enumerated() { alert.addAction(UIAlertAction(title: value, style: .default) { _ in selected(index) }) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = view; alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(alert, animated: true)
    }
    private func confirm(_ title: String, message: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { _ in action() }); present(alert, animated: true)
    }
    private func share(_ url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view; controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(controller, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        confirm("Import Java Backup?", message: "Replace this game's saves and preferences. Your current saves will be kept as a recovery backup.") { [weak self] in
            guard let self else { return }; self.busy = true
            J2MESaveStore.importBackup(url, game: self.game) { [weak self] in self?.complete($0) }
        }
    }
}

enum J2MEDiagnostics {
    static func url(_ id: String) -> URL {
        DatabaseManager.gamesDirectoryURL.appendingPathComponent("J2MEDiagnostics", isDirectory: true).appendingPathComponent(id + ".txt")
    }
    static func write(id: String, name: String, screen: String, preferences: J2MEPreferences, result: Int32, error: String?, duration: TimeInterval) {
        let text = "Delta Java ME session\nEngine: JarBox 8afc8d8, interpreter\nGame: \(name)\nDate: \(Date())\nPlatform: \(preferences.phone.platform)\nScreen: \(screen)\nFPS cap: \(preferences.fps)\n3D scale: \(preferences.scale3D)\nDuration: \(Int(duration)) seconds\nResult: \(result)\nJava error: \(error ?? "None reported")\nSupported API coverage varies by game.\n"
        let target = url(id)
        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: target, atomically: true, encoding: .utf8)
    }
}
