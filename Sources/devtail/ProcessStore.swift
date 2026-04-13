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
  private let detectPorts: @Sendable ([Int32]) -> [Int32: [Int]]
  private let portPollInterval: Duration

  static let defaultAutoStartDelay: Duration = .milliseconds(100)
  static let defaultSaveDebounceDelay: Duration = .milliseconds(250)
  static let defaultPortPollInterval: Duration = .seconds(1)
  static let portPollMaxAttempts = 30

  private var portPollTask: Task<Void, Never>?
  private var pendingPortDetection: [UUID: Int] = [:]

  init(
    defaults: UserDefaults = .standard,
    persistenceKey: String = Persistence.defaultKey,
    makeRunner: @escaping @MainActor () -> ProcessRunning = { ProcessRunner() },
    autoStartDelay: Duration = ProcessStore.defaultAutoStartDelay,
    saveDebounceDelay: Duration = ProcessStore.defaultSaveDebounceDelay,
    portPollInterval: Duration = ProcessStore.defaultPortPollInterval,
    detectPorts: @escaping @Sendable ([Int32]) -> [Int32: [Int]] = { PortDetector.detect(rootPIDs: $0) }
  ) {
    self.defaults = defaults
    self.persistenceKey = persistenceKey
    self.makeRunner = makeRunner
    self.autoStartDelay = autoStartDelay
    self.saveDebounceDelay = saveDebounceDelay
    self.portPollInterval = portPollInterval
    self.detectPorts = detectPorts

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
      self?.handlePortDetectionStateChange(for: process)
    }
    process.onNaturalExit = { status in
      AppNotifications.processExited(name: process.name, exitCode: status)
    }
  }

  private func handlePortDetectionStateChange(for process: DevProcess) {
    if process.isRunning, process.detectedPorts.isEmpty {
      pendingPortDetection[process.id] = 0
      ensurePortPolling()
    } else {
      pendingPortDetection.removeValue(forKey: process.id)
    }
  }

  func stopAllForQuit() {
    isQuitting = true
    pendingSave?.cancel()
    portPollTask?.cancel()
    portPollTask = nil
    Persistence.save(processes, defaults: defaults, key: persistenceKey)
    for process in processes where process.isRunning {
      process.forceStop()
    }
  }

  private func ensurePortPolling() {
    guard portPollTask == nil, !pendingPortDetection.isEmpty else { return }
    let interval = portPollInterval
    portPollTask = Task { @MainActor [weak self] in
      while true {
        try? await Task.sleep(for: interval)
        guard let self, !Task.isCancelled else { break }
        if self.pendingPortDetection.isEmpty { break }
        await self.tickPortDetection()
      }
      self?.portPollTask = nil
    }
  }

  func tickPortDetection() async {
    var pidByID: [UUID: Int32] = [:]
    for id in pendingPortDetection.keys {
      guard let process = processes.first(where: { $0.id == id }),
        process.isRunning
      else {
        pendingPortDetection.removeValue(forKey: id)
        continue
      }
      let pid = process.currentPID
      if pid > 0 { pidByID[id] = pid }
    }
    guard !pidByID.isEmpty else { return }

    let pids = Array(pidByID.values)
    let detector = detectPorts
    let portsByPID = await Task.detached(priority: .utility) {
      detector(pids)
    }.value

    for (id, pid) in pidByID {
      guard let process = processes.first(where: { $0.id == id }) else {
        pendingPortDetection.removeValue(forKey: id)
        continue
      }
      let newPorts = portsByPID[pid] ?? []
      if !newPorts.isEmpty {
        process.detectedPorts = newPorts
        pendingPortDetection.removeValue(forKey: id)
      } else {
        let attempts = (pendingPortDetection[id] ?? 0) + 1
        if attempts >= Self.portPollMaxAttempts {
          pendingPortDetection.removeValue(forKey: id)
        } else {
          pendingPortDetection[id] = attempts
        }
      }
    }
  }
}
