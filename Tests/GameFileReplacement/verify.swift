import Foundation
@main struct Checks {
 static func main() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer {try? FileManager.default.removeItem(at: root)}
  let source=root.appendingPathComponent("new.jar"), target=root.appendingPathComponent("existing.jar"), artwork=root.appendingPathComponent("cover.png")
  let old=Data("old game".utf8), new=Data("new game".utf8)
  try new.write(to: source);try old.write(to: target);try old.write(to: artwork)
  try GameFileReplacement.replace(source: source, destination: target) { precondition((try? Data(contentsOf: target))==new) }
  precondition((try? Data(contentsOf: target))==new)
  precondition((try? Data(contentsOf: artwork))==old)
  try old.write(to: target)
  do {try GameFileReplacement.replace(source: source, destination: target) { throw CocoaError(.fileWriteUnknown) };preconditionFailure()} catch {}
  precondition((try? Data(contentsOf: target))==old)
  try FileManager.default.removeItem(at: target)
  do {try GameFileReplacement.replace(source: source, destination: target) { throw CocoaError(.fileWriteUnknown) };preconditionFailure()} catch {}
  precondition(!FileManager.default.fileExists(atPath: target.path))
  try Data().write(to: source);try old.write(to: target)
  do {try GameFileReplacement.replace(source: source, destination: target) {};preconditionFailure()} catch {}
  precondition((try? Data(contentsOf: target))==old)
  precondition((try? FileManager.default.contentsOfDirectory(atPath: root.path).sorted())==["cover.png","existing.jar","new.jar"])
  print("Replacement checks passed: swap, existing/missing-file rollback, empty-file rejection, artwork preservation and staging cleanup")
 }
}
