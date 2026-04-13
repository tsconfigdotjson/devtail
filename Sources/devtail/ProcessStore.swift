import DevtailKit
import SwiftUI

@MainActor
@Observable
final class ProcessStore {
  var processes: [DevProcess]
  var onIconChange: (() -> Void)?
  private var isQuitting = false
  private var pendingSave: Task<Void, Never>?

  private let defaults: UserDefaults
  private let persistenceKey: String
  private let makeRunner: @MainActor () -> ProcessRunning
  private let autoStartDelay: Duration
  private let saveDebounceDelay: Duration

  static let defaultAutoStartDelay: Duration = .milliseconds(100)
  static let defaultSaveDebounceDelay: Duration = .milliseconds(250)

  init(
    defaults: UserDefaults = .standard,
    persistenceKey: String = Persistence.defaultKey,
    makeRunner: @escaping @MainActor () -> ProcessRunning = { ProcessRunner() },
    autoStartDelay: Duration = ProcessStore.defaultAutoStartDelay,
    saveDebounceDelay: Duration = ProcessStore.defaultSaveDebounceDelay
  ) {
    self.defaults = defaults
    self.persistenceKey = persistenceKey
    self.makeRunner = makeRunner
    self.autoStartDelay = autoStartDelay
    self.saveDebounceDelay = saveDebounceDelay

    let saved = Persistence.load(defaults: defaults, key: persistenceKey)
    self.processes = saved.map { config in
      DevProcess(
        id: config.id,
        name: config.name,
        command: config.command,
        workingDirectory: config.workingDirectory,
        auxiliaryCommands: config.auxiliaryCommands.map {
          AuxiliaryCommand(id: $0.id, name: $0.name, command: $0.command)
        },
        makeRunner: makeRunner
      )
    }

    for process in processes {
      wireCallbacks(process)
    }

    let autoStartIDs = Set(saved.filter(\.wasRunning).map(\.id))
    if !autoStartIDs.isEmpty {
      let delay = autoStartDelay
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: delay)
        guard let self else { return }
        for process in self.processes where autoStartIDs.contains(process.id) {
          process.start()
        }
      }
    }
  }

  func addProcess(name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]) {
    let process = DevProcess(
      name: name,
      command: command,
      workingDirectory: workingDirectory,
      auxiliaryCommands: auxiliaryCommands,
      makeRunner: makeRunner
    )
    wireCallbacks(process)
    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
      processes.insert(process, at: 0)
    }
    scheduleSave()
  }

  func removeProcess(id: UUID) {
    if let process = processes.first(where: { $0.id == id }) {
      process.stop()
      PopOutWindowManager.shared.closeWindow(for: process.buffer)
      for aux in process.auxiliaryCommands {
        PopOutWindowManager.shared.closeWindow(for: process.bufferFor(auxiliary: aux.id))
      }
    }
    withAnimation(.spring(duration: 0.3)) {
      processes.removeAll { $0.id == id }
    }
    scheduleSave()
  }

  func updateProcess(
    id: UUID, name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]
  ) {
    guard let process = processes.first(where: { $0.id == id }) else { return }
    if process.isRunning { process.stop() }

    process.name = name
    process.command = command
    process.workingDirectory = workingDirectory
    process.auxiliaryCommands = auxiliaryCommands
    process.cleanupAuxiliaryBuffers()
    scheduleSave()
  }

  func scheduleSave() {
    guard !isQuitting else { return }
    pendingSave?.cancel()
    let delay = saveDebounceDelay
    pendingSave = Task { @MainActor [weak self] in
      try? await Task.sleep(for: delay)
      guard let self, !Task.isCancelled, !self.isQuitting else { return }
      Persistence.save(self.processes, defaults: self.defaults, key: self.persistenceKey)
    }
  }

  private func wireCallbacks(_ process: DevProcess) {
    process.onStateChange = { [weak self] in
      self?.scheduleSave()
      self?.onIconChange?()
    }
    process.onNaturalExit = { status in
      AppNotifications.processExited(name: process.name, exitCode: status)
    }
  }

  func stopAllForQuit() {
    isQuitting = true
    pendingSave?.cancel()
    Persistence.save(processes, defaults: defaults, key: persistenceKey)
    for process in processes where process.isRunning {
      process.forceStop()
    }
  }
}
