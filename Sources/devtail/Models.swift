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

    func start() {
        guard !isRunning else { return }
        isRunning = true
        buffer.clear()

        let r = ProcessRunner()
        runner = r
        r.start(
            command: command,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            buffer: buffer
        ) { [weak self] _ in
            self?.isRunning = false
            self?.runner = nil
        }
    }

    func stop() {
        runner?.stop()
        runner = nil
        isRunning = false
    }

    func toggle() {
        if isRunning { stop() } else { start() }
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
