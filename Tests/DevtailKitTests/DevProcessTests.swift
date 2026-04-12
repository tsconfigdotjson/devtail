import Foundation
import Testing

@testable import DevtailKit

@MainActor
final class FakeProcessRunner: ProcessRunning {
  private(set) var startCount = 0
  private(set) var stopCount = 0
  private(set) var stopSyncCount = 0
  private(set) var lastCommand: String?
  private(set) var lastWorkingDirectory: String?
  private(set) var lastBuffer: TerminalBuffer?

  private var pendingOnExit: (@MainActor @Sendable (Int32) -> Void)?

  func start(
    command: String,
    workingDirectory: String?,
    buffer: TerminalBuffer,
    onExit: (@MainActor @Sendable (Int32) -> Void)?
  ) {
    startCount += 1
    lastCommand = command
    lastWorkingDirectory = workingDirectory
    lastBuffer = buffer
    pendingOnExit = onExit
  }

  func stop() { stopCount += 1 }
  func stopSync(timeout: TimeInterval) { stopSyncCount += 1 }

  func fireExit(_ status: Int32) {
    pendingOnExit?(status)
    pendingOnExit = nil
  }
}

@MainActor
struct DevProcessTests {

  private func makeProcess(
    aux: [AuxiliaryCommand] = [],
    factory: FakeRunnerFactory? = nil
  ) -> (DevProcess, FakeRunnerFactory) {
    let f = factory ?? FakeRunnerFactory()
    let process = DevProcess(
      name: "test",
      command: "sleep 5",
      workingDirectory: "/tmp",
      auxiliaryCommands: aux,
      makeRunner: { f.make() }
    )
    return (process, f)
  }

  // MARK: - start / stop basics

  @Test func startSetsIsRunningAndInvokesRunner() {
    let (p, f) = makeProcess()
    p.start()
    #expect(p.isRunning == true)
    #expect(f.runners.count == 1)
    #expect(f.runners[0].startCount == 1)
    #expect(f.runners[0].lastCommand == "sleep 5")
    #expect(f.runners[0].lastWorkingDirectory == "/tmp")
  }

  @Test func startWhenRunningIsNoop() {
    let (p, f) = makeProcess()
    p.start()
    p.start()
    #expect(f.runners.count == 1)
  }

  @Test func emptyWorkingDirectoryPassesNilToRunner() {
    let factory = FakeRunnerFactory()
    let p = DevProcess(
      name: "t", command: "echo hi", workingDirectory: "",
      makeRunner: { factory.make() }
    )
    p.start()
    #expect(factory.runners[0].lastWorkingDirectory == nil)
  }

  @Test func stopWhenNotRunningIsNoop() {
    let (p, f) = makeProcess()
    p.stop()
    #expect(f.runners.count == 0)
    #expect(p.isRunning == false)
  }

  @Test func stopClearsIsRunningAndInvokesRunnerStop() {
    let (p, f) = makeProcess()
    p.start()
    p.stop()
    #expect(p.isRunning == false)
    #expect(f.runners[0].stopCount == 1)
  }

  @Test func toggleFlipsState() {
    let (p, _) = makeProcess()
    p.toggle()
    #expect(p.isRunning == true)
    p.toggle()
    #expect(p.isRunning == false)
  }

  // MARK: - exit distinction: natural vs user-initiated

  @Test func naturalExitFiresOnNaturalExit() {
    let (p, f) = makeProcess()
    var exitStatus: Int32?
    p.onNaturalExit = { status in exitStatus = status }
    p.start()
    f.runners[0].fireExit(0)
    #expect(exitStatus == 0)
    #expect(p.isRunning == false)
  }

  @Test func naturalExitWithNonZeroStatusAppendsErrorMessage() {
    let (p, f) = makeProcess()
    p.start()
    f.runners[0].fireExit(137)
    #expect(p.isRunning == false)
    let plain = p.buffer.lines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
    #expect(plain.contains("137"))
  }

  @Test func userStopDoesNotFireOnNaturalExit() {
    let (p, f) = makeProcess()
    var fired = false
    p.onNaturalExit = { _ in fired = true }
    p.start()
    p.stop()
    f.runners[0].fireExit(-1)
    #expect(fired == false)
  }

  @Test func naturalExitMessageOnCleanExit() {
    let (p, f) = makeProcess()
    p.start()
    f.runners[0].fireExit(0)
    let plain = p.buffer.lines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
    #expect(plain.contains("Process exited"))
  }

  @Test func stopAppendsStoppedMessage() {
    let (p, _) = makeProcess()
    p.start()
    p.stop()
    let plain = p.buffer.lines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
    #expect(plain.contains("Process stopped"))
  }

  // MARK: - auxiliary commands

  @Test func startSpawnsRunnerPerAuxiliary() {
    let aux = [
      AuxiliaryCommand(name: "logs", command: "tail -f log"),
      AuxiliaryCommand(name: "watch", command: "fswatch ."),
    ]
    let (p, f) = makeProcess(aux: aux)
    p.start()
    // 1 main + 2 aux = 3 runners total.
    #expect(f.runners.count == 3)
    #expect(f.runners[1].lastCommand == "tail -f log")
    #expect(f.runners[2].lastCommand == "fswatch .")
  }

  @Test func stopAlsoStopsAuxiliaries() {
    let aux = [AuxiliaryCommand(name: "logs", command: "tail -f log")]
    let (p, f) = makeProcess(aux: aux)
    p.start()
    p.stop()
    #expect(f.runners[0].stopCount == 1)
    #expect(f.runners[1].stopCount == 1)
  }

  @Test func naturalMainExitStopsAuxiliaries() {
    let aux = [AuxiliaryCommand(name: "logs", command: "tail -f log")]
    let (p, f) = makeProcess(aux: aux)
    p.start()
    f.runners[0].fireExit(0)
    #expect(f.runners[1].stopCount == 1)
  }

  @Test func auxiliaryBufferIsCreatedOnDemandAndReused() {
    let aux = AuxiliaryCommand(name: "logs", command: "tail -f log")
    let (p, _) = makeProcess(aux: [aux])
    let a = p.bufferFor(auxiliary: aux.id)
    let b = p.bufferFor(auxiliary: aux.id)
    #expect(a === b)
  }

  @Test func cleanupAuxiliaryBuffersDropsUnknownIDs() {
    let staleID = UUID()
    let aux = AuxiliaryCommand(id: staleID, name: "logs", command: "tail -f log")
    let (p, _) = makeProcess(aux: [aux])
    _ = p.bufferFor(auxiliary: staleID)
    p.auxiliaryCommands = []
    p.cleanupAuxiliaryBuffers()
    let fresh = p.bufferFor(auxiliary: staleID)
    // After cleanup the old buffer is dropped, so a fresh lookup creates a
    // new instance.
    #expect(!fresh.hasContent)
  }

  // MARK: - forceStop (quit path)

  @Test func forceStopUsesSyncOnMainAndAux() {
    let aux = [AuxiliaryCommand(name: "logs", command: "tail -f log")]
    let (p, f) = makeProcess(aux: aux)
    p.start()
    p.forceStop()
    #expect(f.runners[0].stopSyncCount == 1)
    #expect(f.runners[1].stopSyncCount == 1)
    #expect(p.isRunning == false)
  }

  @Test func forceStopWithoutStartIsNoop() {
    let (p, f) = makeProcess()
    p.forceStop()
    #expect(f.runners.count == 0)
    #expect(p.isRunning == false)
  }

  // MARK: - onStateChange

  @Test func onStateChangeFiresOnStartAndStop() {
    let (p, _) = makeProcess()
    var count = 0
    p.onStateChange = { count += 1 }
    p.start()
    p.stop()
    // start fires once (after the runner spawns), stop fires once.
    #expect(count == 2)
  }

  @Test func onStateChangeFiresOnNaturalExit() {
    let (p, f) = makeProcess()
    var count = 0
    p.onStateChange = { count += 1 }
    p.start()
    count = 0
    f.runners[0].fireExit(0)
    #expect(count == 1)
  }

  // MARK: - buffer clear on restart

  @Test func restartingClearsMainBuffer() {
    let (p, f) = makeProcess()
    p.start()
    p.buffer.append("stale output")
    p.stop()
    p.start()
    // Exit message from stop() plus start() clears the buffer, so after start
    // the buffer should not contain the stale output any more.
    let plain = p.buffer.lines.map { $0.spans.map(\.text).joined() }.joined(separator: "\n")
    #expect(!plain.contains("stale output"))
    _ = f  // silence unused warning
  }
}

@MainActor
final class FakeRunnerFactory {
  private(set) var runners: [FakeProcessRunner] = []

  func make() -> FakeProcessRunner {
    let r = FakeProcessRunner()
    runners.append(r)
    return r
  }
}
