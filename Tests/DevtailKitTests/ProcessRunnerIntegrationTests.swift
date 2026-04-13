import Foundation
import Testing

@testable import DevtailKit

@MainActor
@Suite(.serialized)
struct ProcessRunnerIntegrationTests {

  private static let shortTimeout: Duration = .seconds(5)

  private func waitForExit(
    runner: ProcessRunner,
    exitStatus: UnsafeMutablePointer<Int32?>? = nil,
    timeout: Duration = shortTimeout
  ) async {
    let deadline = ContinuousClock.now + timeout
    while runner.isRunning && ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  private func plain(_ buffer: TerminalBuffer) -> String {
    buffer.lines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
  }

  @Test func runsCommandAndCapturesStdout() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(
      command: "printf 'hello-from-test\\n'",
      workingDirectory: nil,
      buffer: buffer
    ) { status in
      #expect(status == 0)
      gate.open()
    }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(plain(buffer).contains("hello-from-test"))
  }

  @Test func capturesStderrIntoSameBuffer() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(
      command: "printf 'err-stream\\n' 1>&2",
      workingDirectory: nil,
      buffer: buffer
    ) { _ in gate.open() }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(plain(buffer).contains("err-stream"))
  }

  @Test func propagatesNonZeroExitStatus() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()
    var observed: Int32 = -99

    runner.start(
      command: "exit 42",
      workingDirectory: nil,
      buffer: buffer
    ) { status in
      observed = status
      gate.open()
    }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(observed == 42)
  }

  @Test func runsInSpecifiedWorkingDirectory() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(
      command: "pwd",
      workingDirectory: "/tmp",
      buffer: buffer
    ) { _ in gate.open() }

    await gate.wait(timeout: Self.shortTimeout)
    // On macOS /tmp is a symlink to /private/tmp; accept either.
    let out = plain(buffer)
    #expect(out.contains("/tmp") || out.contains("/private/tmp"))
  }

  @Test func expandsTildeInWorkingDirectory() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(
      command: "pwd",
      workingDirectory: "~",
      buffer: buffer
    ) { _ in gate.open() }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(plain(buffer).contains(NSHomeDirectory()))
  }

  @Test func stopTerminatesLongRunningProcess() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()

    runner.start(
      command: "sleep 30",
      workingDirectory: nil,
      buffer: buffer,
      onExit: nil
    )
    // Give the subprocess a moment to actually launch.
    try? await Task.sleep(for: .milliseconds(100))
    #expect(runner.isRunning)

    runner.stop()
    await waitForExit(runner: runner)
    #expect(!runner.isRunning)
  }

  // `stopSync` is covered via mocks (DevProcessAuxiliaryTests.forceStopUsesSyncOnMainAndAux).
  // A real-subprocess variant blocks MainActor on DispatchSemaphore.wait, which
  // trips swift-testing's cooperative thread-pool guard under CI load.

  @Test func forwardsInheritedEnvironmentToSubprocess() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(
      // FORCE_COLOR is one of the forced keys ProcessRunner always injects.
      command: "printf 'FC=%s\\n' \"$FORCE_COLOR\"",
      workingDirectory: nil,
      buffer: buffer
    ) { _ in gate.open() }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(plain(buffer).contains("FC=1"))
  }

  @Test func failedLaunchInvokesOnExitWithError() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()
    var observed: Int32 = 0

    runner.start(
      command: "echo unreachable",
      workingDirectory: "/definitely/does/not/exist/\(UUID().uuidString)",
      buffer: buffer
    ) { status in
      observed = status
      gate.open()
    }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(observed == -1)
    #expect(plain(buffer).contains("Failed to start"))
  }

  @Test func startTwiceReplacesPreviousProcess() async {
    let runner = ProcessRunner()
    let buffer = TerminalBuffer()
    let gate = AsyncGate()

    runner.start(command: "sleep 30", workingDirectory: nil, buffer: buffer, onExit: nil)
    try? await Task.sleep(for: .milliseconds(50))

    runner.start(command: "printf 'second\\n'", workingDirectory: nil, buffer: buffer) { _ in
      gate.open()
    }

    await gate.wait(timeout: Self.shortTimeout)
    #expect(plain(buffer).contains("second"))
    #expect(!runner.isRunning)
  }
}

/// Awaitable one-shot latch for test synchronization.
final class AsyncGate: @unchecked Sendable {
  private let lock = NSLock()
  private var opened = false
  private var continuations: [CheckedContinuation<Void, Never>] = []

  func open() {
    lock.lock()
    let toResume = continuations
    continuations.removeAll()
    opened = true
    lock.unlock()
    for c in toResume { c.resume() }
  }

  func wait(timeout: Duration) async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
          self.lock.lock()
          if self.opened {
            self.lock.unlock()
            c.resume()
          } else {
            self.continuations.append(c)
            self.lock.unlock()
          }
        }
      }
      group.addTask {
        try? await Task.sleep(for: timeout)
      }
      _ = await group.next()
      group.cancelAll()
    }
  }
}
