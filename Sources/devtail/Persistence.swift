import DevtailKit
import Foundation

struct SavedProcess: Codable {
  let id: UUID
  var name: String
  var command: String
  var workingDirectory: String
  var auxiliaryCommands: [SavedAuxCommand]
  var wasRunning: Bool

  struct SavedAuxCommand: Codable {
    let id: UUID
    var name: String
    var command: String
  }
}

enum Persistence {
  static let defaultKey = "devtail.processes"

  @MainActor
  static func save(
    _ processes: [DevProcess],
    defaults: UserDefaults = .standard,
    key: String = defaultKey
  ) {
    let saved = processes.map { p in
      SavedProcess(
        id: p.id,
        name: p.name,
        command: p.command,
        workingDirectory: p.workingDirectory,
        auxiliaryCommands: p.auxiliaryCommands.map {
          SavedProcess.SavedAuxCommand(id: $0.id, name: $0.name, command: $0.command)
        },
        wasRunning: p.isRunning
      )
    }
    if let data = try? JSONEncoder().encode(saved) {
      defaults.set(data, forKey: key)
    }
  }

  static func load(
    defaults: UserDefaults = .standard,
    key: String = defaultKey
  ) -> [SavedProcess] {
    guard let data = defaults.data(forKey: key),
      let saved = try? JSONDecoder().decode([SavedProcess].self, from: data)
    else {
      return []
    }
    return saved
  }
}
