//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import DeltaCore

import SNESDeltaCore
import GBADeltaCore
import GBCDeltaCore
import NESDeltaCore
import N64DeltaCore
import MelonDSDeltaCore
import GPGXDeltaCore

enum System: String, CaseIterable
{
    case nes
    case genesis
    case snes
    case n64
    case gbc
    case gba
    case ds
    case j2me
    
    static var registeredSystems: [System] {
        let systems = System.allCases.filter { Delta.registeredCores.keys.contains($0.gameType) }
        return systems
    }
    
    static var coreSystems: [System] { allCases.filter { $0.descriptor.runtime == .deltaCore } }

    static var allCores: [DeltaCoreProtocol] {
        return [NES.core, SNES.core, N64.core, GBC.core, GBA.core, MelonDS.core, GPGX.core]
    }
}

extension System
{
    var descriptor: SystemDescriptor {
        // Every legacy enum case corresponds to a validated built-in descriptor.
        return BuiltInSystems.descriptors.first { $0.preferenceKey == self.rawValue }!
    }

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
        switch self
        {
        case .nes: return NES.core
        case .snes: return SNES.core
        case .n64: return N64.core
        case .gbc: return GBC.core
        case .gba: return GBA.core
        case .ds: return Settings.preferredCore(for: .ds) ?? MelonDS.core
        case .j2me: return nil
        case .genesis: return GPGX.core
        }
    }
    
    var gameType: DeltaCore.GameType { GameType(rawValue: descriptor.identifier) }

    init?(gameType: DeltaCore.GameType)
    {
        guard let descriptor = BuiltInSystems.registry.system(identifier: gameType.rawValue),
              let system = System(rawValue: descriptor.preferenceKey) else { return nil }
        self = system
    }

}

extension DeltaCore.GameType
{
    static let j2me = GameType(rawValue: "page.ducnguyen.delta.j2me")

    init?(fileExtension: String)
    {
        guard let system = BuiltInSystems.registry.system(fileExtension: fileExtension) else { return nil }
        self.init(rawValue: system.identifier)
    }
}
