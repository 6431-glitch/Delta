//
//  CoresListView.swift
//  Delta
//
//  Created by Caroline Moore on 3/30/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct CoresListView: View
{
    var body: some View {
        Form {
            ForEach(System.registeredSystems, id: \.self) { system in
                NavigationLink(destination: coreSettingsDestination(for: system)) {
                    LabeledContent(system.localizedName) {
                        Text(coreName(for: system))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .tint(.accentColor)
        .navigationTitle("Cores")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func coreName(for system: System) -> String
    {
        let core = Settings.preferredCore(for: system.gameType) ?? system.deltaCore
        return core?.metadata?.name.value ?? core?.name ?? system.localizedName
    }
    
    @ViewBuilder
    private func coreSettingsDestination(for system: System) -> some View
    {
        let destinations: [System: () -> AnyView] = [
            .nes: { AnyView(NESCoreSettingsView()) },
            .genesis: { AnyView(GenesisCoreSettingsView()) },
            .snes: { AnyView(SNESCoreSettingsView()) },
            .n64: { AnyView(N64CoreSettingsView()) },
            .gbc: { AnyView(GBCCoreSettingsView()) },
            .gba: { AnyView(GBACoreSettingsView()) },
            .ds: { AnyView(MelonDSCoreSettingsView().ignoresSafeArea()) }
        ]
        if let destination = destinations[system] { destination() }
        else {
            Form {
                if let core = system.deltaCore {
                    LabeledContent("Core", value: core.name)
                    if let version = core.version { LabeledContent("Version", value: version) }
                } else { Text("No core is available for this system.") }
            }
            .navigationTitle(system.localizedName)
        }
    }
}
