import Foundation
import Observation

@MainActor
@Observable
public final class DevProcess: Identifiable {
  public let id: UUID
  public var name: String
  public var command: String
  public var workingDirectory: String
  public var auxiliaryCommands: [AuxiliaryCommand]

  public let buffer: TerminalBuffer
  private var auxiliaryBuffers: [UUID: TerminalBuffer] = [:]
  public var isRunning = false
  public var detectedPorts: [Int] = []

  private var runner: ProcessRunning?
  private var auxiliaryRunners: [UUID: ProcessRunning] = [:]
  private var userStopped = false
  private let makeRunner: @MainActor () -> ProcessRunning

  public var onStateChange: (() -> Void)?
  public var onNaturalExit: (@MainActor (Int32) -> Void)?

  public init(
    id: UUID = UUID(),
    name: String,
    command: String,
    workingDirectory: String = "",
    auxiliaryCommands: [AuxiliaryCommand] = [],
    makeRunner: @escaping @MainActor () -> ProcessRunning = { ProcessRunner() }
  ) {
    self.id = id
    self.name = name
    self.command = command
    self.workingDirectory = workingDirectory
    self.auxiliaryCommands = auxiliaryCommands
    self.buffer = TerminalBuffer()
    self.makeRunner = makeRunner
  }

  public var currentPID: Int32 { runner?.pid ?? 0 }

  public func bufferFor(auxiliary id: UUID) -> TerminalBuffer {
    if let buf = auxiliaryBuffers[id] {
      return buf
    }
    let buf = TerminalBuffer()
    auxiliaryBuffers[id] = buf
    return buf
  }

  public func cleanupAuxiliaryBuffers() {
    let validIDs = Set(auxiliaryCommands.map(\.id))
    for key in auxiliaryBuffers.keys where !validIDs.contains(key) {
      auxiliaryBuffers.removeValue(forKey: key)
    }
  }

  public func start() {
    guard !isRunning else { return }
    userStopped = false
    isRunning = true
    buffer.clear()

    let r = makeRunner()
    runner = r
    r.start(
      command: command,
      workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
      buffer: buffer
    ) { [weak self] status in
      guard let self, self.runner === r else { return }
      self.runner = nil
      self.isRunning = false
      self.detectedPorts = []
      self.stopAuxiliaryCommands()

      if status == 0 {
        self.buffer.append("\n\u{1B}[2mProcess exited\u{1B}[0m\n")
      } else {
        self.buffer.append("\n\u{1B}[31mProcess exited with code \(status)\u{1B}[0m\n")
      }

      if !self.userStopped {
        self.onNaturalExit?(status)
      }

      self.onStateChange?()
    }

    startAuxiliaryCommands()
    onStateChange?()
  }

  public func stop() {
    guard isRunning else { return }
    userStopped = true
    runner?.stop()
    runner = nil
    stopAuxiliaryCommands()
    isRunning = false
    detectedPorts = []
    buffer.append("\n\u{1B}[2mProcess stopped\u{1B}[0m\n")
    onStateChange?()
  }

  public func forceStop() {
    userStopped = true
    runner?.stopSync(timeout: 0.3)
    runner = nil
    for (_, r) in auxiliaryRunners {
      r.stopSync(timeout: 0.3)
    }
    auxiliaryRunners.removeAll()
    isRunning = false
    detectedPorts = []
  }

  public func toggle() {
    if isRunning { stop() } else { start() }
  }

  private func startAuxiliaryCommands() {
    for aux in auxiliaryCommands {
      let auxRunner = makeRunner()
      let auxBuffer = bufferFor(auxiliary: aux.id)
      auxBuffer.clear()
      auxiliaryRunners[aux.id] = auxRunner
      auxRunner.start(
        command: aux.command,
        workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
        buffer: auxBuffer
      ) { [weak self] _ in
        self?.auxiliaryRunners[aux.id] = nil
      }
    }
  }

  private func stopAuxiliaryCommands() {
    for (_, r) in auxiliaryRunners {
      r.stop()
    }
    auxiliaryRunners.removeAll()
  }
}

public struct AuxiliaryCommand: Identifiable, Sendable {
  public let id: UUID
  public var name: String
  public var command: String

  public init(id: UUID = UUID(), name: String, command: String) {
    self.id = id
    self.name = name
    self.command = command
  }
}
