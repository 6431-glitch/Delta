import Foundation
import CoreData
import DeltaCore

/// Runtime metadata and artwork extraction are isolated from import persistence.
enum ContentImportAdapter
{
    static func inspect(_ url: URL, descriptorURL: URL? = nil) throws -> ImportInspection
    {
        let inspector = JavaContentInspector(descriptorURL: descriptorURL)
        let coordinator = ImportCoordinator(registry: BuiltInSystems.registry,
            inspectors: ["page.ducnguyen.delta.j2me": inspector],
            isReadable: { FileManager.default.isReadableFile(atPath: $0.path) })
        return try coordinator.inspect(url)
    }
    static func validateReplacement(_ url: URL, systemIdentifier: String) throws
    {
        guard BuiltInSystems.registry.system(fileExtension: url.pathExtension)?.identifier == systemIdentifier else {
            throw NSError(domain: "GameReplacement", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "Choose a raw game file for the same platform. ZIP archives are not supported for replacement.")])
        }
        if BuiltInSystems.registry.system(identifier: systemIdentifier)?.runtime == .javaME {
            guard let metadata = J2MEJARMetadata.read(from: url.path), let name = metadata.className,
                  J2MEZIPReader.extractEntry(zipPath: url.path, entryName: name.replacingOccurrences(of: ".", with: "/") + ".class") != nil else {
                throw NSError(domain: "GameReplacement", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "The selected JAR does not contain a valid MIDlet.")])
            }
        }
    }

    static func updateReplacementConfiguration(_ game: Game, source: URL)
    {
        guard System(gameType: game.type)?.descriptor.runtime == .javaME else { return }
        var settings = game.gameSettings as? [String: Any] ?? [:]
        settings.removeValue(forKey: "j2me.descriptor")
        settings["j2me.originalFilename"] = source.lastPathComponent
        game.gameSettings = settings as NSDictionary
    }

    struct SidecarResult {
        var identifiers = Set<String>()
        var invalidURLs = Set<URL>()
    }

    static func attachSidecars(in urls: Set<URL>, context: NSManagedObjectContext) -> SidecarResult
    {
        var result = SidecarResult()
        let descriptorURLs = urls.filter { $0.pathExtension.lowercased() == "jad" }
        for descriptorURL in descriptorURLs {
            let stem = descriptorURL.deletingPathExtension().lastPathComponent.lowercased()
            let matchingJars = urls.filter { $0.pathExtension.lowercased() == "jar" && $0.deletingPathExtension().lastPathComponent.lowercased() == stem }
            if matchingJars.isEmpty {
                let request: NSFetchRequest<Game> = Game.fetchRequest()
                request.predicate = NSPredicate(format: "type == %@", GameType.j2me.rawValue)
                let matches = ((try? context.fetch(request)) ?? []).filter {
                    let settings = $0.gameSettings as? [String: Any] ?? [:]
                    return (settings["j2me.originalFilename"] as? String).map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.lowercased() == stem } ?? false
                }
                if matches.count == 1, let game = matches.first {
                    var settings = game.gameSettings as? [String: Any] ?? [:]
                    settings["j2me.descriptor"] = J2MEScreenProfile.descriptorAttributes(at: descriptorURL)
                    game.gameSettings = settings as NSDictionary
                    result.identifiers.insert(game.identifier)
                } else { result.invalidURLs.insert(descriptorURL) }
            } else if matchingJars.count != 1 { result.invalidURLs.insert(descriptorURL) }
        }
        return result
    }

    static func reuseExisting(identifier: String, source url: URL, descriptors descriptorURLs: Set<URL>, context: NSManagedObjectContext) -> Game?
    {
        guard BuiltInSystems.registry.system(fileExtension: url.pathExtension)?.runtime == .javaME else { return nil }
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "identifier == %@", identifier)
        guard let existing = try? context.fetch(request).first else { return nil }
        let paired = descriptorURLs.filter { $0.deletingPathExtension().lastPathComponent.lowercased() == url.deletingPathExtension().lastPathComponent.lowercased() }
        if paired.count == 1, let descriptor = paired.first {
            var settings = existing.gameSettings as? [String: Any] ?? [:]
            settings["j2me.descriptor"] = J2MEScreenProfile.descriptorAttributes(at: descriptor)
            existing.gameSettings = settings as NSDictionary
        }
        if url.standardizedFileURL != existing.fileURL.standardizedFileURL { try? FileManager.default.removeItem(at: url) }
        return existing
    }

}

private struct JavaContentInspector: GameContentInspector
{
    let descriptorURL: URL?
    func inspect(_ url: URL) throws -> ImportInspection
    {
        guard let metadata = J2MEJARMetadata.read(from: url.path), metadata.className != nil else { throw ImportCoordinator.Failure.invalidContent }
        var settings: [String: Any] = ["j2me.originalFilename": url.lastPathComponent]
        if let descriptorURL { settings["j2me.descriptor"] = J2MEScreenProfile.descriptorAttributes(at: descriptorURL) }
        return ImportInspection(displayName: metadata.midletName, artworkData: metadata.readIcon(from: url.path)?.pngData(),
            configurationData: try JSONSerialization.data(withJSONObject: settings, options: [.sortedKeys]))
    }
}
