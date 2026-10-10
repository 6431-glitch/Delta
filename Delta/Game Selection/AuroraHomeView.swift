import SwiftUI
import CoreData
import UIKit
import SDWebImage

/// Immutable presentation data keeps Core Data objects on the controller's queue.
struct AuroraGame: Identifiable, Equatable {
    let id: NSManagedObjectID
    let name: String
    let platform: String
    let collectionID: String
    let artworkURL: URL?
    let backdropURL: URL?
    let isFavorite: Bool
    let playedDate: Date?
}

enum AuroraArtworkKind {
    case cover, backdrop
    var title: String { self == .cover ? String(localized: "Cover") : String(localized: "Backdrop") }
}


final class AuroraHomeModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published private(set) var games: [AuroraGame] = []
    @Published var selectedID: NSManagedObjectID?
    @Published var collectionID: String?
    @Published var favoritesOnly = false
    @Published var query = ""
    @Published var bannerOnly = false
    @Published var orientation = AppOrientation.current
    @Published var orientationError: String?
    @Published var artworkRevision = UUID()
    @Published var selectedTab = 0
    private let results: NSFetchedResultsController<Game>
    #if DEBUG
    private let previewContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    var isPreview: Bool { ProcessInfo.processInfo.environment["AURORA_PREVIEW_ARTWORK"] != nil }
    #else
    var isPreview: Bool { false }
    #endif
    var launch: ((NSManagedObjectID) -> Void)?
    var favorite: ((NSManagedObjectID) -> Void)?
    var importGames: (() -> Void)?
    var gameActions: ((NSManagedObjectID, UIView) -> [UIMenuElement])?
    var dragProvider: ((NSManagedObjectID) -> NSItemProvider?)?
    var changeOrientation: ((AppOrientation) -> Void)?
    var tabChanged: (() -> Void)?

    override init() {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.name, ascending: true)]
        results = NSFetchedResultsController(fetchRequest: request, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        super.init()
        results.delegate = self
        #if DEBUG
        if ProcessInfo.processInfo.environment["AURORA_QA_TAB"] == "settings" { selectedTab = 1 }
        #endif
    }
    func refresh() {
        artworkRevision = UUID()
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["AURORA_PREVIEW_ARTWORK"] {
            if games.isEmpty {
                let names = ["Star Voyager", "Pocket Garden", "Moonlight Quest", "Circuit Rush", "Mystic Isles", "Pixel Rally", "Sky Realms"]
                games = names.enumerated().map { index, name in
                    let game = Game(entity: Game.entity(), insertInto: previewContext)
                    return AuroraGame(id: game.objectID, name: name, platform: index < 4 ? "SNES" : "GBA", collectionID: index < 4 ? "preview-snes" : "preview-gba", artworkURL: URL(fileURLWithPath: path), backdropURL: nil, isFavorite: index == 2, playedDate: Date().addingTimeInterval(Double(-index * 3600)))
                }
                selectedID = games.first?.id
            }
            return
        }
        #endif
        do {
            try results.performFetch()
            publishGames()
        } catch { orientationError = error.localizedDescription }
    }
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) { if !isPreview { publishGames() } }
    private func publishGames() {
        games = (results.fetchedObjects ?? []).map {
            AuroraGame(id: $0.objectID, name: $0.name, platform: $0.gameCollection?.shortName ?? "", collectionID: $0.gameCollection?.identifier ?? "", artworkURL: $0.artworkURL, backdropURL: $0.backdropURL, isFavorite: $0.isFavorite, playedDate: $0.playedDate)
        }
        if !games.contains(where: { $0.collectionID == collectionID }) { collectionID = nil }
        reconcileSelection()
        if selectedGame == nil { bannerOnly = false }
    }
    var filteredGames: [AuroraGame] {
        games.filter {
            (collectionID == nil || $0.collectionID == collectionID) &&
            (!favoritesOnly || $0.isFavorite) &&
            (query.isEmpty || $0.name.localizedStandardContains(query))
        }
    }
    var recentGames: [AuroraGame] {
        Array(games.filter { $0.playedDate != nil }.sorted { $0.playedDate! > $1.playedDate! }.prefix(12))
    }
    var selectedGame: AuroraGame? { filteredGames.first { $0.id == selectedID } ?? filteredGames.first }
    var platforms: [AuroraGame] {
        var seen = Set<String>()
        return games.filter { seen.insert($0.collectionID).inserted }
    }
    func reconcileSelection() {
        if !filteredGames.contains(where: { $0.id == selectedID }) {
            selectedID = filteredGames.first?.id
        }
    }
    func togglePreviewFavorite(_ id: NSManagedObjectID) {
        guard isPreview, let index = games.firstIndex(where: { $0.id == id }) else { return }
        let game = games[index]
        games[index] = AuroraGame(id: game.id, name: game.name, platform: game.platform, collectionID: game.collectionID, artworkURL: game.artworkURL, backdropURL: game.backdropURL, isFavorite: !game.isFavorite, playedDate: game.playedDate)
        reconcileSelection()
    }
    func select(_ game: AuroraGame) {
        if !filteredGames.contains(where: { $0.id == game.id }) {
            collectionID = nil; favoritesOnly = false; query = ""
        }
        selectedID = game.id
    }
}

/// SDWebImage handles local covers, remote covers, caching and cancellation.
private struct AuroraArtwork: UIViewRepresentable {
    let url: URL?
    var fit = false
    var revision: UUID? = nil
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.clipsToBounds = true
        view.tintColor = .white.withAlphaComponent(0.35)
        view.backgroundColor = UIColor(red: 0.08, green: 0.07, blue: 0.18, alpha: 1)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }
    func updateUIView(_ view: UIImageView, context: Context) {
        view.contentMode = fit ? .scaleAspectFit : .scaleAspectFill
        guard context.coordinator.url != url || context.coordinator.revision != revision || !context.coordinator.loaded else { return }
        context.coordinator.url = url
        context.coordinator.revision = revision
        context.coordinator.loaded = true
        view.sd_setImage(with: url, placeholderImage: UIImage(systemName: "gamecontroller"), options: [])
    }
    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) { view.sd_cancelCurrentImageLoad() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var url: URL?; var revision: UUID?; var loaded = false }
}

@available(iOS 26, *)
struct AuroraLibraryTabs: View {
    @ObservedObject var model: AuroraHomeModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            Tab("Library", systemImage: "square.grid.2x2", value: 0) {
                AuroraHomeView(model: model)
            }
            Tab("Settings", systemImage: "gearshape", value: 1) {
                SettingsView(isTab: true)
            }
        }
        .toolbar(model.bannerOnly ? .hidden : .visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .tint(Color(red: 0.73, green: 0.52, blue: 1))
        .onReceive(NotificationCenter.default.publisher(for: AppOrientation.didChange)) { _ in
            model.orientation = AppOrientation.current
        }
        .onChange(of: model.selectedTab) { previous, current in
            model.tabChanged?()
            if previous == 1 && current == 0 {
                SyncManager.shared.sync()
                model.refresh()
            }
        }
    }
}

@available(iOS 26, *)
struct AuroraHomeView: View {
    @ObservedObject var model: AuroraHomeModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var searchVisible = false
    @State private var gridVisible = false
    @FocusState private var searchFocused: Bool
    @State private var wheelProgress: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.11).ignoresSafeArea()
                backdrop(progress: landscape && !gridVisible && !model.bannerOnly ? wheelProgress : nil)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(model.bannerOnly ? 0 : 0.2))
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                if model.bannerOnly {
                    VStack { HStack { Spacer(); eyeButton }; Spacer() }.padding(16)
                } else if gridVisible {
                    gridLibrary(landscape: landscape)
                } else if landscape {
                    landscapeHome(geometry: geometry)
                } else {
                    portraitHome(geometry: geometry)
                }
            }
            .foregroundStyle(.white)
            .preferredColorScheme(.dark)
            .ignoresSafeArea(.keyboard)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.bannerOnly)
            .onChange(of: model.query) { model.reconcileSelection() }
            .onChange(of: model.collectionID) { model.reconcileSelection() }
            .onChange(of: model.favoritesOnly) { model.reconcileSelection() }
            .onChange(of: landscape) { searchFocused = false }
            .onPreferenceChange(AuroraWheelProgressKey.self) { wheelProgress = $0 }
            .alert("Unable to Update Home", isPresented: Binding(get: { model.orientationError != nil }, set: { if !$0 { model.orientationError = nil } })) {
                Button("OK") { model.orientationError = nil }
            } message: { Text(model.orientationError ?? "") }
        }
    }

    /// The incoming image sits over an opaque outgoing image. Its opacity is the
    /// fractional scroll distance, keeping total coverage constant at every point.
    @ViewBuilder
    private func backdrop(progress: CGFloat?) -> some View {
        let games = model.filteredGames
        if !games.isEmpty {
            let selected = games.firstIndex { $0.id == model.selectedGame?.id } ?? 0
            let position = min(CGFloat(games.count - 1), max(0, progress ?? CGFloat(selected)))
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, games.count - 1)
            let fraction = Double(position - CGFloat(lower))
            ZStack {
                // Retain the previous image too, so reversing at an integer boundary
                // reuses the already-loaded view instead of mounting it again.
                ForEach(games[max(0, lower - 1)...upper]) { game in
                    backdropImage(game)
                        .opacity(game.id == games[lower].id ? 1 : (game.id == games[upper].id ? fraction : 0))
                        .zIndex(game.id == games[upper].id && upper != lower ? 1 : 0)
                }
            }
            // Scroll geometry supplies the animation; no timed easing can lag behind a reversal.
            .transaction { $0.animation = nil }
        }
    }

    private func backdropImage(_ game: AuroraGame) -> some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.11)
            if let url = game.backdropURL ?? game.artworkURL {
                AuroraArtwork(url: url, revision: model.artworkRevision)
            }
        }
    }

    private var orientationMenu: some View {
        Menu {
            ForEach(AppOrientation.allCases, id: \.rawValue) { orientation in
                Button {
                    model.changeOrientation?(orientation)
                } label: {
                    Label(orientation.title, systemImage: model.orientation == orientation ? "checkmark" : orientation.symbol)
                }
            }
        } label: {
            Image(systemName: model.orientation.symbol)
                .overlay(alignment: .bottomTrailing) {
                    if model.orientation != .automatic { Image(systemName: "lock.fill").font(.system(size: 9)).offset(x: 5, y: 4) }
                }
                .frame(width: 44, height: 44)
                .glassEffect(.regular.tint(model.orientation == .automatic ? .clear : .purple.opacity(0.25)).interactive(), in: .circle)
        }
        .accessibilityLabel("Orientation")
        .accessibilityValue(model.orientation.title)
    }
    private var eyeButton: some View {
        iconButton(model.bannerOnly ? "eye.slash" : "eye", label: model.bannerOnly ? "Show Home Controls" : "View Banner") {
            searchFocused = false
            model.bannerOnly.toggle()
        }
        .disabled(model.selectedGame == nil)
    }
    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44) }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(Text(label))
    }
    private var tools: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                orientationMenu
                eyeButton
                iconButton("plus", label: "Import Games") { model.importGames?() }
                iconButton(gridVisible ? "rectangle.stack" : "square.grid.2x2", label: gridVisible ? "Carousel View" : "Grid View") { gridVisible.toggle() }
            }
        }
    }
    private var platformMenu: some View {
        Menu {
            Button("All Games") { model.collectionID = nil; model.favoritesOnly = false }
            Button("Favorites", systemImage: "star") { model.collectionID = nil; model.favoritesOnly = true }
            ForEach(model.platforms) { platform in
                Button(platform.platform) { model.collectionID = platform.collectionID; model.favoritesOnly = false }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: model.favoritesOnly ? "star.fill" : "gamecontroller")
                Text(model.favoritesOnly ? String(localized: "Favorites") : model.platforms.first { $0.collectionID == model.collectionID }?.platform ?? String(localized: "All Games"))
                Image(systemName: "chevron.down").font(.caption)
            }.font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44)
                .glassEffect(.regular.interactive(), in: .capsule)
        }.accessibilityLabel("Game Collection")
    }
    private var searchControl: some View {
        HStack(spacing: 10) {
            Button { searchVisible = true; searchFocused = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("Search Games")
            if searchVisible {
                TextField("Search games", text: $model.query).focused($searchFocused).submitLabel(.search)
                    .autocorrectionDisabled()
                Button("Close Search", systemImage: "xmark") {
                    searchFocused = false; searchVisible = false; model.query = ""
                }.labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
        }.frame(maxWidth: searchVisible ? .infinity : 44)
            .glassEffect(.regular.interactive(), in: .capsule)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: searchVisible)
    }
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller").font(.largeTitle)
            Text(model.games.isEmpty ? "Your next adventure starts here" : "No matching games").font(.title2.bold())
            Text(model.games.isEmpty ? "Import a game to build your library." : "Try another collection or search.").foregroundStyle(.secondary)
            if model.games.isEmpty { Button("Import Games", systemImage: "plus") { model.importGames?() }.buttonStyle(.glassProminent) }
            else { Button("Show All Games") { model.query = ""; model.collectionID = nil; model.favoritesOnly = false }.buttonStyle(.glass) }
        }.multilineTextAlignment(.center).padding(24)
    }

    private func portraitHome(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            HStack {
                if !searchVisible { Text("Library").font(.largeTitle.bold()); Spacer() }
                GlassEffectContainer { HStack(spacing: 10) {
                    searchControl
                    if !searchVisible {
                        iconButton("plus", label: "Import Games") { model.importGames?() }
                        orientationMenu
                        iconButton("square.grid.2x2", label: "Grid View") { gridVisible = true }
                    }
                } }
            }.padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    platformMenu.padding(.horizontal, 20)
                    if model.filteredGames.isEmpty { emptyState.frame(maxWidth: .infinity) }
                    else {
                        TabView(selection: Binding(get: { model.selectedGame?.id }, set: { model.selectedID = $0 })) {
                            ForEach(model.filteredGames) { game in
                                hero(game: game).padding(.horizontal, 20).padding(.bottom, 28).tag(Optional(game.id))
                            }
                        }.tabViewStyle(.page(indexDisplayMode: .automatic))
                            .frame(height: max(340, min(540, geometry.size.height * 0.62)))
                        if !model.recentGames.isEmpty { recentShelf }
                    }
                }.padding(.bottom, 16)
            }
        }.padding(.top, 8).padding(.bottom, 8)
            .background(.black.opacity(0.45))
    }
    private func hero(game: AuroraGame) -> some View {
        ZStack(alignment: .bottom) {
            AuroraArtwork(url: game.backdropURL ?? game.artworkURL, revision: model.artworkRevision)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 12) {
                AuroraArtwork(url: game.artworkURL, fit: true, revision: model.artworkRevision)
                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text(game.name).font(.title2.bold()).lineLimit(2)
                    HStack {
                        Label(game.platform, systemImage: "gamecontroller").font(.subheadline)
                        Spacer()
                        playButton(game)
                    }
                }
            }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)).padding(10)
        }.clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(alignment: .topTrailing) {
                GlassEffectContainer { HStack(spacing: 8) { gameMenu(game); eyeButton } }.padding(12)
            }
            .accessibilityElement(children: .contain)
    }
    private func gameMenu(_ game: AuroraGame) -> some View {
        AuroraGameMenuButton { source in model.gameActions?(game.id, source) ?? [] }
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private func playButton(_ game: AuroraGame) -> some View {
        Button(game.playedDate == nil ? "Play" : "Resume", systemImage: "play.fill") { model.launch?(game.id) }
            .font(.headline).padding(.horizontal, 10).frame(minHeight: 44).buttonStyle(.glassProminent)
            .tint(.purple)
    }
    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Played").font(.title3.bold()).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(model.recentGames) { game in
                        Button { model.select(game) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AuroraArtwork(url: game.artworkURL, fit: true, revision: model.artworkRevision).frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(game.name).font(.caption).lineLimit(2).frame(width: 100, alignment: .leading)
                            }
                        }.buttonStyle(.plain).accessibilityLabel(Text(game.name))
                    }
                }.padding(.horizontal, 20)
            }
        }
    }
    private func gridLibrary(landscape: Bool) -> some View {
        VStack(spacing: 12) {
            HStack {
                platformMenu
                Spacer(minLength: 8)
                searchControl
                iconButton("plus", label: "Import Games") { model.importGames?() }
                iconButton("rectangle.stack", label: "Carousel View") { gridVisible = false }
            }.padding(.horizontal, 16)
            if model.filteredGames.isEmpty { emptyState.frame(maxWidth: .infinity, maxHeight: .infinity) }
            else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 180 : 140), spacing: 16)], spacing: 20) {
                        ForEach(model.filteredGames) { game in
                            VStack(alignment: .leading, spacing: 8) {
                                Button { model.select(game); gridVisible = false } label: {
                                    AuroraArtwork(url: game.artworkURL, fit: true, revision: model.artworkRevision)
                                        .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18))
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(.plain).accessibilityLabel(Text(game.name))
                                    .onDrag { model.dragProvider?(game.id) ?? NSItemProvider() }
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(game.name).font(.subheadline.bold()).lineLimit(2)
                                        Text(game.platform).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    gameMenu(game)
                                }
                            }.padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                        }
                    }.padding(16)
                }
            }
        }.padding(.vertical, 8).background(.black.opacity(0.45))
    }

    private func landscapeHome(geometry: GeometryProxy) -> some View {
        let wheelWidth = min(260.0, geometry.size.width * 0.29)
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom).ignoresSafeArea().allowsHitTesting(false)
            HStack(spacing: 0) {
                ZStack {
                    if !model.filteredGames.isEmpty {
                        AuroraWheel(model: model, leadingOverflow: geometry.safeAreaInsets.leading)
                            .padding(.top, 48)
                    }
                }.frame(width: wheelWidth, height: geometry.size.height)
                    .background(alignment: .topLeading) {
                        // Only the backdrop extends beneath the safe area; covers and controls stay inset.
                        Rectangle().fill(reduceTransparency ? AnyShapeStyle(Color.black) : AnyShapeStyle(.ultraThinMaterial))
                            .opacity(reduceTransparency ? 1 : 0.85)
                            .mask(LinearGradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white.opacity(0.95), location: 0.25),
                                .init(color: .white.opacity(0.8), location: 0.45),
                                .init(color: .white.opacity(0.45), location: 0.65),
                                .init(color: .white.opacity(0.12), location: 0.85),
                                .init(color: .clear, location: 1)
                            ], startPoint: .leading, endPoint: .trailing))
                            .frame(width: wheelWidth + geometry.safeAreaInsets.leading,
                                   height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                            .offset(x: -geometry.safeAreaInsets.leading, y: -geometry.safeAreaInsets.top)
                            .allowsHitTesting(false)
                    }
                Spacer(minLength: 0)
            }
            if model.filteredGames.isEmpty { emptyState.padding(.leading, wheelWidth).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let game = model.selectedGame {
                VStack(alignment: .leading, spacing: 10) {
                    Text(game.name).font(typeSize.isAccessibilitySize ? .title3.bold() : .title.bold()).lineLimit(2)
                    Text(game.platform).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    HStack(spacing: 12) {
                        playButton(game)
                        gameMenu(game)
                        iconButton(game.isFavorite ? "heart.fill" : "heart", label: game.isFavorite ? "Unfavorite" : "Favorite") { model.favorite?(game.id) }

                    }
                }.padding(.leading, wheelWidth + 16).padding(.trailing, 20).padding(.bottom, 16)
            }
            VStack {
                HStack(alignment: .top) {
                    GlassEffectContainer { HStack(spacing: 8) {
                        platformMenu
                        searchControl
                    } }
                    Spacer(minLength: 8)
                    tools
                }
                Spacer()
            }.padding(.horizontal, 12).padding(.top, 8)
        }
    }
}

/// Resolve actions when the menu opens so its popovers always use the tapped button.
private struct AuroraGameMenuButton: UIViewRepresentable {
    let actions: (UIView) -> [UIMenuElement]
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .white
        button.accessibilityLabel = String(localized: "Game Actions")
        button.showsMenuAsPrimaryAction = true
        return button
    }
    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak button] completion in
            guard let button else { completion([]); return }
            completion(actions(button))
        }])
    }
}

@available(iOS 26, *)
private struct AuroraWheelProgressKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

@available(iOS 26, *)
private struct AuroraWheel: View {
    @ObservedObject var model: AuroraHomeModel
    var leadingOverflow: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollPosition: CGFloat = 0
    @State private var scrollTargetID: NSManagedObjectID?

    init(model: AuroraHomeModel, leadingOverflow: CGFloat) {
        self.model = model
        self.leadingOverflow = leadingOverflow
        let index = model.filteredGames.firstIndex { $0.id == model.selectedGame?.id } ?? 0
        _scrollPosition = State(initialValue: CGFloat(index))
        _scrollTargetID = State(initialValue: model.selectedGame?.id)
    }

    var body: some View {
        GeometryReader { geometry in
            let step = max(68, min(100, geometry.size.height * 0.27))
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.filteredGames) { game in
                        Color.clear.frame(maxWidth: .infinity).frame(height: step)
                            .id(game.id)
                            .accessibilityHidden(true)
                    }
                }
                .scrollTargetLayout()
                .onGeometryChange(for: CGFloat.self) { content in
                    let top = content.frame(in: .named("wheelViewport")).minY
                    return (geometry.size.height / 2 - step / 2 - top) / step
                } action: { position in
                    scrollPosition = position
                    if let id = centeredGameID(at: position), model.selectedID != id {
                        model.selectedID = id
                    }
                }
            }
            .safeAreaPadding(.vertical, max(0, (geometry.size.height - step) / 2))
            // Native scroll targeting is separate from the selected game. Updating the
            // details during a drag must not issue a programmatic snap back to that row.
            .scrollPosition(id: $scrollTargetID, anchor: .center)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .overlay {
                wheelArtwork(size: geometry.size, step: step)
                    .allowsHitTesting(false)
            }
            // Fade vertically across the artwork's full drawing bounds, including the
            // space outside the leading safe area used by rotated neighboring covers.
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.15), location: 0.05),
                .init(color: .white.opacity(0.6), location: 0.15),
                .init(color: .white, location: 0.3),
                .init(color: .white, location: 0.7),
                .init(color: .white.opacity(0.6), location: 0.85),
                .init(color: .white.opacity(0.15), location: 0.95),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .frame(width: geometry.size.width + leadingOverflow, height: geometry.size.height)
                .offset(x: -leadingOverflow / 2))
            // Covers have no buttons, menus, or launch action. VoiceOver can still scroll the wheel.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Game Wheel")
            .accessibilityValue(model.selectedGame?.name ?? "")
            .accessibilityAdjustableAction { direction in
                let games = model.filteredGames
                guard !games.isEmpty else { return }
                let index = games.firstIndex { $0.id == model.selectedGame?.id } ?? 0
                let next = direction == .increment ? min(index + 1, games.count - 1) : max(index - 1, 0)
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { model.selectedID = games[next].id }
            }
        }
        .coordinateSpace(name: "wheelViewport")
        .preference(key: AuroraWheelProgressKey.self, value: scrollPosition)
        .onAppear { scrollTargetID = model.selectedGame?.id }
        .onChange(of: model.selectedID) { _, id in
            if id != centeredGameID(at: scrollPosition) { scrollTargetID = id }
        }
    }

    private func centeredGameID(at position: CGFloat) -> NSManagedObjectID? {
        let games = model.filteredGames
        guard position.isFinite, !games.isEmpty else { return nil }
        let index = Int(min(CGFloat(games.count - 1), max(0, position.rounded())))
        return games[index].id
    }

    /// All visible covers share one drawing stack, so native scroll-row compositing cannot
    /// place the following row in front. Depth follows distance to the actual center.
    private func wheelArtwork(size: CGSize, step: CGFloat) -> some View {
        let games = model.filteredGames
        let center = Int(scrollPosition.rounded())
        let lower = min(games.count, max(0, center - 4))
        let upper = max(lower, min(games.count, center + 5))
        return ZStack {
            ForEach(lower..<upper, id: \.self) { index in
                wheelItem(games[index], distance: CGFloat(index) - scrollPosition, size: size, step: step)
            }
        }.frame(width: size.width, height: size.height)
    }

    private func wheelItem(_ game: AuroraGame, distance: CGFloat, size: CGSize, step: CGFloat) -> some View {
        let magnitude = abs(distance)
        let scale = max(0.55, 1 - magnitude * 0.2)
        let blur = min(4, max(0, magnitude - 0.65) * 1.5)
        let opacity = Double(max(0.05, 1 - magnitude * 0.29))
        let side = coverSide(size)
        let x = side / 2 - min(magnitude * magnitude * 16, size.width * 0.4)
        let y = size.height * 0.5 + distance * step
        return cover(game, size: size)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(distance) * 13))
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
            .position(x: x, y: y)
            .frame(width: size.width, height: size.height)
            .zIndex(10 - Double(magnitude))
    }

    private func coverSide(_ size: CGSize) -> CGFloat {
        min(126, size.width * 0.58, size.height * 0.5)
    }

    private func cover(_ game: AuroraGame, size: CGSize) -> some View {
        let side = coverSide(size)
        return AuroraArtwork(url: game.artworkURL, fit: true, revision: model.artworkRevision)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.purple.opacity(game.id == model.selectedGame?.id ? 1 : 0), lineWidth: 2))
            .allowsHitTesting(false)
    }
}

/// Keep navigation containers consistent with the app-wide orientation preference.
class GamesNavigationController: UINavigationController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        AppOrientation.current == .automatic ? (topViewController?.supportedInterfaceOrientations ?? .allButUpsideDown) : AppOrientation.current.mask
    }
    override var shouldAutorotate: Bool { topViewController?.shouldAutorotate ?? true }
}
