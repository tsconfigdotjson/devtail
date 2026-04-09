import SwiftUI
import DevtailKit

@MainActor
@Observable
final class ProcessStore {
    var processes: [DevProcess]

    init() {
        self.processes = Self.sampleData()
    }

    func addProcess(name: String, command: String, workingDirectory: String, auxiliaryCommands: [AuxiliaryCommand]) {
        let process = DevProcess(
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            auxiliaryCommands: auxiliaryCommands
        )
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            processes.insert(process, at: 0)
        }
    }

    func removeProcess(id: UUID) {
        if let process = processes.first(where: { $0.id == id }) {
            process.stop()
        }
        withAnimation(.spring(duration: 0.3)) {
            processes.removeAll { $0.id == id }
        }
    }

    // MARK: - Sample Data with ANSI colors

    private static func sampleData() -> [DevProcess] {
        let jooba = DevProcess(
            name: "jooba",
            command: "npm run dev",
            workingDirectory: "~/projects/jooba",
            auxiliaryCommands: [
                AuxiliaryCommand(
                    name: "Server Logs",
                    command: "tail -f logs/server.log"
                ),
            ]
        )
        jooba.isRunning = true
        jooba.buffer.append(
            "\u{1B}[36m>\u{1B}[0m jooba@2.1.0 dev\n"
            + "\u{1B}[36m>\u{1B}[0m next dev\n"
            + "\n"
            + "  \u{1B}[32m\u{25B2} Next.js 14.0.4\u{1B}[0m\n"
            + "  - Local:        \u{1B}[36mhttp://localhost:3000\u{1B}[0m\n"
            + "\n"
            + " \u{1B}[32m\u{2713}\u{1B}[0m Ready in 2.3s\n"
            + " \u{1B}[32m\u{2713}\u{1B}[0m Compiled \u{1B}[36m/\u{1B}[0m in 340ms\n"
            + " \u{1B}[32m\u{2713}\u{1B}[0m Compiled \u{1B}[36m/api/users\u{1B}[0m in 120ms\n"
        )

        // Populate the server log auxiliary buffer
        let serverLogID = jooba.auxiliaryCommands[0].id
        jooba.bufferFor(auxiliary: serverLogID).append(
            "\u{1B}[2m[10:23:45]\u{1B}[0m \u{1B}[32mINFO\u{1B}[0m  Request \u{1B}[1mGET\u{1B}[0m /api/users \u{1B}[32m200\u{1B}[0m \u{1B}[2m45ms\u{1B}[0m\n"
            + "\u{1B}[2m[10:23:46]\u{1B}[0m \u{1B}[32mINFO\u{1B}[0m  WebSocket connection established\n"
            + "\u{1B}[2m[10:23:47]\u{1B}[0m \u{1B}[33mDEBUG\u{1B}[0m Cache hit ratio: 94.2%\n"
        )

        let gateway = DevProcess(
            name: "api-gateway",
            command: "cargo run --release",
            workingDirectory: "~/projects/gateway",
            auxiliaryCommands: [
                AuxiliaryCommand(
                    name: "Access Log",
                    command: "tail -f /var/log/gateway/access.log"
                ),
            ]
        )
        gateway.buffer.append(
            "\u{1B}[1m\u{1B}[32m   Compiling\u{1B}[0m api-gateway v0.3.1\n"
            + "\u{1B}[1m\u{1B}[32m   Compiling\u{1B}[0m hyper v1.2.0\n"
            + "\u{1B}[1m\u{1B}[32m   Compiling\u{1B}[0m tokio v1.36.0\n"
            + "\u{1B}[1m\u{1B}[32m    Finished\u{1B}[0m \u{1B}[32mrelease [optimized]\u{1B}[0m target(s) in 12.4s\n"
            + "\u{1B}[1m\u{1B}[32m     Running\u{1B}[0m `target/release/api-gateway`\n"
            + "\u{1B}[36m[INFO]\u{1B}[0m Server listening on \u{1B}[1m0.0.0.0:8080\u{1B}[0m\n"
            + "\u{1B}[36m[INFO]\u{1B}[0m Healthcheck endpoint: \u{1B}[2m/health\u{1B}[0m\n"
            + "\u{1B}[33m[WARN]\u{1B}[0m Rate limiter using default config\n"
            + "Process terminated.\n"
        )

        let accessLogID = gateway.auxiliaryCommands[0].id
        gateway.bufferFor(auxiliary: accessLogID).append(
            "\u{1B}[2m192.168.1.10\u{1B}[0m - \u{1B}[36m[09/Apr/2026:10:23:45]\u{1B}[0m \"\u{1B}[1mGET\u{1B}[0m /api/v1/users\" \u{1B}[32m200\u{1B}[0m 1234\n"
            + "\u{1B}[2m192.168.1.11\u{1B}[0m - \u{1B}[36m[09/Apr/2026:10:23:46]\u{1B}[0m \"\u{1B}[1mPOST\u{1B}[0m /api/v1/auth\" \u{1B}[32m200\u{1B}[0m 567\n"
            + "\u{1B}[2m192.168.1.12\u{1B}[0m - \u{1B}[36m[09/Apr/2026:10:23:47]\u{1B}[0m \"\u{1B}[1mGET\u{1B}[0m /api/v1/health\" \u{1B}[32m200\u{1B}[0m 12\n"
        )

        return [jooba, gateway]
    }
}
