import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreData
import ImageIO

/// Imported bytes are staged until the user reviews every destination.
struct ArtworkImportDraft: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    var gameID: NSManagedObjectID?
    var kind: AuroraArtworkKind = .cover
}

@available(iOS 26, *)
struct AuroraArtworkManager: View {
    @ObservedObject var model: AuroraHomeModel
    @State private var query = ""
    @State private var platform: String?
    @State private var missingOnly = false
    @State private var selecting = false
    @State private var selected = Set<NSManagedObjectID>()
    @State private var target: (NSManagedObjectID, AuroraArtworkKind)?
    @State private var photos: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showSources = false
    @State private var drafts: [ArtworkImportDraft] = []
    @State private var reviewing = false
    @State private var busy = false
    @State private var error: String?

    private var games: [AuroraGame] {
        model.games.filter {
            (query.isEmpty || $0.name.localizedStandardContains(query)) &&
            (platform == nil || $0.collectionID == platform) &&
            (!missingOnly || $0.artworkURL == nil || $0.backdropURL == nil)
        }
    }
    private var destinations: [AuroraGame] {
        selected.isEmpty ? model.games : model.games.filter { selected.contains($0.id) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search games", text: $query).autocorrectionDisabled()
                }.padding(14).background(.white.opacity(0.07), in: Capsule())
                Menu {
                    Button("All games") { platform = nil; missingOnly = false }
                    Button("Missing artwork") { platform = nil; missingOnly = true }
                    ForEach(model.platforms) { game in
                        Button(game.platform) { platform = game.collectionID; missingOnly = false }
                    }
                } label: {
                    Label(missingOnly ? "Missing artwork" : model.platforms.first { $0.collectionID == platform }?.platform ?? "All games", systemImage: "gamecontroller")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }.buttonStyle(.glass)
                VStack(spacing: 0) {
                    HStack {
                        Text("Game").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Cover").frame(width: 64)
                        Text("Backdrop").frame(width: 110)
                    }.font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
                    ForEach(games) { game in
                        Divider()
                        row(game)
                    }
                    if games.isEmpty {
                        ContentUnavailableView("No games found", systemImage: "photo", description: Text("Import games into your Library, or change the filter."))
                    }
                }.padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.08)))
                Text(selecting ? "\(selected.count) games selected" : "Tap a cover or backdrop to edit")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(16).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.05, blue: 0.2), Color(red: 0.025, green: 0.04, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .navigationTitle("Artwork").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    target = nil; showSources = true
                } label: { Image(systemName: "photo.badge.plus") }
                    .accessibilityLabel(selecting ? "Import for selected games" : "Import Artwork")
                    .disabled(busy || model.games.isEmpty || (selecting && selected.isEmpty))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(selecting ? "Done" : "Select") { selecting.toggle(); selected.removeAll() }.disabled(busy)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .background {
            ArtworkSourceActionSheet(isPresented: $showSources) { source in
                if source == .photos { showPhotos = true } else { showFiles = true }
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photos, maxSelectionCount: target == nil ? nil : 1, matching: .images)
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            busy = true
            Task {
                do {
                    var imported: [ArtworkImportDraft] = []
                    for (index, item) in items.enumerated() {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                        imported.append(try draft(name: "Photo \(index + 1)", data: data))
                    }
                    drafts = imported; reviewing = true
                } catch { self.error = error.localizedDescription }
                busy = false; photos = []
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image], allowsMultipleSelection: target == nil) { result in
            do {
                let urls = try result.get()
                busy = true
                Task {
                    do {
                        let images = try await Task.detached(priority: .userInitiated) {
                            try urls.map { url -> (String, Data) in
                                let access = url.startAccessingSecurityScopedResource()
                                defer { if access { url.stopAccessingSecurityScopedResource() } }
                                return (url.lastPathComponent, try Data(contentsOf: url))
                            }
                        }.value
                        drafts = try images.map { try draft(name: $0.0, data: $0.1) }
                        reviewing = !drafts.isEmpty
                    } catch { self.error = error.localizedDescription }
                    busy = false
                }
            } catch { self.error = error.localizedDescription }
        }
        .sheet(isPresented: $reviewing, onDismiss: { drafts = [] }) {
            ArtworkImportReview(drafts: $drafts, games: destinations) { changes in
                try await ArtworkBatchWriter.apply(changes)
                model.refresh()
            }
        }
        .alert("Unable to Import Artwork", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .overlay { if busy { ProgressView("Loading images…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
    }
    private func draft(name: String, data: Data) throws -> ArtworkImportDraft {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { throw CocoaError(.fileReadCorruptFile) }
        return ArtworkImportDraft(name: name, data: data, gameID: target?.0 ?? (destinations.count == 1 ? destinations.first?.id : nil), kind: target?.1 ?? .cover)
    }
    private func row(_ game: AuroraGame) -> some View {
        HStack(spacing: 10) {
            if selecting {
                Button { if !selected.insert(game.id).inserted { selected.remove(game.id) } } label: {
                    Image(systemName: selected.contains(game.id) ? "checkmark.circle.fill" : "circle")
                }.accessibilityLabel("Select \(game.name)")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name).font(.subheadline.weight(.semibold))
                Text(game.platform).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            asset(game, kind: .cover, width: 64)
            asset(game, kind: .backdrop, width: 110)
        }.padding(.vertical, 10)
    }
    private func asset(_ game: AuroraGame, kind: AuroraArtworkKind, width: CGFloat) -> some View {
        let url = kind == .cover ? game.artworkURL : game.backdropURL
        return Button { target = (game.id, kind); showSources = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04))
                if let url {
                    AuroraArtwork(url: url, fit: kind == .cover, revision: model.artworkRevision)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    Image(systemName: "plus").foregroundStyle(.secondary)
                }
            }.frame(width: width, height: 64)
        }.buttonStyle(.plain).disabled(busy || selecting).accessibilityLabel("Edit \(kind.title) for \(game.name)")
    }
}

@available(iOS 26, *)
private struct ArtworkImportReview: View {
    @Binding var drafts: [ArtworkImportDraft]
    let games: [AuroraGame]
    let apply: ([ArtworkImportDraft]) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var error: String?
    private var valid: Bool {
        ArtworkImportValidation.canApply(
            assignments: drafts.map { ($0.gameID?.uriRepresentation().absoluteString, $0.kind == .cover ? "cover" : "backdrop") },
            availableGames: Set(games.map { $0.id.uriRepresentation().absoluteString })
        )
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($drafts) { $draft in
                        HStack(alignment: .top, spacing: 12) {
                            ArtworkDraftThumbnail(data: draft.data)
                            VStack(alignment: .leading) {
                                Text(draft.name).font(.subheadline).lineLimit(2)
                                Picker("Game", selection: $draft.gameID) {
                                    Text("Choose game").tag(nil as NSManagedObjectID?)
                                    ForEach(games) { game in Text(game.name).tag(Optional(game.id)) }
                                }
                                Picker("Artwork", selection: $draft.kind) {
                                    Text("Cover").tag(AuroraArtworkKind.cover)
                                    Text("Backdrop").tag(AuroraArtworkKind.backdrop)
                                }.pickerStyle(.segmented)
                            }
                        }.padding(.vertical, 4)
                    }.onDelete { drafts.remove(atOffsets: $0) }
                } footer: {
                    Text(valid ? "Nothing is saved until you apply." : "Choose a game for every image. Each game can receive one cover and one backdrop per import.")
                }
            }.disabled(saving)
                .navigationTitle("Review Import").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) } }
                .safeAreaInset(edge: .bottom) {
                    Button(saving ? "Saving…" : "Apply \(drafts.count) Changes") {
                        saving = true
                        Task {
                            do { try await apply(drafts); dismiss() }
                            catch { self.error = error.localizedDescription; saving = false }
                        }
                    }.buttonStyle(.glassProminent).disabled(!valid || saving).padding()
                }
                .alert("Unable to Save Artwork", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK") { error = nil }
                } message: { Text(error ?? "") }
        }.preferredColorScheme(.dark).interactiveDismissDisabled(saving)
    }
}

private struct ArtworkDraftThumbnail: View {
    let data: Data
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ProgressView() }
        }.frame(width: 60, height: 64).task {
            image = await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil), let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 160] as CFDictionary) else { return nil as UIImage? }
                return UIImage(cgImage: cg)
            }.value
        }
    }
}

/// Files and Core Data changes commit together; a failed save restores existing artwork.
enum ArtworkBatchWriter {
    static func apply(_ drafts: [ArtworkImportDraft]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DatabaseManager.shared.performBackgroundTask { context in
                var backups: [(URL, Data?)] = []
                do {
                    var changed: [Game] = []
                    var destinations = Set<URL>()
                    for draft in drafts {
                        guard let id = draft.gameID, let game = try context.existingObject(with: id) as? Game, !game.isDeleted else { throw CocoaError(.managedObjectReferentialIntegrity) }
                        guard let source = CGImageSourceCreateWithData(draft.data as CFData, nil),
                              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: draft.kind == .cover ? 1000 : 2560] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
                        let image = UIImage(cgImage: cg)
                        guard let data = draft.kind == .cover ? image.pngData() : image.jpegData(compressionQuality: 0.9) else { throw CocoaError(.fileWriteUnknown) }
                        let url = draft.kind == .cover ? DatabaseManager.artworkURL(for: game) : DatabaseManager.gamesDirectoryURL.appendingPathComponent(game.identifier + "-backdrop.jpg")
                        guard destinations.insert(url).inserted else { throw CocoaError(.validationMultipleErrors) }
                        let existing = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
                        backups.append((url, existing))
                        try data.write(to: url, options: .atomic)
                        if draft.kind == .cover { game.artworkURL = url } else { game.backdropURL = url }
                        if !changed.contains(where: { $0.objectID == id }) { changed.append(game) }
                    }
                    try context.save()
                    for game in changed { SyncManager.shared.recordController?.updateRecord(for: game) }
                    for (url, _) in backups { ArtworkImagePipeline.invalidate(url) }
                    continuation.resume()
                } catch {
                    context.rollback()
                    for (url, _) in backups { ArtworkImagePipeline.invalidate(url) }
                    for (url, data) in backups.reversed() {
                        if let data { try? data.write(to: url, options: .atomic) }
                        else { try? FileManager.default.removeItem(at: url) }
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


/// UIAlertController gives iPhone imports the native action-sheet presentation.
/// iPad receives the system-required popover anchor rather than an unsafe presentation.
private struct ArtworkSourceActionSheet: UIViewControllerRepresentable {
    enum Source { case photos, files }
    @Binding var isPresented: Bool
    let choose: (Source) -> Void
    func makeUIViewController(context: Context) -> Presenter { Presenter() }
    func updateUIViewController(_ controller: Presenter, context: Context) {
        controller.show = isPresented
        controller.closed = { isPresented = false }
        controller.choose = choose
        controller.presentIfReady()
    }
    final class Presenter: UIViewController, UIAdaptivePresentationControllerDelegate {
        var show = false
        var closed: (() -> Void)?
        var choose: ((Source) -> Void)?
        override func loadView() { view = UIView(); view.backgroundColor = .clear; view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); presentIfReady() }
        func presentIfReady() {
            guard show, viewIfLoaded?.window != nil, presentedViewController == nil else { return }
            let sheet = UIAlertController(title: String(localized: "Import Artwork"), message: nil, preferredStyle: .actionSheet)
            for (title, source) in [(String(localized: "Photos"), Source.photos), (String(localized: "Files"), Source.files)] {
                sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self, weak sheet] _ in
                    self?.show = false; self?.closed?()
                    sheet?.dismiss(animated: true) { self?.choose?(source) }
                })
            }
            sheet.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { [weak self] _ in
                self?.show = false; self?.closed?()
            })
            if UIDevice.current.userInterfaceIdiom == .pad, let popover = sheet.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
            sheet.presentationController?.delegate = self
            present(sheet, animated: true)
        }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            show = false; closed?()
        }
    }
}
