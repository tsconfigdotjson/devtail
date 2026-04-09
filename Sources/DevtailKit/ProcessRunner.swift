import Foundation

@MainActor
public final class ProcessRunner {
    private var process: Process?
    private var readTask: Task<Void, Never>?

    public init() {}

    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    public func start(
        command: String,
        workingDirectory: String? = nil,
        buffer: TerminalBuffer,
        onExit: (@MainActor @Sendable (Int32) -> Void)? = nil
    ) {
        stop()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", command]

        if let dir = workingDirectory, !dir.isEmpty {
            let expanded = NSString(string: dir).expandingTildeInPath
            proc.currentDirectoryURL = URL(fileURLWithPath: expanded)
        }

        var env = ProcessInfo.processInfo.environment
        env["FORCE_COLOR"] = "1"
        env["TERM"] = "xterm-256color"
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        self.process = proc

        let handle = pipe.fileHandleForReading
        let procRef = proc

        readTask = Task.detached { [weak self] in
            var pending = ""
            var lastFlush = ContinuousClock.now

            while true {
                let data = handle.availableData
                if data.isEmpty {
                    // EOF — flush remaining
                    if !pending.isEmpty {
                        let batch = pending
                        await buffer.append(batch)
                    }
                    break
                }
                if let str = String(data: data, encoding: .utf8) {
                    pending += str
                }

                // Throttle: flush at most every 50ms or when buffer is large
                let now = ContinuousClock.now
                if now - lastFlush >= .milliseconds(50) || pending.count > 16_384 {
                    let batch = pending
                    pending = ""
                    lastFlush = now
                    await buffer.append(batch)
                }
            }

            procRef.waitUntilExit()
            let status = procRef.terminationStatus
            await MainActor.run { [weak self] in
                if self?.process === procRef {
                    self?.process = nil
                }
                onExit?(status)
            }
        }

        do {
            try proc.run()
        } catch {
            self.process = nil
            buffer.append("Failed to start: \(error.localizedDescription)\n")
            onExit?(-1)
        }
    }

    public func stop() {
        guard let proc = process, proc.isRunning else {
            process = nil
            readTask?.cancel()
            readTask = nil
            return
        }

        // Kill the entire process group (zsh + npm + node + server).
        // Use SIGTERM first — SIGINT gets swallowed by npm's signal handler.
        let pid = proc.processIdentifier
        kill(-pid, SIGTERM)

        // Escalate in the background if they don't die
        Task.detached {
            try? await Task.sleep(for: .milliseconds(800))
            // SIGKILL the group — cannot be caught or ignored
            kill(-pid, SIGKILL)
        }

        process = nil
        readTask?.cancel()
        readTask = nil
    }
}
