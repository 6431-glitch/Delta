//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaDomain
import DeltaCore

import SNESDeltaCore
import GBADeltaCore
import GBCDeltaCore
import NESDeltaCore
import N64DeltaCore
import MelonDSDeltaCore
import GPGXDeltaCore

/// A descriptor-backed compatibility facade. Adding a system no longer adds enum cases.
struct System: RawRepresentable, CaseIterable, Hashable, CustomStringConvertible
{
    // Composition: extend this registry alongside a core factory/registration and its resources.
    static let registry = BuiltInSystems.registry
    let descriptor: SystemDescriptor
    var rawValue: String { descriptor.preferenceKey }
    var description: String { rawValue }

    private init(descriptor: SystemDescriptor) { self.descriptor = descriptor }
    init?(rawValue: String)
    {
        guard let descriptor = Self.registry.systems.first(where: { $0.preferenceKey == rawValue }) else { return nil }
        self.init(descriptor: descriptor)
    }
    static let nes = System(rawValue: "nes")!
    static let genesis = System(rawValue: "genesis")!
    static let snes = System(rawValue: "snes")!
    static let n64 = System(rawValue: "n64")!
    static let gbc = System(rawValue: "gbc")!
    static let gba = System(rawValue: "gba")!
    static let ds = System(rawValue: "ds")!
    static let j2me = System(rawValue: "j2me")!

    static var allCases: [System] { registry.systems.map { System(descriptor: $0) } }
    static var registeredSystems: [System] { allCases.filter { Delta.registeredCores.keys.contains($0.gameType) } }
    static var coreSystems: [System] { allCases.filter { $0.descriptor.runtime == .deltaCore } }
    static var allCores: [DeltaCoreProtocol] {
        let builtIn: [DeltaCoreProtocol] = [NES.core, SNES.core, N64.core, GBC.core, GBA.core, MelonDS.core, GPGX.core]
        let extra = Delta.registeredCores.values.filter { core in !builtIn.contains { $0.identifier == core.identifier } }
        return builtIn + extra.sorted { $0.identifier < $1.identifier }
    }
    static func == (lhs: System, rhs: System) -> Bool { lhs.descriptor.identifier == rhs.descriptor.identifier }
    func hash(into hasher: inout Hasher) { hasher.combine(descriptor.identifier) }
}

extension System
{
    var localizedName: String { NSLocalizedString(descriptor.name, comment: "") }
    var localizedShortName: String { NSLocalizedString(descriptor.shortName, comment: "") }
    var localizedDisplayName: String { NSLocalizedString(descriptor.displayName, comment: "") }
    var year: Int { descriptor.year }

    var controllerIcon: UIImage {
        let fallback = UIImage(systemName: "gamecontroller.fill")!
        let names: [System: String] = [.nes: "NES", .snes: "SNES", .n64: "N64", .gbc: "GBC", .gba: "GBA", .ds: "DS", .genesis: "Genesis"]
        if self == .j2me { return UIImage(systemName: "candybarphone") ?? fallback }
        return names[self].flatMap { UIImage(named: $0) } ?? fallback
    }
}

extension System
{
    var deltaCore: DeltaCoreProtocol? {
        guard descriptor.runtime == .deltaCore else { return nil }
        if self == .ds { return Settings.preferredCore(for: .ds) ?? MelonDS.core }
        let providers: [String: () -> DeltaCoreProtocol] = [
            "nes": { NES.core }, "snes": { SNES.core }, "n64": { N64.core },
            "gbc": { GBC.core }, "gba": { GBA.core }, "genesis": { GPGX.core }
        ]
        return providers[rawValue]?() ?? Delta.core(for: gameType)
    }
    
    var gameType: DeltaCore.GameType { GameType(rawValue: descriptor.identifier) }

    init?(gameType: DeltaCore.GameType)
    {
        guard let descriptor = Self.registry.system(identifier: gameType.rawValue) else { return nil }
        self.init(descriptor: descriptor)
    }

}

extension DeltaCore.GameType
{
    static let j2me = GameType(rawValue: "page.ducnguyen.delta.j2me")

    init?(fileExtension: String)
    {
        guard let system = System.registry.system(fileExtension: fileExtension) else { return nil }
        self.init(rawValue: system.identifier)
    }
}
