import DevtailKit
import Foundation
import Testing

@testable import devtail

@MainActor
struct PersistenceIntegrationTests {

  private func isolatedDefaults() -> (UserDefaults, String) {
    let suite = "devtail.persistence.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
  }

  @Test func saveThenLoadRoundTripsDevProcesses() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let id = UUID()
    let auxID = UUID()
    let process = DevProcess(
      id: id,
      name: "Web",
      command: "npm run dev",
      workingDirectory: "/tmp/project",
      auxiliaryCommands: [AuxiliaryCommand(id: auxID, name: "CSS", command: "tailwind --watch")]
    )

    Persistence.save([process], defaults: defaults)
    let loaded = Persistence.load(defaults: defaults)

    #expect(loaded.count == 1)
    #expect(loaded[0].id == id)
    #expect(loaded[0].name == "Web")
    #expect(loaded[0].command == "npm run dev")
    #expect(loaded[0].workingDirectory == "/tmp/project")
    #expect(loaded[0].auxiliaryCommands.count == 1)
    #expect(loaded[0].auxiliaryCommands[0].id == auxID)
    #expect(loaded[0].auxiliaryCommands[0].name == "CSS")
    #expect(loaded[0].wasRunning == false)
  }

  @Test func loadFromEmptyDefaultsReturnsEmpty() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let loaded = Persistence.load(defaults: defaults)
    #expect(loaded.isEmpty)
  }

  @Test func loadWithCorruptDataReturnsEmpty() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    defaults.set(Data("not valid json".utf8), forKey: Persistence.defaultKey)
    let loaded = Persistence.load(defaults: defaults)
    #expect(loaded.isEmpty)
  }

  @Test func saveReplacesPreviousData() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = DevProcess(name: "A", command: "echo a")
    let second = DevProcess(name: "B", command: "echo b")

    Persistence.save([first], defaults: defaults)
    #expect(Persistence.load(defaults: defaults).count == 1)

    Persistence.save([second], defaults: defaults)
    let loaded = Persistence.load(defaults: defaults)
    #expect(loaded.count == 1)
    #expect(loaded[0].name == "B")
  }

  @Test func saveEmptyListClearsEntries() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    Persistence.save([DevProcess(name: "A", command: "echo a")], defaults: defaults)
    Persistence.save([], defaults: defaults)

    #expect(Persistence.load(defaults: defaults).isEmpty)
  }

  @Test func customKeyIsolatesEntries() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    Persistence.save(
      [DevProcess(name: "A", command: "echo a")],
      defaults: defaults,
      key: "devtail.testkey.one"
    )
    Persistence.save(
      [DevProcess(name: "B", command: "echo b")],
      defaults: defaults,
      key: "devtail.testkey.two"
    )

    let one = Persistence.load(defaults: defaults, key: "devtail.testkey.one")
    let two = Persistence.load(defaults: defaults, key: "devtail.testkey.two")
    #expect(one.count == 1 && one[0].name == "A")
    #expect(two.count == 1 && two[0].name == "B")
  }
}
