import SwiftUI
import DevtailKit

@MainActor
@Observable
final class DevProcess: Identifiable {
    let id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var auxiliaryCommands: [AuxiliaryCommand]

    let buffer = TerminalBuffer()
    private var auxiliaryBuffers: [UUID: TerminalBuffer] = [:]
    var isRunning = false

    private var runner: ProcessRunner?
    private var auxiliaryRunners: [UUID: ProcessRunner] = [:]
    private var userStopped = false

    /// Called when running state changes so the store can persist.
    var onStateChange: (() -> Void)?

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String = "",
        auxiliaryCommands: [AuxiliaryCommand] = []
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.auxiliaryCommands = auxiliaryCommands
    }

    func bufferFor(auxiliary id: UUID) -> TerminalBuffer {
        if let buf = auxiliaryBuffers[id] {
            return buf
        }
        let buf = TerminalBuffer()
        auxiliaryBuffers[id] = buf
        return buf
    }

    /// Remove buffers for auxiliary commands that no longer exist.
    func cleanupAuxiliaryBuffers() {
        let validIDs = Set(auxiliaryCommands.map(\.id))
        for key in auxiliaryBuffers.keys where !validIDs.contains(key) {
            auxiliaryBuffers.removeValue(forKey: key)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        userStopped = false
        isRunning = true
        buffer.clear()

        let r = ProcessRunner()
        runner = r
        r.start(
            command: command,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            buffer: buffer
        ) { [weak self] status in
            guard let self, self.runner === r else { return }
            self.runner = nil
            self.isRunning = false
            self.stopAuxiliaryCommands()

            if status == 0 {
                self.buffer.append("\n\u{1B}[2mProcess exited\u{1B}[0m\n")
            } else {
                self.buffer.append("\n\u{1B}[31mProcess exited with code \(status)\u{1B}[0m\n")
            }

            if !self.userStopped {
                AppNotifications.processExited(name: self.name, exitCode: status)
            }

            self.onStateChange?()
        }

        startAuxiliaryCommands()
        onStateChange?()
    }

    func stop() {
        guard isRunning else { return }
        userStopped = true
        runner?.stop()
        runner = nil
        stopAuxiliaryCommands()
        isRunning = false
        buffer.append("\n\u{1B}[2mProcess stopped\u{1B}[0m\n")
        onStateChange?()
    }

    /// Synchronous stop that blocks until all processes are dead.
    /// Only use during app quit.
    func forceStop() {
        userStopped = true
        runner?.stopSync()
        runner = nil
        for (_, r) in auxiliaryRunners {
            r.stopSync()
        }
        auxiliaryRunners.removeAll()
        isRunning = false
    }

    func toggle() {
        if isRunning { stop() } else { start() }
    }

    // MARK: - Auxiliary Commands

    private func startAuxiliaryCommands() {
        for aux in auxiliaryCommands {
            let auxRunner = ProcessRunner()
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

struct AuxiliaryCommand: Identifiable {
    let id: UUID
    var name: String
    var command: String

    init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }
}
