import AppKit
import DevtailKit
import Foundation
import Testing

@testable import devtail

/// Initialize NSApplication once so PopOutWindowManager's NSApp calls don't crash.
@MainActor private let testNSApp: NSApplication = .shared

@MainActor
final class RecordingRunner: ProcessRunning {
  private(set) var startCount = 0
  private(set) var stopCount = 0
  private(set) var stopSyncCount = 0
  private(set) var lastCommand: String?
  private var pendingOnExit: (@MainActor @Sendable (Int32) -> Void)?

  func start(
    command: String,
    workingDirectory: String?,
    buffer: TerminalBuffer,
    onExit: (@MainActor @Sendable (Int32) -> Void)?
  ) {
    startCount += 1
    lastCommand = command
    pendingOnExit = onExit
  }

  func stop() { stopCount += 1 }
  func stopSync(timeout: TimeInterval) { stopSyncCount += 1 }

  func fireExit(_ status: Int32) {
    pendingOnExit?(status)
    pendingOnExit = nil
  }
}

@MainActor
final class RecordingRunnerFactory {
  private(set) var runners: [RecordingRunner] = []
  func make() -> ProcessRunning {
    let r = RecordingRunner()
    runners.append(r)
    return r
  }
}

@MainActor
@Suite(.serialized)
struct ProcessStoreIntegrationTests {

  init() { _ = testNSApp }

  private func isolatedDefaults() -> (UserDefaults, String) {
    let suite = "devtail.processstore.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
  }

  private func seed(_ defaults: UserDefaults, processes: [SavedProcess]) throws {
    let data = try JSONEncoder().encode(processes)
    defaults.set(data, forKey: Persistence.defaultKey)
  }

  private func waitFor(
    _ deadline: Duration = .milliseconds(750),
    _ predicate: () -> Bool
  ) async {
    let end = ContinuousClock.now + deadline
    while ContinuousClock.now < end {
      if predicate() { return }
      try? await Task.sleep(for: .milliseconds(10))
    }
  }

  @Test func initLoadsPreviouslySavedProcesses() throws {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let id = UUID()
    let auxID = UUID()
    try seed(
      defaults,
      processes: [
        SavedProcess(
          id: id, name: "API", command: "go run main.go",
          workingDirectory: "/srv/api",
          auxiliaryCommands: [
            SavedProcess.SavedAuxCommand(id: auxID, name: "logs", command: "tail -f log")
          ],
          wasRunning: false
        )
      ]
    )

    let factory = RecordingRunnerFactory()
    let store = ProcessStore(defaults: defaults, makeRunner: { factory.make() })

    #expect(store.processes.count == 1)
    #expect(store.processes[0].id == id)
    #expect(store.processes[0].name == "API")
    #expect(store.processes[0].command == "go run main.go")
    #expect(store.processes[0].auxiliaryCommands.count == 1)
    #expect(store.processes[0].auxiliaryCommands[0].id == auxID)
    #expect(store.processes[0].auxiliaryCommands[0].name == "logs")
  }

  @Test func naturalExitFromProcessNotifiesAndTriggersSave() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20)
    )
    var iconChangeCount = 0
    store.onIconChange = { iconChangeCount += 1 }

    store.addProcess(name: "Job", command: "echo", workingDirectory: "", auxiliaryCommands: [])
    store.processes[0].start()
    factory.runners[0].fireExit(7)

    #expect(!store.processes[0].isRunning)
    #expect(iconChangeCount >= 1)

    await waitFor {
      let saved = Persistence.load(defaults: defaults)
      return saved.count == 1 && saved[0].wasRunning == false
    }
    let saved = Persistence.load(defaults: defaults)
    #expect(saved.count == 1)
    #expect(saved[0].wasRunning == false)
  }

  @Test func initWithEmptyDefaultsStartsBlank() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(defaults: defaults, makeRunner: { RecordingRunner() })
    #expect(store.processes.isEmpty)
  }

  @Test func addProcessPersistsAfterDebounce() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { RecordingRunner() },
      saveDebounceDelay: .milliseconds(20)
    )

    store.addProcess(name: "Web", command: "npm run dev", workingDirectory: "", auxiliaryCommands: [])
    await waitFor { !Persistence.load(defaults: defaults).isEmpty }

    let loaded = Persistence.load(defaults: defaults)
    #expect(loaded.count == 1)
    #expect(loaded[0].name == "Web")
  }

  @Test func removeProcessPersistsChange() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { RecordingRunner() },
      saveDebounceDelay: .milliseconds(20)
    )

    store.addProcess(name: "A", command: "echo a", workingDirectory: "", auxiliaryCommands: [])
    await waitFor { Persistence.load(defaults: defaults).count == 1 }

    let id = store.processes[0].id
    store.removeProcess(id: id)
    await waitFor { Persistence.load(defaults: defaults).isEmpty }

    #expect(Persistence.load(defaults: defaults).isEmpty)
  }

  @Test func removeProcessWithAuxCommandsClosesAllWindows() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { RecordingRunner() },
      saveDebounceDelay: .milliseconds(20)
    )

    store.addProcess(
      name: "Stack",
      command: "main",
      workingDirectory: "",
      auxiliaryCommands: [
        AuxiliaryCommand(name: "watch", command: "fswatch ."),
        AuxiliaryCommand(name: "lint", command: "eslint --watch"),
      ]
    )
    let id = store.processes[0].id
    // Touch aux buffers so close has something to iterate.
    for aux in store.processes[0].auxiliaryCommands {
      _ = store.processes[0].bufferFor(auxiliary: aux.id)
    }

    store.removeProcess(id: id)
    await waitFor { Persistence.load(defaults: defaults).isEmpty }
    #expect(store.processes.isEmpty)
  }

  @Test func updateProcessPersistsNewFields() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { RecordingRunner() },
      saveDebounceDelay: .milliseconds(20)
    )

    store.addProcess(name: "Old", command: "old", workingDirectory: "", auxiliaryCommands: [])
    await waitFor { Persistence.load(defaults: defaults).first?.name == "Old" }

    let id = store.processes[0].id
    store.updateProcess(
      id: id, name: "New", command: "new",
      workingDirectory: "/work", auxiliaryCommands: []
    )
    await waitFor { Persistence.load(defaults: defaults).first?.name == "New" }

    let saved = Persistence.load(defaults: defaults)
    #expect(saved.count == 1)
    #expect(saved[0].name == "New")
    #expect(saved[0].command == "new")
    #expect(saved[0].workingDirectory == "/work")
  }

  @Test func autoStartsProcessesMarkedAsRunning() async throws {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let runningID = UUID()
    let stoppedID = UUID()
    try seed(
      defaults,
      processes: [
        SavedProcess(
          id: runningID, name: "Alive", command: "tail -f /dev/null",
          workingDirectory: "", auxiliaryCommands: [], wasRunning: true
        ),
        SavedProcess(
          id: stoppedID, name: "Dormant", command: "echo z",
          workingDirectory: "", auxiliaryCommands: [], wasRunning: false
        ),
      ]
    )

    let factory = RecordingRunnerFactory()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      autoStartDelay: .milliseconds(10)
    )

    await waitFor { factory.runners.contains { $0.lastCommand == "tail -f /dev/null" } }
    _ = store  // keep store alive past the weak-self check in the auto-start task

    let startedCommands = factory.runners.compactMap(\.lastCommand)
    #expect(startedCommands.contains("tail -f /dev/null"))
    #expect(!startedCommands.contains("echo z"))
  }

  @Test func stopAllForQuitPersistsRunningStateAndForceStops() {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let store = ProcessStore(defaults: defaults, makeRunner: { factory.make() })

    store.addProcess(name: "Work", command: "echo", workingDirectory: "", auxiliaryCommands: [])
    store.processes[0].start()
    #expect(factory.runners.count == 1)

    store.stopAllForQuit()

    // wasRunning captured before forceStop flips isRunning.
    let saved = Persistence.load(defaults: defaults)
    #expect(saved.count == 1)
    #expect(saved[0].wasRunning == true)
    #expect(factory.runners[0].stopSyncCount == 1)
  }

  @Test func stopAllForQuitCancelsPendingDebouncedSave() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { RecordingRunner() },
      saveDebounceDelay: .milliseconds(200)
    )

    store.addProcess(name: "A", command: "echo a", workingDirectory: "", auxiliaryCommands: [])
    // Quit before debounce fires — stopAllForQuit should still flush synchronously.
    store.stopAllForQuit()

    // Wait past the original debounce window; state should remain stable.
    try? await Task.sleep(for: .milliseconds(300))
    let saved = Persistence.load(defaults: defaults)
    #expect(saved.count == 1)
    #expect(saved[0].name == "A")
  }
}
