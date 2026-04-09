import SwiftUI

@MainActor
@Observable
final class ProcessStore {
    var processes: [ProcessConfig]

    init() {
        self.processes = Self.sampleData()
    }

    func addProcess(name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]) {
        let config = ProcessConfig(
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            auxiliaryCommands: auxiliaryCommands
        )
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            processes.insert(config, at: 0)
        }
    }

    func removeProcess(id: UUID) {
        withAnimation(.spring(duration: 0.3)) {
            processes.removeAll { $0.id == id }
        }
    }

    func toggleProcess(id: UUID) {
        guard let index = processes.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            processes[index].isRunning.toggle()
            if processes[index].isRunning {
                processes[index].commandOutput = "Starting \(processes[index].command)...\nProcess started with PID 4821"
            } else {
                processes[index].commandOutput += "\nProcess terminated."
            }
        }
    }

    private static func sampleData() -> [ProcessConfig] {
        [
            ProcessConfig(
                name: "jooba",
                command: "npm run dev",
                workingDirectory: "~/projects/jooba",
                auxiliaryCommands: [
                    AuxiliaryCommand(
                        name: "Server Logs",
                        command: "tail -f logs/server.log",
                        output: "[10:23:45] INFO  Request GET /api/users 200 45ms\n[10:23:46] INFO  WebSocket connection established\n[10:23:47] DEBUG Cache hit ratio: 94.2%"
                    ),
                ],
                isRunning: true,
                commandOutput: "> jooba@2.1.0 dev\n> next dev\n\n  \u{25B2} Next.js 14.0.4\n  - Local: http://localhost:3000\n  \u{2713} Ready in 2.3s"
            ),
            ProcessConfig(
                name: "api-gateway",
                command: "cargo run --release",
                workingDirectory: "~/projects/gateway",
                auxiliaryCommands: [
                    AuxiliaryCommand(
                        name: "Access Log",
                        command: "tail -f /var/log/gateway/access.log"
                    ),
                ],
                isRunning: false,
                commandOutput: ""
            ),
        ]
    }
}
