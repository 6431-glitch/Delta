import Foundation
import CoreData

@objc(SnapshotSaveState) class SaveState: NSManagedObject {
    @NSManaged var type: Int16
    @NSManaged var creationDate: Date
    @NSManaged var gameID: String
    @NSManaged var coreIdentifier: String
    @NSManaged var coreVersion: String
}

extension IndexPath {
    init(item: Int, section: Int) { self.init(indexes: [section, item]) }
    var section: Int { self[0] }
    var item: Int { self[1] }
}
struct ScrollPosition: OptionSet { let rawValue: Int }
class CollectionSpy {
    var reloads = 0
    var selected: [IndexPath] = []
    func reloadData() { reloads += 1; selected = [] }
    func selectItem(at index: IndexPath, animated: Bool, scrollPosition: ScrollPosition) { selected.append(index) }
}
class DataSourceSpy { let prefetchItemCache = NSCache<SaveState, NSString>() }
class FetchedSourceSpy {
    let fetchedResultsController: NSFetchedResultsController<SaveState>
    init(_ controller: NSFetchedResultsController<SaveState>) { fetchedResultsController = controller }
}
class SaveStatesViewController: NSObject {
    enum Filter { case compatible, incompatible }
    var filter = Filter.compatible
    var isEditing = false
    var isViewLoaded = true
    var selectedSaveStateIDs = Set<NSManagedObjectID>()
    let collectionView = CollectionSpy()
    let dataSource = DataSourceSpy()
    let fetchedDataSource: FetchedSourceSpy
    var toolbarUpdates = 0
    init(_ controller: NSFetchedResultsController<SaveState>) { fetchedDataSource = FetchedSourceSpy(controller); super.init() }
    func updateToolbarState() { toolbarUpdates += 1 }
}

func runChecks() {
    for platform in ["GBC", "GBA", "NES", "SNES", "N64", "DS", "Genesis"] {
        runPlatformChecks(platform)
    }
}

func runPlatformChecks(_ platform: String) {
    let entity = NSEntityDescription()
    entity.name = "SaveState"; entity.managedObjectClassName = NSStringFromClass(SaveState.self)
    let type = NSAttributeDescription(); type.name = "type"; type.attributeType = .integer16AttributeType
    let date = NSAttributeDescription(); date.name = "creationDate"; date.attributeType = .dateAttributeType
    let strings = ["gameID", "coreIdentifier", "coreVersion"].map { name -> NSAttributeDescription in
        let attribute = NSAttributeDescription(); attribute.name = name; attribute.attributeType = .stringAttributeType
        return attribute
    }
    entity.properties = [type, date] + strings
    let model = NSManagedObjectModel(); model.entities = [entity]
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    func state(_ type: Int16, _ timestamp: Double) -> SaveState {
        let state = SaveState(entity: entity, insertInto: context)
        state.gameID = "game-a"; state.coreIdentifier = platform; state.coreVersion = "current"
        state.type = type; state.creationDate = Date(timeIntervalSince1970: timestamp)
        return state
    }
    let oldest = state(0, 1); let newest = state(0, 2); let manual = state(2, 3)
    try! context.save()
    let request = NSFetchRequest<SaveState>(entityName: "SaveState")
    request.predicate = NSPredicate(format: "gameID == %@ AND coreIdentifier == %@ AND coreVersion == %@", "game-a", platform, "current")
    request.sortDescriptors = [NSSortDescriptor(key: "type", ascending: true), NSSortDescriptor(key: "creationDate", ascending: false)]
    let results = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: "type", cacheName: nil)
    let screen = SaveStatesViewController(results)
    results.delegate = screen
    try! results.performFetch()
    screen.dataSource.prefetchItemCache.setObject("old snapshot", forKey: oldest)
    // Loading rotates the oldest autosave to the front: a real FRC move.
    oldest.creationDate = Date(timeIntervalSince1970: 4)
    try! context.save()
    precondition(screen.collectionView.reloads == 1)
    precondition(screen.dataSource.prefetchItemCache.object(forKey: oldest) == nil)
    precondition(results.fetchedObjects!.first === oldest)
    // Keep editing selection attached to its object as that object moves.
    screen.isEditing = true; screen.selectedSaveStateIDs = [oldest.objectID, manual.objectID]
    newest.creationDate = Date(timeIntervalSince1970: 5)
    try! context.save()
    precondition(screen.collectionView.selected.contains(results.indexPath(forObject: oldest)!))
    precondition(screen.collectionView.selected.contains(results.indexPath(forObject: manual)!))
    // Section insertion and deletion must not leave selections at obsolete paths.
    let quick = state(1, 6); try! context.save()
    precondition(screen.collectionView.selected.contains(results.indexPath(forObject: manual)!))
    context.delete(manual); try! context.save()
    precondition(!screen.selectedSaveStateIDs.contains(manual.objectID))
    precondition(screen.collectionView.selected.count == 1)
    context.delete(quick); try! context.save()
    // Incompatible view inserts an informational section before fetched sections.
    screen.filter = .incompatible
    oldest.creationDate = Date(timeIntervalSince1970: 7); try! context.save()
    let local = results.indexPath(forObject: oldest)!
    precondition(screen.collectionView.selected == [IndexPath(item: local.item, section: local.section + 1)])
    // Rapid rotations deliver one completed snapshot apiece, without delayed work.
    screen.isEditing = false
    let before = screen.collectionView.reloads
    for index in 0..<20 {
        oldest.creationDate = Date(timeIntervalSince1970: Double(10 + index))
        try! context.save()
    }
    precondition(screen.collectionView.reloads == before + 20)
    // Sync can add states belonging to another game, core or incompatible version.
    let otherGame = state(2, 40); otherGame.gameID = "game-b"
    let otherCore = state(2, 41); otherCore.coreIdentifier = "other-core"
    let incompatible = state(3, 42); incompatible.coreVersion = "legacy"
    try! context.save()
    precondition(results.fetchedObjects!.count == 2)
    incompatible.coreVersion = "current"; try! context.save()
    precondition(results.fetchedObjects!.count == 3)
    incompatible.coreVersion = "legacy"; try! context.save()
    precondition(results.fetchedObjects!.count == 2)
    let reloads = screen.collectionView.reloads
    screen.isViewLoaded = false
    oldest.creationDate = Date(timeIntervalSince1970: 50); try! context.save()
    precondition(screen.collectionView.reloads == reloads)
    print("\(platform) shared-screen checks passed: autosave moves, cache refresh, selection restoration, section insert/delete, info offset and 20 rapid rotations")
}
