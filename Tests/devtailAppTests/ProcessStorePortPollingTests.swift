import AppKit
import DevtailKit
import Foundation
import Testing

@testable import devtail

final class ScriptedPortDetector: @unchecked Sendable {
  private let lock = NSLock()
  private var _invocations: [[Int32]] = []
  private var _response: [Int32: [Int]] = [:]

  var invocations: [[Int32]] {
    lock.lock(); defer { lock.unlock() }
    return _invocations
  }

  func setResponse(_ response: [Int32: [Int]]) {
    lock.lock(); defer { lock.unlock() }
    _response = response
  }

  var callback: @Sendable ([Int32]) -> [Int32: [Int]] {
    { [self] pids in
      lock.lock()
      _invocations.append(pids)
      let resp = _response
      lock.unlock()
      var out: [Int32: [Int]] = [:]
      for pid in pids { out[pid] = resp[pid] ?? [] }
      return out
    }
  }
}

@MainActor
@Suite(.serialized)
struct ProcessStorePortPollingTests {

  init() { _ = NSApplication.shared }

  private func isolatedDefaults() -> (UserDefaults, String) {
    let suite = "devtail.portpoll.test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
  }

  private func waitFor(
    _ deadline: Duration = .seconds(2),
    _ predicate: () -> Bool
  ) async {
    let end = ContinuousClock.now + deadline
    while ContinuousClock.now < end {
      if predicate() { return }
      try? await Task.sleep(for: .milliseconds(10))
    }
  }

  @Test func detectsPortsAfterProcessStartsAndStopsPolling() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(25),
      detectPorts: detector.callback
    )

    detector.setResponse([4242: [3000]])

    store.addProcess(name: "Web", command: "next", workingDirectory: "", auxiliaryCommands: [])
    let proc = store.processes[0]
    proc.start()
    factory.runners[0].pid = 4242

    await waitFor { proc.detectedPorts == [3000] }
    #expect(proc.detectedPorts == [3000])

    let invocationsAtDetect = detector.invocations.count
    // Once ports are detected, further polling should stop — invocation count must not grow.
    try? await Task.sleep(for: .milliseconds(150))
    #expect(detector.invocations.count == invocationsAtDetect)
  }

  @Test func stopsPollingAfterMaxAttemptsWhenNoPorts() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(10),
      detectPorts: detector.callback
    )

    // Detector never returns ports for this pid.
    detector.setResponse([:])

    store.addProcess(name: "NonServer", command: "echo", workingDirectory: "", auxiliaryCommands: [])
    let proc = store.processes[0]
    proc.start()
    factory.runners[0].pid = 9999

    // Wait well beyond (max attempts × interval) + slack.
    await waitFor(.seconds(2)) {
      detector.invocations.count >= ProcessStore.portPollMaxAttempts
    }

    let countAtMax = detector.invocations.count
    #expect(countAtMax >= ProcessStore.portPollMaxAttempts)
    #expect(proc.detectedPorts.isEmpty)

    // After the cap, polling should stop — give it time to confirm no further calls.
    try? await Task.sleep(for: .milliseconds(100))
    #expect(detector.invocations.count == countAtMax)

    _ = store
  }

  @Test func stoppingProcessHaltsPolling() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(10),
      detectPorts: detector.callback
    )

    detector.setResponse([:])

    store.addProcess(name: "Ghost", command: "sleep", workingDirectory: "", auxiliaryCommands: [])
    let proc = store.processes[0]
    proc.start()
    factory.runners[0].pid = 5555

    // Let polling run a few cycles.
    await waitFor { detector.invocations.count >= 2 }
    #expect(detector.invocations.count >= 2)

    proc.stop()
    let countAtStop = detector.invocations.count

    try? await Task.sleep(for: .milliseconds(100))
    #expect(detector.invocations.count == countAtStop)
    #expect(proc.detectedPorts.isEmpty)
  }

  @Test func skipsDetectionWhenRunnerExposesNoPID() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(10),
      detectPorts: detector.callback
    )

    store.addProcess(name: "Pidless", command: "x", workingDirectory: "", auxiliaryCommands: [])
    store.processes[0].start()
    // Leave runner.pid = 0 — store should never invoke detector with empty pid list.

    try? await Task.sleep(for: .milliseconds(80))
    #expect(detector.invocations.isEmpty)

    _ = store
  }

  @Test func detectsPortsForMultipleProcessesInOneTick() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(25),
      detectPorts: detector.callback
    )

    detector.setResponse([1001: [3000], 2002: [5173, 5174]])

    store.addProcess(name: "Web", command: "w", workingDirectory: "", auxiliaryCommands: [])
    store.addProcess(name: "API", command: "a", workingDirectory: "", auxiliaryCommands: [])
    let web = store.processes.first { $0.name == "Web" }!
    let api = store.processes.first { $0.name == "API" }!

    web.start()
    api.start()
    let webRunner = factory.runners[factory.runners.count - 2]
    let apiRunner = factory.runners[factory.runners.count - 1]
    webRunner.pid = 1001
    apiRunner.pid = 2002

    await waitFor { !web.detectedPorts.isEmpty && !api.detectedPorts.isEmpty }
    #expect(web.detectedPorts == [3000])
    #expect(api.detectedPorts == [5173, 5174])

    // At least one invocation should have asked for both pids at once.
    let batched = detector.invocations.contains { Set($0) == Set([1001, 2002]) }
    #expect(batched)
  }

  @Test func restartingProcessReschedulesDetection() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(15),
      detectPorts: detector.callback
    )

    detector.setResponse([111: [4000]])

    store.addProcess(name: "Srv", command: "s", workingDirectory: "", auxiliaryCommands: [])
    let proc = store.processes[0]
    proc.start()
    factory.runners[0].pid = 111

    await waitFor { proc.detectedPorts == [4000] }
    let countAfterFirstDetection = detector.invocations.count

    proc.stop()
    #expect(proc.detectedPorts.isEmpty)

    // Confirm polling has quiesced.
    try? await Task.sleep(for: .milliseconds(60))
    let countAfterStop = detector.invocations.count

    // Restart with a different pid and new ports.
    detector.setResponse([222: [4001]])
    proc.start()
    factory.runners[1].pid = 222

    await waitFor { proc.detectedPorts == [4001] }
    #expect(proc.detectedPorts == [4001])
    #expect(detector.invocations.count > countAfterStop)
    #expect(countAfterStop >= countAfterFirstDetection)
  }

  @Test func portsClearedWhenProcessExitsNaturally() async {
    let (defaults, suite) = isolatedDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }

    let factory = RecordingRunnerFactory()
    let detector = ScriptedPortDetector()
    let store = ProcessStore(
      defaults: defaults,
      makeRunner: { factory.make() },
      saveDebounceDelay: .milliseconds(20),
      portPollInterval: .milliseconds(15),
      detectPorts: detector.callback
    )

    detector.setResponse([7777: [5173]])

    store.addProcess(name: "Vite", command: "vite", workingDirectory: "", auxiliaryCommands: [])
    let proc = store.processes[0]
    proc.start()
    factory.runners[0].pid = 7777

    await waitFor { proc.detectedPorts == [5173] }
    #expect(proc.detectedPorts == [5173])

    factory.runners[0].fireExit(0)
    #expect(proc.detectedPorts.isEmpty)
  }
}
