import UIKit
import CoreData
import DeltaApplication
import DeltaCore

/// One interactive transfer at a time; UI owns confirmation and temporary-package lifetime.
@MainActor enum GameTransferCoordinator {
    static let fileExtension = "deltatransfer"
    private static var busy = false
    private static var deferredIncomingCleanup = Set<URL>()

    static func cleanInterruptedTransfers() {
        let abandoned = GameTransferTemporaryFiles.interruptedWorkspaces()
        DispatchQueue.global(qos: .utility).async {
            for directory in abandoned { GameTransferTemporaryFiles.discardWorkspace(directory) }
        }
    }

    private static func finishOperation(incoming: [URL] = []) {
        busy = false
        deferredIncomingCleanup.formUnion(incoming)
        let copies = deferredIncomingCleanup
        deferredIncomingCleanup.removeAll()
        for url in copies { GameTransferTemporaryFiles.discardIncomingCopy(url) }
    }

    static func export(_ game: Game, from presenter: UIViewController, sourceView: UIView?) {
        guard !busy else { show(GameTransferError.busy, present: { presenter.present($0, animated: true) }); return }
        busy = true
        Task {
            defer { finishOperation() }
            do {
                let snapshot = try GameTransferArchive.snapshot(game)
                let identifiers = Set(snapshot.manifest.games.map(\.identifier))
                EmulationServices.transferringGameIdentifiers.formUnion(identifiers)
                defer { EmulationServices.transferringGameIdentifiers.subtract(identifiers) }
                let url = try await work { try GameTransferArchive.create(snapshot) }
                let lifetime = GameTransferExportLifetime(directory: url.deletingLastPathComponent())
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = sourceView ?? presenter.view
                share.popoverPresentationController?.sourceRect = sourceView?.bounds ?? CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
                share.completionWithItemsHandler = { _, _, _, _ in lifetime.finish() }
                presenter.present(share, animated: true)
            } catch { show(error, present: { presenter.present($0, animated: true) }) }
        }
    }

    static func exportLibrary(from presenter: UIViewController, sourceView: UIView?) {
        guard !busy else { show(GameTransferError.busy, present: { presenter.present($0, animated: true) }); return }
        busy = true
        Task {
            defer { finishOperation() }
            do {
                let request: NSFetchRequest<Game> = Game.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.name, ascending: true)]
                let games = try DatabaseManager.shared.viewContext.fetch(request).filter { CoreStorageAdapter.firmware($0.identifier) == nil }
                let snapshot = try GameTransferArchive.snapshot(games)
                let identifiers = Set(snapshot.manifest.games.map(\.identifier))
                EmulationServices.transferringGameIdentifiers.formUnion(identifiers)
                defer { EmulationServices.transferringGameIdentifiers.subtract(identifiers) }
                let url = try await work { try GameTransferArchive.create(snapshot) }
                let lifetime = GameTransferExportLifetime(directory: url.deletingLastPathComponent())
                let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = sourceView ?? presenter.view
                share.popoverPresentationController?.sourceRect = sourceView?.bounds ?? CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
                share.completionWithItemsHandler = { _, _, _, _ in lifetime.finish() }
                presenter.present(share, animated: true)
            } catch { show(error, present: { presenter.present($0, animated: true) }) }
        }
    }

    static func receive(_ urls: [URL], present: @escaping (UIAlertController) -> Void) {
        guard !urls.isEmpty else { return }
        guard !busy else {
            deferredIncomingCleanup.formUnion(urls)
            show(GameTransferError.busy, present: present)
            return
        }
        busy = true
        Task {
            defer { finishOperation(incoming: urls) }
            for url in urls {
                do {
                    let prepared = try await work { try GameTransferArchive.prepare(url) }
                    defer { GameTransferTemporaryFiles.discardWorkspace(prepared.directory) }
                    try checkInactive(prepared.manifest)
                    var identifiers = Set(prepared.manifest.games.map(\.identifier))
                    EmulationServices.transferringGameIdentifiers.formUnion(identifiers)
                    defer { EmulationServices.transferringGameIdentifiers.subtract(identifiers) }
                    let existing = try prepared.manifest.games.compactMap {
                        try GameTransferArchive.find(Game.self, id: $0.identifier, context: DatabaseManager.shared.viewContext)
                    }
                    if !existing.isEmpty {
                        let confirmed = await confirm(present: present)
                        guard confirmed else { continue }
                        try checkInactive(prepared.manifest)
                        // Keep complete recovery packages in Documents, beyond temporary share-sheet cleanup.
                        var backedUp = Set<String>()
                        for game in existing where !backedUp.contains(game.identifier) {
                            let snapshot = try GameTransferArchive.snapshot(game)
                            let recoveryIdentifiers = Set(snapshot.manifest.games.map(\.identifier))
                            identifiers.formUnion(recoveryIdentifiers)
                            EmulationServices.transferringGameIdentifiers.formUnion(recoveryIdentifiers)
                            let recovery = try await work { try GameTransferArchive.create(snapshot) }
                            defer { GameTransferTemporaryFiles.discardWorkspace(recovery.deletingLastPathComponent()) }
                            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("Transfers/Recovery/" + UUID().uuidString, isDirectory: true)
                            do {
                                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                                try FileManager.default.moveItem(at: recovery, to: directory.appendingPathComponent(recovery.lastPathComponent))
                            } catch {
                                try? FileManager.default.removeItem(at: directory)
                                throw error
                            }
                            backedUp.formUnion(snapshot.manifest.games.map(\.identifier))
                        }
                    }
                    try checkInactive(prepared.manifest)
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        GameTransferArchive.install(prepared) { continuation.resume(with: $0) }
                    }
                } catch {
                    let failure = error as NSError
                    Logger.transfer.error("Transfer receive failed: domain=\(failure.domain, privacy: .public), code=\(failure.code, privacy: .public)")
                    show(error, present: present)
                    return
                }
            }
        }
    }

    private static func checkInactive(_ manifest: GameTransferManifest) throws {
        guard !manifest.games.contains(where: {
            EmulationServices.sessions.session(gameIdentifier: $0.identifier) != nil ||
            ($0.gameType == GameType.j2me.rawValue && EmulationServices.isJavaActive)
        }) else { throw GameTransferError.gameInUse }
    }
    private static func confirm(present: (UIAlertController) -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: String(localized: "Restore Transfer?"),
                message: String(localized: "Some games are already in your library. Imported settings and matching saves will replace the current versions. Additional local saves are kept. Recovery transfers of the current games will be saved in Documents/Transfers/Recovery."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in continuation.resume(returning: false) })
            alert.addAction(UIAlertAction(title: String(localized: "Restore"), style: .default) { _ in continuation.resume(returning: true) })
            present(alert)
        }
    }
    private static func show(_ error: Error, present: (UIAlertController) -> Void) {
        present(UIAlertController(title: String(localized: "Could Not Transfer Game"), error: error))
    }
    static func work<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try body()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
