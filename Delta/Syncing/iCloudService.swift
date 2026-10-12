import CloudKit
import CoreData
import Harmony
import Roxas

/// A private CloudKit backend for Harmony. The local database and conflict UI
/// remain owned by Harmony; CloudKit stores immutable revisions and current heads.
final class iCloudService: Harmony.Service {
    static let shared = iCloudService()
    let localizedName = "iCloud"
    let identifier = "page.ducnguyen.Delta.iCloud"
    static let containerIdentifier = "iCloud.page.ducnguyen.Delta"
    private lazy var container = CKContainer(identifier: Self.containerIdentifier)
    private var database: CKDatabase { container.privateCloudDatabase }
    private let zoneID = CKRecordZone.ID(zoneName: "DeltaSync", ownerName: CKCurrentUserDefaultName)
    private let accountKey = "iCloudSyncAccountID"

    private typealias Revision = iCloudSyncState.Revision
    private typealias Token = iCloudSyncState.Token
    private enum BackendError: LocalizedError {
        case unavailable, changedAccount, malformed
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Sign in to iCloud in Settings to use iCloud sync."
            case .changedAccount: return "Your iCloud account changed. Reconnect iCloud sync before continuing."
            case .malformed: return "The iCloud sync data is incomplete or invalid."
            }
        }
    }

    func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void) {
        authenticate(interactive: true, completionHandler: completionHandler)
    }
    func authenticateInBackground(completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void) {
        authenticate(interactive: false, completionHandler: completionHandler)
    }
    private func authenticate(interactive: Bool, completionHandler: @escaping (Result<Account, AuthenticationError>) -> Void) {
        Task {
            do {
                if !interactive && UserDefaults.standard.string(forKey: accountKey) == nil { throw AuthenticationError.noSavedCredentials }
                let user = try await currentUser()
                if let previous = UserDefaults.standard.string(forKey: accountKey), previous != user {
                    throw BackendError.changedAccount
                }
                _ = try await database.save(CKRecordZone(zoneID: zoneID))
                UserDefaults.standard.set(user, forKey: accountKey)
                completionHandler(.success(Account(name: "iCloud", emailAddress: nil)))
            } catch { completionHandler(.failure(AuthenticationError(mapError(error)))) }
        }
    }
    func deauthenticate(completionHandler: @escaping (Result<Void, DeauthenticationError>) -> Void) {
        // Disconnect only this app; never sign out the device or delete cloud data.
        UserDefaults.standard.removeObject(forKey: accountKey)
        completionHandler(.success(()))
    }
    private func currentUser() async throws -> String {
        guard try await container.accountStatus() == .available else { throw BackendError.unavailable }
        return try await container.userRecordID().recordName
    }
    private func checkAccount() async throws -> String {
        try Task.checkCancellation()
        guard let expected = UserDefaults.standard.string(forKey: accountKey) else { throw AuthenticationError.notAuthenticated }
        guard try await currentUser() == expected else { throw BackendError.changedAccount }
        return expected
    }
    private func run<T, E: Swift.Error>(_ wrap: @escaping (Swift.Error) -> E, context: NSManagedObjectContext? = nil, completion: @escaping (Result<T, E>) -> Void, body: @escaping () async throws -> T) -> Progress {
        let progress = Progress(totalUnitCount: 1)
        let task = Task {
            do {
                _ = try await checkAccount()
                let value = try await body()
                progress.completedUnitCount = 1
                iCloudSyncState.deliver(.success(value), on: context, completion: completion)
            } catch {
                iCloudSyncState.deliver(.failure(wrap(mapError(error))), on: context, completion: completion)
            }
        }
        progress.cancellationHandler = { task.cancel() }
        return progress
    }
    private func mapError(_ error: Swift.Error) -> Swift.Error {
        if error is CancellationError { return GeneralError.cancelled }
        guard let error = error as? CKError else { return error }
        if error.code == .partialFailure, let errors = error.partialErrorsByItemID {
            // BatchRequestFailed is collateral; report the actual atomic failure.
            if let cause = errors.values.first(where: { ($0 as? CKError)?.code != .batchRequestFailed }) { return mapError(cause) }
        }
        switch error.code {
        case .unknownItem: return ServiceError.itemDoesNotExist
        case .notAuthenticated: return AuthenticationError.notAuthenticated
        case .quotaExceeded: return ServiceError.insufficentSpace
        case .networkUnavailable, .networkFailure: return ServiceError.connectionFailed(URLError(.notConnectedToInternet))
        case .operationCancelled: return GeneralError.cancelled
        default: return error
        }
    }
    private func recordFailure(_ record: AnyRecord, _ error: Swift.Error) -> RecordError {
        let error = mapError(error)
        if (error as? CKError)?.code == .serverRecordChanged { return .conflicted(record) }
        return RecordError(record, error)
    }
    private func id(_ name: String) -> CKRecord.ID { CKRecord.ID(recordName: name, zoneID: zoneID) }
    private func headName(kind: String, components: [String]) throws -> String {
        try iCloudSyncState.identifier(kind: kind, components: components)
    }
    private func metadataData(_ metadata: [HarmonyMetadataKey: Any]) throws -> Data {
        let values = metadata.reduce(into: [String: String]()) { result, entry in
            if let value = entry.value as? String { result[entry.key.rawValue] = value }
        }
        return try JSONEncoder().encode(values)
    }
    private func metadata(_ head: CKRecord) throws -> [HarmonyMetadataKey: String] {
        guard let data = head["metadata"] as? Data else { throw BackendError.malformed }
        return try JSONDecoder().decode([String: String].self, from: data).reduce(into: [:]) { $0[HarmonyMetadataKey($1.key)] = $1.value }
    }
    private func revisions(_ head: CKRecord) throws -> [Revision] {
        guard let data = head["revisions"] as? Data else { throw BackendError.malformed }
        return try JSONDecoder().decode([Revision].self, from: data)
    }
    private func fetchHead(_ name: String, createType: String? = nil) async throws -> CKRecord {
        do { return try await database.record(for: id(name)) }
        catch let error as CKError where error.code == .unknownItem {
            guard let type = createType else { throw error }
            return CKRecord(recordType: type, recordID: id(name))
        }
    }
    private func save(_ records: [CKRecord], deleting: [CKRecord.ID] = []) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: deleting)
            operation.isAtomic = true
            operation.savePolicy = .ifServerRecordUnchanged
            operation.modifyRecordsResultBlock = { continuation.resume(with: $0) }
            database.add(operation)
        }
    }
    private func uploadRevision(head: CKRecord, payload: URL, metadata: Data, date: Date) async throws -> CKRecord {
        let revision = Revision(identifier: "revision-" + UUID().uuidString, date: date)
        let body = CKRecord(recordType: "DeltaRevision", recordID: id(revision.identifier))
        var records = [body, head]
        let size = try payload.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let chunkDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: chunkDirectory) }
        if size > 16 * 1024 * 1024 {
            try FileManager.default.createDirectory(at: chunkDirectory, withIntermediateDirectories: true)
            let urls = try iCloudSyncState.split(payload, into: chunkDirectory)
            var names: [String] = []
            for (index, url) in urls.enumerated() {
                let name = revision.identifier + "-chunk-" + String(index)
                let chunk = CKRecord(recordType: "DeltaChunk", recordID: id(name))
                chunk["payload"] = CKAsset(fileURL: url)
                chunk["parent"] = CKRecord.Reference(recordID: body.recordID, action: .deleteSelf)
                records.append(chunk)
                names.append(name)
            }
            // Supported Delta ROMs fit well within CloudKit's 200-record batch.
            guard records.count <= 200 else { throw ServiceError.invalidResponse }
            body["chunks"] = names as CKRecordValue
        } else { body["payload"] = CKAsset(fileURL: payload) }
        body["size"] = NSNumber(value: size)
        body["sha1"] = try RSTHasher.sha1HashOfFile(at: payload) as CKRecordValue
        body["parent"] = CKRecord.Reference(recordID: head.recordID, action: .deleteSelf)
        var history = head["revisions"] == nil ? [] : try revisions(head)
        history.insert(revision, at: 0)
        head["revisions"] = try JSONEncoder().encode(history) as CKRecordValue
        head["metadata"] = metadata as CKRecordValue
        try await save(records)
        return head
    }
    private func downloadPayload(headName: String, version: String?) async throws -> URL {
        let head = try await fetchHead(headName)
        let history = try revisions(head)
        let revision: Revision
        do { revision = try iCloudSyncState.revision(in: history, requested: version) }
        catch { throw ServiceError.itemDoesNotExist }
        let body = try await database.record(for: id(revision.identifier))
        guard (body["parent"] as? CKRecord.Reference)?.recordID == head.recordID else { throw BackendError.malformed }
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            if let source = (body["payload"] as? CKAsset)?.fileURL {
                try FileManager.default.copyItem(at: source, to: target)
            } else if let names = body["chunks"] as? [String], !names.isEmpty {
                var sources: [URL] = []
                for name in names {
                    try Task.checkCancellation()
                    let chunk = try await database.record(for: id(name))
                    guard (chunk["parent"] as? CKRecord.Reference)?.recordID == body.recordID,
                          let source = (chunk["payload"] as? CKAsset)?.fileURL else { throw BackendError.malformed }
                    sources.append(source)
                }
                try iCloudSyncState.assemble(sources, at: target)
            } else { throw BackendError.malformed }
            guard try target.resourceValues(forKeys: [.fileSizeKey]).fileSize == (body["size"] as? NSNumber)?.intValue,
                  try RSTHasher.sha1HashOfFile(at: target) == body["sha1"] as? String else { throw BackendError.malformed }
            return target
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    func fetchAllRemoteRecords(context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Data), FetchError>) -> Void) -> Progress {
        fetchChanges(token: nil, context: context) { result in
            completionHandler(result.map { ($0.0, $0.2) })
        }
    }
    func fetchChangedRemoteRecords(changeToken: Data, context: NSManagedObjectContext, completionHandler: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>) -> Void) -> Progress {
        fetchChanges(token: changeToken, context: context, completion: completionHandler)
    }
    private func fetchChanges(token: Data?, context: NSManagedObjectContext, completion: @escaping (Result<(Set<RemoteRecord>, Set<String>, Data), FetchError>) -> Void) -> Progress {
        run({ FetchError($0) }, context: context, completion: completion) {
            let account = try await self.checkAccount()
            var previous: CKServerChangeToken?
            if let token {
                do {
                    let envelope = try JSONDecoder().decode(Token.self, from: token)
                    guard envelope.account == account else { throw BackendError.changedAccount }
                    previous = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: envelope.token(for: account))
                    guard previous != nil else { throw FetchError.invalidChangeToken(token) }
                } catch BackendError.changedAccount { throw BackendError.changedAccount }
                catch { previous = nil }
            }
            var changes: ([CKRecord], Set<String>, CKServerChangeToken)
            var fullRefresh = previous == nil
            do { changes = try await self.zoneChanges(since: previous) }
            catch let error as CKError where error.code == .changeTokenExpired || error.code == .zoneNotFound || error.code == .userDeletedZone {
                if error.code != .changeTokenExpired { _ = try await self.database.save(CKRecordZone(zoneID: self.zoneID)) }
                changes = try await self.zoneChanges(since: nil)
                fullRefresh = true
            }
            let encoded = try NSKeyedArchiver.archivedData(withRootObject: changes.2, requiringSecureCoding: true)
            let next = try JSONEncoder().encode(Token(account: account, serverToken: encoded))
            let snapshots = try changes.0.map { head -> (String, Revision, [HarmonyMetadataKey: String]) in
                guard let revision = try self.revisions(head).first else { throw BackendError.malformed }
                return (head.recordID.recordName, revision, try self.metadata(head))
            }
            let deleted = changes.1
            let reset = fullRefresh && token != nil
            return try await context.perform {
                var inserted = Set<RemoteRecord>()
                do {
                    var deletedIDs = deleted
                    if reset {
                        let known = try context.fetch(NSFetchRequest<RemoteRecord>(entityName: "RemoteRecord"))
                        deletedIDs.formUnion(Set(known.map(\.identifier)).subtracting(snapshots.map { $0.0 }))
                    }
                    for (name, revision, metadata) in snapshots {
                        inserted.insert(try RemoteRecord(identifier: name, versionIdentifier: revision.identifier, versionDate: revision.date, metadata: metadata, status: token == nil ? .normal : .updated, context: context))
                    }
                    return (inserted, deletedIDs, next)
                } catch {
                    inserted.forEach { context.delete($0) }
                    throw error
                }
            }
        }
    }
    private func zoneChanges(since token: CKServerChangeToken?) async throws -> ([CKRecord], Set<String>, CKServerChangeToken) {
        try await withCheckedThrowingContinuation { continuation in
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = token
            configuration.desiredKeys = ["metadata", "revisions"]
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: configuration])
            operation.fetchAllChanges = true
            var heads: [String: CKRecord] = [:]
            var deletions = Set<String>()
            var latest: CKServerChangeToken?
            var zoneError: Swift.Error?
            operation.recordWasChangedBlock = { recordID, result in
                switch result {
                case .success(let record) where record.recordType == "DeltaRecord":
                    heads[recordID.recordName] = record
                    deletions.remove(recordID.recordName)
                case .failure(let error): zoneError = error
                default: break
                }
            }
            operation.recordWithIDWasDeletedBlock = { recordID, type in
                if type == "DeltaRecord" { heads.removeValue(forKey: recordID.recordName); deletions.insert(recordID.recordName) }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let value): latest = value.serverChangeToken
                case .failure(let error): zoneError = error
                }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                do {
                    try result.get()
                    if let error = zoneError { throw error }
                    guard let latest else { throw BackendError.malformed }
                    continuation.resume(returning: (Array(heads.values), deletions, latest))
                } catch { continuation.resume(throwing: error) }
            }
            database.add(operation)
        }
    }

    func upload(_ record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteRecord, RecordError>) -> Void) -> Progress {
        run({ self.recordFailure(record, $0) }, context: context, completion: completionHandler) {
            let snapshot = try record.perform { managed -> (Data, Date, String?, String?) in
                guard let local = managed.localRecord else { throw ValidationError.nilLocalRecord }
                return (try JSONEncoder().encode(local), local.modificationDate, managed.remoteRecord?.identifier, managed.remoteRecord?.version.identifier)
            }
            let name = try snapshot.2 ?? self.headName(kind: "record", components: [String(describing: record.recordID)])
            let head = try await self.fetchHead(name, createType: "DeltaRecord")
            if head["revisions"] != nil {
                guard let expected = snapshot.3, try self.revisions(head).first?.identifier == expected else { throw RecordError.conflicted(record) }
            }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try snapshot.0.write(to: temporary, options: .atomic)
            defer { try? FileManager.default.removeItem(at: temporary) }
            do { _ = try await self.uploadRevision(head: head, payload: temporary, metadata: self.metadataData(metadata), date: snapshot.1) }
            catch let error as CKError where error.code == .serverRecordChanged { throw RecordError.conflicted(record) }
            guard let revision = try self.revisions(head).first else { throw BackendError.malformed }
            let remoteMetadata = try self.metadata(head)
            return try await context.perform {
                try RemoteRecord(identifier: name, versionIdentifier: revision.identifier, versionDate: revision.date, metadata: remoteMetadata, status: .normal, context: context)
            }
        }
    }
    func download(_ record: AnyRecord, version: Version, context: NSManagedObjectContext, completionHandler: @escaping (Result<LocalRecord, RecordError>) -> Void) -> Progress {
        run({ self.recordFailure(record, $0) }, context: context, completion: completionHandler) {
            let name = try record.perform { managed -> String in
                guard let remote = managed.remoteRecord else { throw ValidationError.nilRemoteRecord }
                return remote.identifier
            }
            let url = try await self.downloadPayload(headName: name, version: version.identifier)
            defer { try? FileManager.default.removeItem(at: url) }
            let data = try Data(contentsOf: url)
            return try await context.perform {
                let decoder = JSONDecoder(); decoder.managedObjectContext = context
                return try decoder.decode(LocalRecord.self, from: data)
            }
        }
    }
    func delete(_ record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress {
        run({ self.recordFailure(record, $0) }, completion: completionHandler) {
            let name = try record.perform { managed -> String in
                guard let remote = managed.remoteRecord else { throw ValidationError.nilRemoteRecord }
                return remote.identifier
            }
            try await self.removeHead(name)
        }
    }
    private func removeHead(_ name: String) async throws {
        do { _ = try await database.deleteRecord(withID: id(name)) }
        catch let error as CKError where error.code == .unknownItem { /* Idempotent deletion. */ }
    }
    func upload(_ file: File, for record: AnyRecord, metadata: [HarmonyMetadataKey: Any], context: NSManagedObjectContext, completionHandler: @escaping (Result<RemoteFile, FileError>) -> Void) -> Progress {
        run({ FileError(file.identifier, $0) }, context: context, completion: completionHandler) {
            let name = try self.headName(kind: "file", components: [String(describing: record.recordID), file.identifier])
            let head = try await self.fetchHead(name, createType: "DeltaFile")
            // Snapshot the asset: a running game may write its save while CloudKit uploads.
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: file.fileURL, to: temporary)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let expectedHash = metadata[HarmonyMetadataKey("harmony_sha1Hash")] as? String
            guard try RSTHasher.sha1HashOfFile(at: temporary) == expectedHash else { throw BackendError.malformed }
            let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            head["size"] = NSNumber(value: size)
            _ = try await self.uploadRevision(head: head, payload: temporary, metadata: self.metadataData(metadata), date: Date())
            guard let version = try self.revisions(head).first else { throw BackendError.malformed }
            let remoteMetadata = try self.metadata(head)
            return try await context.perform {
                try RemoteFile(remoteIdentifier: name, versionIdentifier: version.identifier, size: size, metadata: remoteMetadata, context: context)
            }
        }
    }
    func download(_ remoteFile: RemoteFile, version: String?, completionHandler: @escaping (Result<File, FileError>) -> Void) -> Progress {
        let name = remoteFile.remoteIdentifier, identifier = remoteFile.identifier
        return run({ FileError(identifier, $0) }, completion: completionHandler) {
            let url = try await self.downloadPayload(headName: name, version: version)
            return File(identifier: identifier, fileURL: url)
        }
    }
    func delete(_ remoteFile: RemoteFile, completionHandler: @escaping (Result<Void, FileError>) -> Void) -> Progress {
        let name = remoteFile.remoteIdentifier, identifier = remoteFile.identifier
        return run({ FileError(identifier, $0) }, completion: completionHandler) { try await self.removeHead(name) }
    }
    func updateMetadata(_ metadata: [HarmonyMetadataKey: Any], for record: AnyRecord, completionHandler: @escaping (Result<Void, RecordError>) -> Void) -> Progress {
        run({ self.recordFailure(record, $0) }, completion: completionHandler) {
            let name = try record.perform { managed -> String in
                guard let remote = managed.remoteRecord else { throw ValidationError.nilRemoteRecord }
                return remote.identifier
            }
            let head = try await self.fetchHead(name)
            var values = try self.metadata(head).mapValues { $0 as Any }
            values.merge(metadata) { _, new in new }
            head["metadata"] = try self.metadataData(values) as CKRecordValue
            try await self.save([head])
        }
    }
    func fetchVersions(for record: AnyRecord, completionHandler: @escaping (Result<[Version], RecordError>) -> Void) -> Progress {
        run({ self.recordFailure(record, $0) }, completion: completionHandler) {
            let name = try record.perform { managed -> String in
                guard let remote = managed.remoteRecord else { throw ValidationError.nilRemoteRecord }
                return remote.identifier
            }
            return try self.revisions(await self.fetchHead(name)).map { Version(identifier: $0.identifier, date: $0.date) }
        }
    }
    func fetchVersions(for remoteFile: RemoteFile, completionHandler: @escaping (Result<[Version], FileError>) -> Void) -> Progress {
        let name = remoteFile.remoteIdentifier, identifier = remoteFile.identifier
        return run({ FileError(identifier, $0) }, completion: completionHandler) {
            try self.revisions(await self.fetchHead(name)).map { Version(identifier: $0.identifier, date: $0.date) }
        }
    }
}
