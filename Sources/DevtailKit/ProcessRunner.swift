import Foundation

@MainActor
public final class ProcessRunner {
  private var process: Process?
  private var readTask: Task<Void, Never>?
  private var launchedPID: Int32 = 0

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
    proc.arguments = ["-li", "-c", command]

    if let dir = workingDirectory, !dir.isEmpty {
      let expanded = NSString(string: dir).expandingTildeInPath
      proc.currentDirectoryURL = URL(fileURLWithPath: expanded)
    }

    proc.environment = [
      "HOME": NSHomeDirectory(),
      "USER": NSUserName(),
      "FORCE_COLOR": "1",
      "TERM": "xterm-256color",
    ]

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
          if !pending.isEmpty {
            let batch = pending
            await buffer.append(batch)
          }
          break
        }
        if let str = String(data: data, encoding: .utf8) {
          pending += str
        }

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
          self?.launchedPID = 0
        }
        onExit?(status)
      }
    }

    do {
      try proc.run()
      launchedPID = proc.processIdentifier
    } catch {
      self.process = nil
      self.launchedPID = 0
      buffer.append("Failed to start: \(error.localizedDescription)\n")
      onExit?(-1)
    }
  }

  public func stop() {
    let pid = launchedPID
    guard pid != 0 else { return }

    kill(-pid, SIGTERM)

    Task.detached {
      try? await Task.sleep(for: .milliseconds(800))
      kill(-pid, SIGKILL)
    }

    process = nil
    launchedPID = 0
    readTask?.cancel()
    readTask = nil
  }

  public func stopSync(timeout: TimeInterval = 2.0) {
    let pid = launchedPID
    guard pid != 0 else { return }

    kill(-pid, SIGTERM)

    let deadline = Date().addingTimeInterval(timeout)
    while kill(pid, 0) == 0 && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.01)
    }

    if kill(pid, 0) == 0 {
      kill(-pid, SIGKILL)
      Thread.sleep(forTimeInterval: 0.05)
    }

    process = nil
    launchedPID = 0
    readTask?.cancel()
    readTask = nil
  }
}
