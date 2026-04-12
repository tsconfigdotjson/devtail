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
  private static let key = "devtail.processes"

  @MainActor
  static func save(_ processes: [DevProcess]) {
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
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  static func load() -> [SavedProcess] {
    guard let data = UserDefaults.standard.data(forKey: key),
      let saved = try? JSONDecoder().decode([SavedProcess].self, from: data)
    else {
      return []
    }
    return saved
  }
}
