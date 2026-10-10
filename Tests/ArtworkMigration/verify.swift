// Run with: swift Tests/ArtworkMigration/verify.swift /path/to/Delta.app/Delta.momd
// Uses generic managed objects to test the schema independently of iOS emulator frameworks.
import Foundation
import CoreData
let modelDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let old = NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("Delta 12.mom"))!
let new = NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("Delta 13.mom"))!
precondition(Set(new.entitiesByName["Game"]!.attributesByName.keys).subtracting(old.entitiesByName["Game"]!.attributesByName.keys) == ["backdropURL"])
precondition(new.entitiesByName["Game"]!.attributesByName["backdropURL"]!.isOptional)
for model in [old, new] { for entity in model.entities { entity.managedObjectClassName = "NSManagedObject" } }
_ = try NSMappingModel.inferredMappingModel(forSourceModel: old, destinationModel: new)
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AuroraMigration-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let storeURL = directory.appendingPathComponent("Library.sqlite")
func open(_ model: NSManagedObjectModel) throws -> (NSPersistentStoreCoordinator, NSManagedObjectContext) {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = coordinator
    return (coordinator, context)
}
func close(_ coordinator: NSPersistentStoreCoordinator) throws { for store in coordinator.persistentStores { try coordinator.remove(store) } }
do {
    let (coordinator, context) = try open(old)
    let game = NSEntityDescription.insertNewObject(forEntityName: "Game", into: context)
    game.setValue("Artwork migration fixture", forKey: "name")
    game.setValue("fixture", forKey: "identifier")
    game.setValue("fixture.gba", forKey: "filename")
    game.setValue("gba" as NSString, forKey: "type")
    game.setValue(true, forKey: "isFavorite")
    game.setValue(URL(string: "https://example.com/cover.png")! as NSURL, forKey: "artworkURL")
    try context.save()
    try close(coordinator)
}
do {
    let (coordinator, context) = try open(new)
    let games = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Game"))
    precondition(games.count == 1)
    let game = games[0]
    precondition(game.value(forKey: "name") as? String == "Artwork migration fixture")
    precondition(game.value(forKey: "isFavorite") as? Bool == true)
    precondition(game.value(forKey: "artworkURL") as? URL == URL(string: "https://example.com/cover.png"))
    precondition(game.value(forKey: "backdropURL") == nil)
    game.setValue(URL(fileURLWithPath: "/tmp/fixture-backdrop.jpg") as NSURL, forKey: "backdropURL")
    try context.save()
    context.reset()
    let saved = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Game"))[0]
    precondition(saved.value(forKey: "backdropURL") as? URL == URL(fileURLWithPath: "/tmp/fixture-backdrop.jpg"))
    saved.setValue(nil, forKey: "backdropURL")
    try context.save()
    context.reset()
    let reset = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Game"))[0]
    precondition(reset.value(forKey: "backdropURL") == nil)
    try close(coordinator)
}
print("PASS: existing game migrated with cover/favorite preserved; backdrop persists and resets independently.")
