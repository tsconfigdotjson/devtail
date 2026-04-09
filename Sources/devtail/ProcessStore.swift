import SwiftUI
import DevtailKit

@MainActor
@Observable
final class ProcessStore {
    var processes: [DevProcess]
    private var isQuitting = false

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

        // Wire up persistence callbacks
        for process in processes {
            process.onStateChange = { [weak self] in self?.save() }
        }

        // Defer auto-start so views have time to initialize
        let autoStartIDs = Set(saved.filter(\.wasRunning).map(\.id))
        if !autoStartIDs.isEmpty {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                for process in self.processes where autoStartIDs.contains(process.id) {
                    process.start()
                }
            }
        }
    }

    // MARK: - CRUD

    func addProcess(name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]) {
        let process = DevProcess(
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            auxiliaryCommands: auxiliaryCommands
        )
        process.onStateChange = { [weak self] in self?.save() }
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            processes.insert(process, at: 0)
        }
        save()
    }

    func removeProcess(id: UUID) {
        if let process = processes.first(where: { $0.id == id }) {
            process.stop()
        }
        withAnimation(.spring(duration: 0.3)) {
            processes.removeAll { $0.id == id }
        }
        save()
    }

    func updateProcess(id: UUID, name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]) {
        guard let process = processes.first(where: { $0.id == id }) else { return }
        if process.isRunning { process.stop() }

        process.name = name
        process.command = command
        process.workingDirectory = workingDirectory
        process.auxiliaryCommands = auxiliaryCommands
        process.cleanupAuxiliaryBuffers()
        save()
    }

    // MARK: - Persistence

    func save() {
        guard !isQuitting else { return }
        Persistence.save(processes)
    }

    /// Save state then synchronously kill all processes.
    /// Blocks until every child process is dead — only call during app quit.
    func stopAllForQuit() {
        isQuitting = true
        Persistence.save(processes) // Captures wasRunning before we stop
        for process in processes where process.isRunning {
            process.forceStop()
        }
    }
}
