//
//  SettingsView.swift
//  Delta
//
//  Created by Caroline Moore on 3/31/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

import DeltaCore
import Harmony

private struct SettingsBadge: View
{
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
    }
}

struct SettingsView: View
{
    var isTab = false
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var inheritedColorScheme
    @SwiftUI.State private var category: SettingsCategory = .all

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 26, *) {
                    modernSettings
                } else {
                    Form {
                        ControlsSection()
                        EmulationSection()
                        OnlineMultiplayerSection()
                        DisplaySection()
                        ServicesSection()
                        MiscellaneousSection()
                        CreditsSection()
                        SupportSection()
                    }
                    .safeAreaPadding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTab {
                    if #available(iOS 26, *)
                    {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) {
                                // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                                SyncManager.shared.sync()
                                dismiss()
                            }
                        }
                    }
                    else
                    {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                // dismiss() skips presentationControllerDidDismiss, so explicitly sync on close.
                                SyncManager.shared.sync()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .toolbarColorScheme(isModern ? .dark : nil, for: .navigationBar)
        }
        .preferredColorScheme(isModern ? .dark : nil)
        .environment(\.colorScheme, isModern ? .dark : inheritedColorScheme)
    }

    private var isModern: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    @available(iOS 26, *)
    private var modernSettings: some View {
        GeometryReader { geometry in
            let sidebar = geometry.size.width >= 650 && !typeSize.isAccessibilitySize
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.09).ignoresSafeArea()
                if !reduceTransparency {
                    RadialGradient(colors: [.purple.opacity(0.24), .clear], center: .topLeading, startRadius: 0, endRadius: 550)
                        .ignoresSafeArea().allowsHitTesting(false)
                    RadialGradient(colors: [.teal.opacity(0.09), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 500)
                        .ignoresSafeArea().allowsHitTesting(false)
                }
                if sidebar {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("Delta", systemImage: "gamecontroller.fill")
                                .font(.title3.bold()).padding(.horizontal, 12)
                            GlassEffectContainer(spacing: 12) {
                                VStack(spacing: 8) {
                                    ForEach(SettingsCategory.allCases) { item in
                                        categoryButton(item, sidebar: true)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }.padding(16).frame(width: 190)
                        settingsForm
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            GlassEffectContainer(spacing: 12) {
                                HStack(spacing: 8) {
                                    ForEach(SettingsCategory.allCases) { item in
                                        categoryButton(item, sidebar: false)
                                    }
                                }.padding(.horizontal, 20).padding(.vertical, 10)
                            }
                        }
                        settingsForm
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.73, green: 0.52, blue: 1))
    }

    @available(iOS 26, *)
    private func categoryButton(_ item: SettingsCategory, sidebar: Bool) -> some View {
        Button { category = item } label: {
            Label(item.title, systemImage: item.symbol)
                .font(.subheadline.weight(category == item ? .semibold : .medium))
                .padding(.horizontal, 16).frame(minHeight: 44)
                .frame(maxWidth: sidebar ? .infinity : nil, alignment: .leading)
                .foregroundStyle(category == item ? .white : .white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(category == item ? .purple.opacity(0.3) : .clear).interactive(), in: .capsule)
        .accessibilityAddTraits(category == item ? .isSelected : [])
    }

    @available(iOS 26, *)
    private var settingsForm: some View {
        Form {
            Section {
                settingsHero
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            Group {
                if category == .all || category == .play {
                    ControlsSection()
                    EmulationSection()
                    OnlineMultiplayerSection()
                }
                if category == .all || category == .appearance { DisplaySection() }
                if category == .all || category == .accounts { ServicesSection() }
                if category == .all || category == .more {
                    MiscellaneousSection()
                    CreditsSection()
                    SupportSection()
                }
            }
            .listRowBackground(Color(red: 0.095, green: 0.105, blue: 0.16))
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            Section {
                Text("Delta \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .environment(\.colorScheme, .dark)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .listSectionSpacing(8)
        .id(category)
    }

    private var settingsHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: category == .all ? "gamecontroller.fill" : category.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(category == .all ? String(localized: "Make Delta yours") : category.title)
                        .font(.title2.bold()).foregroundStyle(.white)
                    Text(category.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(reduceTransparency ? 0.1 : 0.045), in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case all, play, appearance, accounts, more
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return String(localized: "Overview")
        case .play: return String(localized: "Play")
        case .appearance: return String(localized: "Appearance")
        case .accounts: return String(localized: "Accounts")
        case .more: return String(localized: "More")
        }
    }
    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .play: return "gamecontroller"
        case .appearance: return "paintpalette"
        case .accounts: return "person.crop.circle"
        case .more: return "ellipsis"
        }
    }
    var subtitle: String {
        switch self {
        case .all: return String(localized: "Your controls, your look, your way to play.")
        case .play: return String(localized: "Fine-tune controls, audio, video, and emulation.")
        case .appearance: return String(localized: "Give Delta a look of your own.")
        case .accounts: return String(localized: "Manage game syncing and achievements.")
        case .more: return String(localized: "Preferences, support, and the people behind Delta.")
        }
    }
}

// MARK: - Controls

private struct ControlsSection: View
{
    @SwiftUI.State
    private var gameControllerManager: ExternalGameControllerManager = .shared

    var body: some View {
        Section("Controls") {
            NavigationLink {
                ControllerSettingsView()
            } label: {
                SettingsRow(label: Text("Controllers"), systemImage: "gamecontroller", color: .purple) {
                    if !gameControllerManager.connectedControllers.isEmpty
                    {
                        Text("\(gameControllerManager.connectedControllers.count) Connected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            NavigationLink {
                SkinSettingsView()
            } label: {
                SettingsRow(label: Text("Skins"), systemImage: "paintpalette", color: .pink)
            }

            NavigationLink {
                TouchHapticsView()
            } label: {
                SettingsRow(label: Text("Touch & Haptics"), systemImage: "hand.tap", color: .red)
            }
        }
    }
}

// MARK: - Emulation

private struct EmulationSection: View
{
    var body: some View {
        Section("Emulation") {
            NavigationLink {
                AudioSettingsView()
            } label: {
                SettingsRow(label: Text("Audio"), systemImage: "speaker.wave.2", color: .green)
            }

            NavigationLink {
                VideoSettingsView()
            } label: {
                SettingsRow(label: Text("Video"), systemImage: "display", color: .teal)
            }

            NavigationLink {
                CoresListView()
            } label: {
                SettingsRow(label: Text("Cores"), systemImage: "cpu", color: .cyan)
            }
        }
    }
}

// MARK: - Online Multiplayer

private struct OnlineMultiplayerSection: View
{
    var body: some View {
        Section("Multiplayer") {
            NavigationLink {
                OnlineMultiplayerView()
            } label: {
                SettingsRow(label: Text("Online Multiplayer"), systemImage: "globe", color: .orange)
            }
        }
    }
}

// MARK: - Online Multiplayer Detail

struct OnlineMultiplayerView: View
{
    @SwiftUI.State
    private var preferredWFCServer: String? = Settings.preferredWFCServer

    @SwiftUI.State
    private var isConfirmingReset: Bool = false

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WFCServersView()
                } label: {
                    LabeledContent {
                        if let serverName = preferredServerName
                        {
                            Text(serverName)
                        }
                    } label: {
                        Text("WFC Server")
                    }
                }

                if preferredWFCServer != nil
                {
                    Button("Reset Online Settings", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .confirmationDialog("Are you sure you want to reset your online settings?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                        Button("Reset Online Settings", role: .destructive) {
                            WFCManager.shared.resetWFCConfiguration()
                        }
                    } message: {
                        Text("You may need to re-add any friend codes you’ve previously registered.")
                    }
                }
            } header: {
                Text("Nintendo DS")
            } footer: {
                Text("Choose the 3rd-party Nintendo WFC server Delta should use for online play in Nintendo DS games.")
            }
        }
        .navigationTitle("Online Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .preferredWFCServer else { return }

            preferredWFCServer = Settings.preferredWFCServer
        }
        .onAppear {
            preferredWFCServer = Settings.preferredWFCServer
        }
    }

    private var preferredServerName: String? {
        guard let preferredWFCServer else { return nil }

        if let servers = UserDefaults.standard.wfcServers, let knownServer = servers.first(where: { $0.dns == preferredWFCServer })
        {
            return knownServer.name
        }

        return preferredWFCServer
    }
}

// MARK: - Services

private struct ServicesSection: View
{
    @SwiftUI.State
    private var syncingServiceName: String? = Settings.syncingService?.localizedName
    
    @SwiftUI.State
    private var syncConflictsCount: Int = 0
    
    @SwiftUI.State
    private var isAccountConnected: Bool = SyncManager.shared.coordinator?.account != nil

    @SwiftUI.State
    private var retroAchievementsUsername: String? = Keychain.shared.retroAchievementsUsername

    var body: some View {
        Section("Accounts & Sync") {
            NavigationLink {
                SyncingServicesViewController.ViewRepresentable()
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("Delta Sync"), systemImage: "arrow.triangle.2.circlepath", color: .indigo) {
                    if let name = syncingServiceName {
                        Text(name).foregroundStyle(.secondary)
                    }
                }
            }

            if isAccountConnected
            {
                NavigationLink {
                    SyncStatusViewController.ViewRepresentable()
                        .ignoresSafeArea()
                } label: {
                    SettingsRow(label: Text("Sync Status"), systemImage: "checkmark.icloud", color: .indigo) {
                        if syncConflictsCount > 0
                        {
                            SettingsBadge(text: "\(syncConflictsCount) conflicts", color: .red)
                        }
                        else
                        {
                            SettingsBadge(text: "No conflicts", color: .green)
                        }
                    }
                }
            }

            NavigationLink {
                AchievementAccount()
            } label: {
                SettingsRow(label: Text("RetroAchievements"), systemImage: "medal", color: .indigo) {
                    if let username = retroAchievementsUsername {
                        Text(username).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Settings.didChangeNotification)) { notification in
            guard let name = notification.userInfo?[Settings.NotificationUserInfoKey.name] as? Settings.Name,
                  name == .syncingService else { return }
            
            syncingServiceName = Settings.syncingService?.localizedName
            isAccountConnected = SyncManager.shared.coordinator?.account != nil
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: SyncCoordinator.didFinishSyncingNotification).receive(on: DispatchQueue.main)) { _ in
            refreshSyncConflicts()
        }
        .onReceive(NotificationCenter.default.publisher(for: AchievementsManager.didFinishAuthenticatingNotification).receive(on: DispatchQueue.main)) { _ in
            retroAchievementsUsername = Keychain.shared.retroAchievementsUsername
        }
        .onAppear {
            refreshSyncConflicts()
        }
    }

    private func refreshSyncConflicts()
    {
        do {
            let records = try SyncManager.shared.recordController?.fetchConflictedRecords() ?? []
            syncConflictsCount = records.count
        } catch {
            Logger.main.error("Failed to refresh sync conflicts. \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - App Icon

private struct DisplaySection: View
{
    var body: some View {
        Section("Display") {
            NavigationLink {
                AltAppIconsViewController.ViewRepresentable()
                    .navigationBarTitleDisplayMode(.large)
                    .ignoresSafeArea()
            } label: {
                SettingsRow(label: Text("App Icon"), systemImage: "square.grid.2x2", color: .blue)
            }
        }
    }
}

// MARK: - Experimental, Minor, & Advanced

private struct MiscellaneousSection: View
{
    var body: some View {
        Section("Preferences") {
            NavigationLink {
                MinorSettingsView()
            } label: {
                SettingsRow(label: Text("Minor"), systemImage: "slider.horizontal.3", color: .gray)
            }

            NavigationLink {
                AdvancedSettingsView()
            } label: {
                SettingsRow(label: Text("Advanced"), systemImage: "gearshape", color: .gray)
            }
            
            NavigationLink {
                ExperimentalFeaturesView()
            } label: {
                SettingsRow(label: Text("Experimental"), systemImage: "flask", color: .gray) {
                    SettingsBadge(text: "Patrons")
                }
            }
        }
    }
}

// MARK: - Credits

private struct CreditsSection: View
{
    var body: some View {
        Section("Credits") {
            NavigationLink {
                ContributorsView()
            } label: {
                Text("Contributors")
            }

            NavigationLink {
                LicensesViewController.ViewRepresentable()
                    .ignoresSafeArea()
            } label: {
                Text("Software Licenses")
            }
        }
    }
}

// MARK: - Support

private struct SupportSection: View
{
    @Environment(\.openURL)
    var openURL
    
    @SwiftUI.State
    private var showMailError = false

    var body: some View {
        Section {
            Button("Contact Us") {
                // TODO: support attachments
                let email = "support@altstore.io"
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                let subject = "Delta \(version) Feedback"
                let urlString = "mailto:\(email)?subject=\(subject)"
                
                if let url = URL(string: urlString)
                {
                    openURL(url) { success in
                        if !success { showMailError = true }
                    }
                }
            }
            .alert("Cannot Send Mail", isPresented: $showMailError) {}
            
            Link("Privacy Policy", destination: URL(string: "https://altstore.io/privacy")!)
            
            Link("Terms of Use", destination: URL(string: "https://altstore.io/terms")!)
        } header: {
            Text("Support")
        } footer: {
            RepresentedFooterView()
                .containerRelativeFrame(.horizontal)
        }
    }
}

// MARK: - Footer

private struct RepresentedFooterView: UIViewRepresentable
{
    func makeUIView(context: Context) -> FollowUsFooterView
    {
        let view = FollowUsFooterView(prefersFullColorIcons: false)
        view.stackView.spacing = 20
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.directionalLayoutMargins.top = 8
        view.stackView.directionalLayoutMargins.bottom = 20
        return view
    }

    func updateUIView(_ uiView: FollowUsFooterView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FollowUsFooterView, context: Context) -> CGSize?
    {
        guard let width = proposal.width ?? uiView.window?.bounds.width else { return nil }

        return uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
    }
}

#Preview {
    SettingsView()
}
