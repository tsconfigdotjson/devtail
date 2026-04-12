import DevtailKit
import SwiftUI

@MainActor
@Observable
final class ProcessStore {
  var processes: [DevProcess]
  var onIconChange: (() -> Void)?
  private var isQuitting = false
  private var pendingSave: Task<Void, Never>?

  private static let autoStartDelay: Duration = .milliseconds(100)
  private static let saveDebounceDelay: Duration = .milliseconds(250)

  init() {
    let saved = Persistence.load()
    self.processes = saved.map { config in
      DevProcess(
        id: config.id,
        name: config.name,
        command: config.command,
        workingDirectory: config.workingDirectory,
        auxiliaryCommands: config.auxiliaryCommands.map {
          AuxiliaryCommand(id: $0.id, name: $0.name, command: $0.command)
        }
      )
    }

    for process in processes {
      process.onStateChange = { [weak self] in
        self?.scheduleSave()
        self?.onIconChange?()
      }
    }

    let autoStartIDs = Set(saved.filter(\.wasRunning).map(\.id))
    if !autoStartIDs.isEmpty {
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: Self.autoStartDelay)
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
      auxiliaryCommands: auxiliaryCommands
    )
    process.onStateChange = { [weak self] in
      self?.scheduleSave()
      self?.onIconChange?()
    }
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
    pendingSave = Task { @MainActor [weak self] in
      try? await Task.sleep(for: Self.saveDebounceDelay)
      guard let self, !Task.isCancelled, !self.isQuitting else { return }
      Persistence.save(self.processes)
    }
  }

  func stopAllForQuit() {
    isQuitting = true
    pendingSave?.cancel()
    Persistence.save(processes)
    for process in processes where process.isRunning {
      process.forceStop()
    }
  }
}
