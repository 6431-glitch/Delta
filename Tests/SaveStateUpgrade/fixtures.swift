let tags = TagFixture()
tags.tags = [" Boss ", "boss", "", "Chapter 2", "|safe|", String(repeating: "x", count: 40)]
precondition(tags.tags == ["Boss", "Chapter 2", "safe", String(repeating: "x", count: 32)])
tags.tags = (0..<20).map { "Tag \($0)" }
precondition(tags.tags.count == 8)
tags.tags = []; precondition(tags.tagsRaw == nil)
precondition(SaveStateRules.historyLimit(nil) == 5)
for (input, expected) in [(-1, 0), (0, 0), (2, 2), (5, 5), (10, 10), (20, 20), (99, 20)] {
    precondition(SaveStateRules.historyLimit(input) == expected)
}
var clock = MainSaveClock()
precondition(!clock.advance(seconds: 299, gameID: "a", active: true))
precondition(!clock.advance(seconds: 1000, gameID: "a", active: false))
precondition(clock.advance(seconds: 1, gameID: "a", active: true))
precondition(!clock.advance(seconds: 299, gameID: "a", active: true))
precondition(!clock.advance(seconds: 1, gameID: "b", active: true))
precondition(clock.advance(seconds: 299, gameID: "b", active: true))
precondition(!clock.advance(seconds: .nan, gameID: "b", active: true))
precondition(!clock.advance(seconds: -10, gameID: "b", active: true))
print("Production policy passed: active-only 5-minute cadence, game switching, repeated intervals, history limits, tag normalization/deduplication/bounds.")

let momd = URL(fileURLWithPath: CommandLine.arguments[2])
let store = URL(fileURLWithPath: CommandLine.arguments[3]).appendingPathComponent("migration.sqlite")
func model(_ version: Int) -> NSManagedObjectModel {
    let model = NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Delta \(version).mom"))!
    // Host fixtures use plain managed objects rather than app-only UIKit subclasses.
    model.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
    return model
}
let old = model(13)
do {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: old)
    let persistent = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: store)
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    for (index, type) in [0, 1, 2, 3].enumerated() {
        let state = NSEntityDescription.insertNewObject(forEntityName: "SaveState", into: context)
        state.setValuesForKeys(["identifier": "state-\(index)", "filename": "state-\(index)", "creationDate": Date(), "modifiedDate": Date(), "type": type, "name": "Existing \(index)"])
    }
    try context.save()
    try coordinator.remove(persistent)
}
let new = model(14)
let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: old, destinationModel: new)
precondition(mapping.entityMappings.contains { $0.name.contains("SaveState") })
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: new)
_ = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: store, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
context.persistentStoreCoordinator = coordinator
let request = NSFetchRequest<NSManagedObject>(entityName: "SaveState")
let states = try context.fetch(request)
precondition(states.count == 4)
precondition(Set(states.map { $0.value(forKey: "type") as! Int }) == [0, 1, 2, 3])
for state in states {
    precondition(state.value(forKey: "tagsRaw") == nil)
    precondition((state.value(forKey: "sortPosition") as! Double) == 0)
}
states[0].setValue("|Boss|", forKey: "tagsRaw")
states[0].setValue(2.0, forKey: "sortPosition")
let main = NSEntityDescription.insertNewObject(forEntityName: "SaveState", into: context)
main.setValuesForKeys(["identifier": "main", "filename": "main", "creationDate": Date(), "modifiedDate": Date(), "type": 4, "name": "Main Save"])
try context.save()
context.reset()
let mainRequest = NSFetchRequest<NSManagedObject>(entityName: "SaveState")
mainRequest.predicate = NSPredicate(format: "type == 4")
let mains = try context.fetch(mainRequest)
precondition(mains.count == 1)
print("Actual compiled model migration passed: v13 SQLite states preserved in v14, new metadata defaults and persistence, Main Save type supported.")

let tagRequest = NSFetchRequest<NSManagedObject>(entityName: "SaveState")
tagRequest.predicate = NSPredicate(format: "tagsRaw CONTAINS[c] %@", "|boss|")
let tagged = try context.fetch(tagRequest)
precondition(tagged.count == 1)
let general = try context.fetch(request).first { ($0.value(forKey: "type") as! Int) == 2 }!
general.setValue(2.0, forKey: "sortPosition")
for (id, order) in [("manual-a", 1.0), ("manual-b", 3.0)] {
    let state = NSEntityDescription.insertNewObject(forEntityName: "SaveState", into: context)
    state.setValuesForKeys(["identifier": id, "filename": id, "creationDate": Date(), "modifiedDate": Date(), "type": 2, "sortPosition": order])
}
try context.save()
let ordered = NSFetchRequest<NSManagedObject>(entityName: "SaveState")
ordered.predicate = NSPredicate(format: "type == 2")
ordered.sortDescriptors = [NSSortDescriptor(key: "sortPosition", ascending: true)]
let identifiers = try context.fetch(ordered).map { $0.value(forKey: "identifier") as! String }
precondition(identifiers == ["manual-a", "state-2", "manual-b"])
let sectioned = NSFetchRequest<NSManagedObject>(entityName: "SaveState")
sectioned.sortDescriptors = [NSSortDescriptor(key: "type", ascending: false), NSSortDescriptor(key: "sortPosition", ascending: true)]
let first = try context.fetch(sectioned).first!
precondition(first.value(forKey: "identifier") as! String == "main")
print("Real-store filtering/ordering passed: case-insensitive exact tags, manual section order and Main Save first.")
