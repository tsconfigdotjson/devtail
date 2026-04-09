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
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8) {
                    await buffer.append(str)
                }
            }
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
        if let proc = process, proc.isRunning {
            proc.interrupt()
            // Force-kill if still running after a beat
            let procRef = proc
            Task.detached {
                try? await Task.sleep(for: .milliseconds(500))
                if procRef.isRunning {
                    procRef.terminate()
                }
            }
        }
        process = nil
        readTask?.cancel()
        readTask = nil
    }
}
