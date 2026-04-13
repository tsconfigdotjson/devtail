import Foundation

@MainActor
public protocol ProcessRunning: AnyObject {
  var pid: Int32 { get }
  func start(
    command: String,
    workingDirectory: String?,
    buffer: TerminalBuffer,
    onExit: (@MainActor @Sendable (Int32) -> Void)?
  )
  func stop()
  func stopSync(timeout: TimeInterval)
}

extension ProcessRunning {
  public var pid: Int32 { 0 }
}

@MainActor
public final class ProcessRunner: ProcessRunning {
  private var process: Process?
  private var readTask: Task<Void, Never>?
  private var launchedPID: Int32 = 0

  nonisolated private static let readBatchBytes = 16_384
  nonisolated private static let readFlushInterval: Duration = .milliseconds(50)
  nonisolated private static let sigKillDelay: Duration = .milliseconds(800)

  // Without PATH, subprocesses can't resolve node/python/go binaries.
  nonisolated internal static let inheritedEnvKeys: [String] = [
    "PATH", "SHELL", "PWD", "TMPDIR",
    "LANG", "LC_ALL",
    "NODE_ENV",
  ]

  public init() {}

  public var isRunning: Bool {
    process?.isRunning ?? false
  }

  public var pid: Int32 { launchedPID }

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

    proc.environment = Self.makeEnvironment()

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
        if now - lastFlush >= Self.readFlushInterval || pending.count > Self.readBatchBytes {
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
      try? await Task.sleep(for: Self.sigKillDelay)
      kill(-pid, SIGKILL)
    }

    process = nil
    launchedPID = 0
    readTask?.cancel()
    readTask = nil
  }

  public func stopSync(timeout: TimeInterval = 0.3) {
    let pid = launchedPID
    guard pid != 0 else { return }

    kill(-pid, SIGTERM)

    let sem = DispatchSemaphore(value: 0)
    let source = DispatchSource.makeProcessSource(
      identifier: pid,
      eventMask: .exit,
      queue: .global(qos: .userInitiated)
    )
    source.setEventHandler { sem.signal() }
    source.resume()

    // Racy: process may have exited before source activated.
    if kill(pid, 0) != 0 {
      sem.signal()
    }

    if sem.wait(timeout: .now() + timeout) == .timedOut {
      kill(-pid, SIGKILL)
    }
    source.cancel()

    process = nil
    launchedPID = 0
    readTask?.cancel()
    readTask = nil
  }

  nonisolated internal static func makeEnvironment() -> [String: String] {
    let parent = ProcessInfo.processInfo.environment
    var env: [String: String] = [
      "HOME": NSHomeDirectory(),
      "USER": NSUserName(),
      "FORCE_COLOR": "1",
      "TERM": "xterm-256color",
    ]
    for key in inheritedEnvKeys {
      if let value = parent[key] {
        env[key] = value
      }
    }
    return env
  }
}
