//
//  AppsListViewController.swift
//  J2MEEmulator
//
//  Springboard-style home screen with app grid.
//

import UIKit
import UniformTypeIdentifiers

class AppsListViewController: UIViewController,
                      UICollectionViewDataSource,
                      UICollectionViewDelegate,
                      UIDocumentPickerDelegate {

    private var springboardCollectionView: UICollectionView!
    private let emptyStateLabel = UILabel()
    private var lastLayoutWidth: CGFloat = 0

    /// Directory where imported JARs are stored
    private static var gamesDirectory: String {
        documentsDirectory + "/games"
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "J2ME Games"
        overrideUserInterfaceStyle = .dark

        // Animated blob background
        let bg = AnimatedBackgroundView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // "+" button — import JAR from Files
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Import JAR", primaryAction: UIAction { [weak self] _ in
                self?.addAppTapped()
            })

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 10

        springboardCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        springboardCollectionView.dataSource = self
        springboardCollectionView.delegate = self
        springboardCollectionView.backgroundColor = .clear
        springboardCollectionView.alwaysBounceVertical = true
        springboardCollectionView.showsVerticalScrollIndicator = false
        springboardCollectionView.register(SpringboardCell.self,
                                           forCellWithReuseIdentifier: SpringboardCell.reuseID)
        springboardCollectionView.contentInsetAdjustmentBehavior = .always
        springboardCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(springboardCollectionView)

        NSLayoutConstraint.activate([
            springboardCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            springboardCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            springboardCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            springboardCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Empty state
        emptyStateLabel.text = "No Games Yet\nTap Import JAR to add a .jar file"
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .systemFont(ofSize: 17)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
        ])

        // Ensure games directory exists
        try? FileManager.default.createDirectory(atPath: Self.gamesDirectory,
                                                  withIntermediateDirectories: true)
        scanApps()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func appDidBecomeActive() {
        scanApps()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = springboardCollectionView.bounds.width
        guard width > 0, width != lastLayoutWidth else { return }
        lastLayoutWidth = width

        let columns: CGFloat = 4
        let iconSize = SpringboardCell.iconSize
        let cellWidth = (width + iconSize) / (columns + 1)
        let horizontalInset = (cellWidth - iconSize) / 2

        guard let layout = springboardCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        layout.itemSize = CGSize(width: cellWidth, height: 96)
        layout.sectionInset = UIEdgeInsets(top: 20, left: horizontalInset,
                                            bottom: 20, right: horizontalInset)
    }

    // ============================================================
    // MARK: - Import JAR from Files
    // ============================================================

    private func addAppTapped() {
        // Files providers may classify JAR as ZIP or generic data. Validate the
        // extension after selection rather than disabling valid archives in Files.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        let fm = FileManager.default
        var imported = 0
        var failures: [String] = []
        let descriptors = urls.filter { $0.pathExtension.lowercased() == "jad" }
        let jars = urls.filter { $0.pathExtension.lowercased() == "jar" }
        for url in urls where !["jar", "jad"].contains(url.pathExtension.lowercased()) {
            failures.append("\(url.lastPathComponent): choose a .jar game or matching .jad descriptor.")
        }
        var importedPaths: [String: URL] = [:]
        for url in jars {
            guard url.pathExtension.lowercased() == "jar" else {
                failures.append("\(url.lastPathComponent): choose a .jar game file.")
                continue
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let directory = URL(fileURLWithPath: Self.gamesDirectory)
            var destination = directory.appendingPathComponent(url.lastPathComponent)
            // Preserve an existing game and its data instead of deleting it first.
            var suffix = 2
            while fm.fileExists(atPath: destination.path) {
                destination = directory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent) (\(suffix)).jar")
                suffix += 1
            }
            do {
                try fm.copyItem(at: url, to: destination)
                imported += 1
                importedPaths[url.deletingPathExtension().lastPathComponent.lowercased()] = destination
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        var attachedDescriptors = 0
        for url in descriptors {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let stem = url.deletingPathExtension().lastPathComponent.lowercased()
            let directory = URL(fileURLWithPath: Self.gamesDirectory)
            let existing = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            let matches = existing.filter { $0.pathExtension.lowercased() == "jar" && $0.deletingPathExtension().lastPathComponent.lowercased() == stem }
            guard let jar = importedPaths[stem] ?? (matches.count == 1 ? matches.first : nil) else {
                failures.append("\(url.lastPathComponent): select its same-name .jar too, or import that game first.")
                continue
            }
            guard !J2MEScreenProfile.descriptorAttributes(at: url).isEmpty else {
                failures.append("\(url.lastPathComponent): unreadable or oversized descriptor.")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                try data.write(to: jar.deletingPathExtension().appendingPathExtension("jad"), options: .atomic)
                attachedDescriptors += 1
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if imported > 0 || attachedDescriptors > 0 { scanApps() }
        if !failures.isEmpty {
            let alert = UIAlertController(title: "Import Failed", message: failures.joined(separator: "\n"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            // Wait until the picker has finished dismissing before showing errors.
            controller.dismiss(animated: true) { [weak self] in self?.present(alert, animated: true) }
        }
    }

    // ============================================================
    // MARK: - App scanning (Documents/games/)
    // ============================================================

    struct AppInfo {
        let name: String
        let path: String
        let fileName: String
        let version: String?
        let vendor: String?
        let icon: UIImage
        let automaticScreen: J2MEScreenProfile
    }
    private var apps: [AppInfo] = []

    private func scanApps() {
        let gamesDir = Self.gamesDirectory

        DispatchQueue.global(qos: .userInitiated).async {
            var jarPaths: [(name: String, path: String)] = []

            if let files = try? FileManager.default.contentsOfDirectory(atPath: gamesDir) {
                for file in files where file.lowercased().hasSuffix(".jar") {
                    jarPaths.append((name: String(file.dropLast(4)), path: gamesDir + "/" + file))
                }
            }

            var unsorted = jarPaths.map { jar -> (String, String, String, String?, String?, UIImage?, J2MEScreenProfile) in
                let meta = JARMetadata.read(from: jar.path)
                let jarIcon = meta?.readIcon(from: jar.path)
                let fileName = URL(fileURLWithPath: jar.path).lastPathComponent
                let appName = meta?.midletName ?? jar.name
                let jadURL = URL(fileURLWithPath: jar.path).deletingPathExtension().appendingPathExtension("jad")
                let jad = J2MEScreenProfile.descriptorAttributes(at: jadURL)
                let detected = J2MEScreenProfile.detect(filename: fileName, manifest: meta?.attributes ?? [:], descriptor: jad)
                return (appName, jar.path, fileName, meta?.version, meta?.vendor, jarIcon, detected)
            }
            unsorted.sort { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }

            let scannedApps = unsorted.enumerated().map { (index, t) in
                AppInfo(name: t.0, path: t.1, fileName: t.2,
                        version: t.3, vendor: t.4,
                        icon: Self.springboardIcon(t.5, name: t.0, index: index), automaticScreen: t.6)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apps = scannedApps
                self.springboardCollectionView.reloadData()
                self.emptyStateLabel.isHidden = !scannedApps.isEmpty
                print("[Swift] Found \(scannedApps.count) MIDlet JARs in \(gamesDir)")
            }
        }
    }

    // ============================================================
    // MARK: - Icon generation
    // ============================================================

    private static let iconSize: CGFloat = SpringboardCell.iconSize

    private static let placeholderGradients: [(UIColor, UIColor)] = [
        (UIColor(red: 0.20, green: 0.40, blue: 0.90, alpha: 1),
         UIColor(red: 0.35, green: 0.60, blue: 1.00, alpha: 1)),
        (UIColor(red: 0.00, green: 0.68, blue: 0.63, alpha: 1),
         UIColor(red: 0.20, green: 0.85, blue: 0.60, alpha: 1)),
        (UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1),
         UIColor(red: 1.00, green: 0.75, blue: 0.28, alpha: 1)),
        (UIColor(red: 0.88, green: 0.22, blue: 0.28, alpha: 1),
         UIColor(red: 1.00, green: 0.42, blue: 0.48, alpha: 1)),
        (UIColor(red: 0.58, green: 0.28, blue: 0.85, alpha: 1),
         UIColor(red: 0.72, green: 0.48, blue: 1.00, alpha: 1)),
        (UIColor(red: 0.22, green: 0.30, blue: 0.80, alpha: 1),
         UIColor(red: 0.38, green: 0.48, blue: 0.95, alpha: 1)),
        (UIColor(red: 0.90, green: 0.28, blue: 0.52, alpha: 1),
         UIColor(red: 1.00, green: 0.48, blue: 0.68, alpha: 1)),
        (UIColor(red: 0.15, green: 0.65, blue: 0.42, alpha: 1),
         UIColor(red: 0.28, green: 0.82, blue: 0.55, alpha: 1)),
    ]

    private static func springboardIcon(_ jarIcon: UIImage?, name: String, index: Int) -> UIImage {
        let size = CGSize(width: iconSize, height: iconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            UIBezierPath(roundedRect: rect, cornerRadius: SpringboardCell.iconCornerRadius).addClip()

            if let img = jarIcon {
                UIColor(white: 0.22, alpha: 1).setFill()
                UIBezierPath(rect: rect).fill()
                img.draw(in: rect)
            } else {
                let pair = placeholderGradients[index % placeholderGradients.count]
                let cgCtx = ctx.cgContext
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorsSpace: colorSpace,
                                              colors: [pair.0.cgColor, pair.1.cgColor] as CFArray,
                                              locations: [0, 1]) {
                    cgCtx.drawLinearGradient(gradient, start: .zero,
                                             end: CGPoint(x: iconSize, y: iconSize), options: [])
                }
                let letter = String(name.prefix(1)).uppercased()
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .font: UIFont.systemFont(ofSize: iconSize * 0.42, weight: .semibold)
                ]
                let strSize = (letter as NSString).size(withAttributes: attrs)
                (letter as NSString).draw(
                    at: CGPoint(x: (iconSize - strSize.width) / 2,
                                y: (iconSize - strSize.height) / 2),
                    withAttributes: attrs)
            }

            let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                                           cornerRadius: SpringboardCell.iconCornerRadius - 0.5)
            UIColor(white: 1.0, alpha: 0.12).setStroke()
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
    }

    // ============================================================
    // MARK: - UICollectionView
    // ============================================================

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        apps.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SpringboardCell.reuseID, for: indexPath) as! SpringboardCell
        let app = apps[indexPath.item]
        cell.configure(name: app.name, icon: app.icon)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        let app = apps[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            let ssEnabled = Self.is3DSupersampling(for: app)
            let toggle3D = UIAction(title: ssEnabled ? "Disable 3D Enhancement" : "Enable 3D Enhancement",
                                    subtitle: ssEnabled ? "Lower quality, but closer to original" : "Smoother 3D, but not original-accurate",
                                    image: UIImage(systemName: "cube"),
                                    state: ssEnabled ? .on : .off) { _ in
                Self.set3DSupersampling(!ssEnabled, for: app)
            }
            let clearData = UIAction(title: "Clear Game Data",
                                     image: UIImage(systemName: "eraser")) { _ in
                self?.confirmClearGameData(for: app)
            }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { _ in
                self?.confirmDeleteApp(at: indexPath)
            }
            let currentRes = Self.resolution(for: app)
            let screenConfig = UIAction(title: "Screen Configuration",
                subtitle: "\(currentRes.w) × \(currentRes.h) · \(Self.screenProfile(for: app).source.rawValue)",
                image: UIImage(systemName: "aspectratio")) { [weak self] _ in
                guard let self else { return }
                let config = J2MEScreenConfigurationController(gameName: app.name,
                    current: Self.screenProfile(for: app), automatic: app.automaticScreen, presets: Self.resolutionOptions) { size in
                    Self.setResolution(w: size?.w, h: size?.h, for: app)
                }
                let nav = UINavigationController(rootViewController: config)
                nav.modalPresentationStyle = .pageSheet
                nav.sheetPresentationController?.detents = [.medium(), .large()]
                self.present(nav, animated: true)
            }

            let currentFps = Self.fpsLimit(for: app)
            let fpsActions = Self.fpsLimitOptions.map { opt in
                UIAction(title: opt.label,
                         state: opt.value == currentFps ? .on : .off) { _ in
                    Self.setFpsLimit(opt.value, for: app)
                }
            }
            let fpsMenu = UIMenu(title: "FPS Limit",
                                  subtitle: "High FPS may break some games",
                                  image: UIImage(systemName: "gauge.with.needle"),
                                  children: fpsActions)

            let settings = UIMenu(options: .displayInline, children: [screenConfig, toggle3D, fpsMenu])
            let actions = UIMenu(options: .displayInline, children: [clearData, delete])
            return UIMenu(children: [settings, actions])
        })
    }

    // MARK: - Per-game settings

    private static func gameId(for app: AppInfo) -> String {
        let jarName = URL(fileURLWithPath: app.path).deletingPathExtension().lastPathComponent
        return jarName.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
    }

    static func is3DSupersampling(for app: AppInfo) -> Bool {
        UserDefaults.standard.object(forKey: "ss3d_\(gameId(for: app))") as? Bool ?? true
    }

    static func set3DSupersampling(_ enabled: Bool, for app: AppInfo) {
        UserDefaults.standard.set(enabled, forKey: "ss3d_\(gameId(for: app))")
    }

    private static let resolutionOptions: [(label: String, w: Int, h: Int)] = [
        // Common phone resolutions, including landscape variants.
        ("101×80",   101,  80),
        ("128×128",  128, 128),
        ("128×160",  128, 160),
        ("132×176",  132, 176),
        ("160×128",  160, 128),
        ("176×208",  176, 208),
        ("176×220",  176, 220),
        ("208×208",  208, 208),
        ("220×220",  220, 220),
        ("240×266",  240, 266),
        ("240×320",  240, 320),
        ("320×240",  320, 240),
        ("240×400",  240, 400),
        ("320×480",  320, 480),
        ("480×320",  480, 320),
        ("352×416",  352, 416),
        ("360×640",  360, 640),
        ("480×800",  480, 800),
    ]

    static func screenProfile(for app: AppInfo) -> J2MEScreenProfile {
        let gid = gameId(for: app)
        if let w = UserDefaults.standard.object(forKey: "resW_\(gid)") as? Int,
           let h = UserDefaults.standard.object(forKey: "resH_\(gid)") as? Int,
           J2MEScreenProfile.valid(w, h) { return J2MEScreenProfile(w: w, h: h, source: .manual) }
        return app.automaticScreen
    }

    static func resolution(for app: AppInfo) -> (w: Int, h: Int) {
        let profile = screenProfile(for: app)
        return (profile.w, profile.h)
    }

    private static func setResolution(w: Int?, h: Int?, for app: AppInfo) {
        let gid = gameId(for: app)
        if let w, let h, J2MEScreenProfile.valid(w, h) {
            UserDefaults.standard.set(w, forKey: "resW_\(gid)")
            UserDefaults.standard.set(h, forKey: "resH_\(gid)")
        } else {
            UserDefaults.standard.removeObject(forKey: "resW_\(gid)")
            UserDefaults.standard.removeObject(forKey: "resH_\(gid)")
        }
    }

    private static let fpsLimitOptions: [(label: String, value: Int)] = [
        ("Unlimited", 0),
        ("15 FPS",   15),
        ("20 FPS",   20),
        ("30 FPS",   30),
        ("60 FPS",   60),
    ]

    static func fpsLimit(for app: AppInfo) -> Int {
        UserDefaults.standard.object(forKey: "fpsLimit_\(gameId(for: app))") as? Int ?? 60
    }

    private static func setFpsLimit(_ fps: Int, for app: AppInfo) {
        UserDefaults.standard.set(fps, forKey: "fpsLimit_\(gameId(for: app))")
    }

    private static var documentsDirectory: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
    }

    private func confirmClearGameData(for app: AppInfo) {
        let alert = UIAlertController(title: "Clear Game Data",
                                       message: "Delete all save data for \(app.name)?",
                                       preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            let gid = Self.gameId(for: app)
            try? FileManager.default.removeItem(atPath: Self.documentsDirectory + "/Games Data/" + gid)
        })
        present(alert, animated: true)
    }

    private func confirmDeleteApp(at indexPath: IndexPath) {
        let app = apps[indexPath.item]
        let alert = UIAlertController(title: "Delete Game",
                                       message: "Delete \(app.name) and all its save data?",
                                       preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let gid = Self.gameId(for: app)
            try? FileManager.default.removeItem(atPath: Self.documentsDirectory + "/Games Data/" + gid)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: app.path).deletingPathExtension().appendingPathExtension("jad"))
            try? FileManager.default.removeItem(atPath: app.path)
            self.springboardCollectionView.performBatchUpdates {
                self.apps.remove(at: indexPath.item)
                self.springboardCollectionView.deleteItems(at: [indexPath])
            }
            self.emptyStateLabel.isHidden = !self.apps.isEmpty
        })
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let app = apps[indexPath.item]

        let render3dScale = Self.is3DSupersampling(for: app) ? 3 : 1
        let res = Self.resolution(for: app)
        let fps = Self.fpsLimit(for: app)
        let gameVC = GameViewController(jarPath: app.path, appName: app.name, appIcon: app.icon,
                                         canvasWidth: res.w, canvasHeight: res.h,
                                         render3dScale: render3dScale, fpsLimit: fps)
        gameVC.modalPresentationStyle = .fullScreen

        let itemIndex = indexPath.item
        let options = UIViewController.Transition.ZoomOptions()
        options.interactiveDismissShouldBegin = { _ in false }
        // Zoom lands on the placeholder icon centered in the game screen
        options.alignmentRectProvider = { context in
            guard let gvc = context.zoomedViewController as? GameViewController,
                  let placeholder = gvc.placeholderIconView else {
                return .null
            }
            return placeholder.frame
        }

        gameVC.preferredTransition = .zoom(options: options) {
            [weak self] _ in
            guard let self,
                  let cell = self.springboardCollectionView.cellForItem(
                      at: IndexPath(item: itemIndex, section: 0)) as? SpringboardCell else {
                return nil
            }
            return cell.iconView
        }

        present(gameVC, animated: true)
    }
}

/// Changes the emulated phone display, independently from iPhone orientation.
private final class J2MEScreenConfigurationController: UITableViewController {
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
        view.tintColor = AuroraKey.purple
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
        cell.backgroundColor = AuroraKey.surface
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
