import AppKit
import Testing

@testable import DevtailKit

// Contract: any sequence of append-path updates must produce the same string
// content as a single full rebuild. Property sweep below guards against silent
// divergence on fast-streaming processes.

@MainActor
struct TerminalRendererTests {

  private static func testAttrs(_ style: ANSIStyle) -> [NSAttributedString.Key: Any] {
    [
      .font: NSFont.monospacedSystemFont(ofSize: 11, weight: style.bold ? .bold : .regular),
      .foregroundColor: NSColor.labelColor,
    ]
  }

  private func driveIncremental(ops: [String], buffer: TerminalBuffer) -> String {
    let storage = NSTextStorage()
    var state = TerminalRenderState.empty

    for op in ops {
      buffer.append(op)
      let action = TerminalRenderer.nextAction(prev: state, buffer: buffer, fontChanged: false)
      switch action {
      case .fullRebuild:
        let full = TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs)
        storage.setAttributedString(full)
      case .appendOnly:
        let delta = TerminalRenderer.renderAppend(
          prev: state, buffer: buffer, attributes: Self.testAttrs)
        storage.append(delta)
      }
      state = TerminalRenderer.newState(for: buffer)
    }
    return storage.string
  }

  // MARK: - nextAction decision table

  @Test func firstRenderAlwaysFullRebuild() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let action = TerminalRenderer.nextAction(
      prev: .empty, buffer: buffer, fontChanged: false)
    #expect(action == .fullRebuild)
  }

  @Test func fontChangeForcesFullRebuild() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    let action = TerminalRenderer.nextAction(
      prev: state, buffer: buffer, fontChanged: true)
    #expect(action == .fullRebuild)
  }

  @Test func steadyStateIsAppendOnly() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append(" world")
    let action = TerminalRenderer.nextAction(
      prev: state, buffer: buffer, fontChanged: false)
    #expect(action == .appendOnly)
  }

  @Test func clearTriggersFullRebuild() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.clear()
    buffer.append("fresh")
    let action = TerminalRenderer.nextAction(
      prev: state, buffer: buffer, fontChanged: false)
    #expect(action == .fullRebuild)
  }

  @Test func trimTriggersFullRebuild() {
    let buffer = TerminalBuffer(maxLines: 3)
    buffer.append("a\nb\nc")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append("\nd\ne")
    let action = TerminalRenderer.nextAction(
      prev: state, buffer: buffer, fontChanged: false)
    #expect(action == .fullRebuild)
  }

  @Test func lineCountShrinkWithoutIDChangeStillRebuilds() {
    let buffer = TerminalBuffer()
    buffer.append("a\nb\nc")
    let firstID = buffer.lines.first!.id
    let prev = TerminalRenderState(firstLineID: firstID, lineCount: 5, lastLineSpanCount: 0)
    let action = TerminalRenderer.nextAction(prev: prev, buffer: buffer, fontChanged: false)
    #expect(action == .fullRebuild)
  }

  // MARK: - newState

  @Test func newStateReflectsCurrentBuffer() {
    let buffer = TerminalBuffer()
    buffer.append("hello\nworld")
    let state = TerminalRenderer.newState(for: buffer)
    #expect(state.lineCount == 2)
    #expect(state.firstLineID == buffer.lines.first!.id)
    #expect(state.lastLineSpanCount == 1)
  }

  @Test func newStateOnEmptyBufferIsSafe() {
    let buffer = TerminalBuffer()
    let state = TerminalRenderer.newState(for: buffer)
    #expect(state.lineCount == 1)
    #expect(state.lastLineSpanCount == 0)
  }

  // MARK: - renderFull content

  @Test func renderFullJoinsLinesWithNewlines() {
    let buffer = TerminalBuffer()
    buffer.append("a\nb\nc")
    let result = TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs)
    #expect(result.string == "a\nb\nc")
  }

  @Test func renderFullOmitsTrailingNewline() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let result = TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs)
    #expect(result.string == "hello")
  }

  @Test func renderFullEmptyLinesAreEmpty() {
    let buffer = TerminalBuffer()
    buffer.append("\n\n\n")
    let result = TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs)
    #expect(result.string == "\n\n\n")
  }

  @Test func renderFullWithANSIColors() {
    let buffer = TerminalBuffer()
    buffer.append("\u{1B}[31mred\u{1B}[0m plain")
    let result = TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs)
    #expect(result.string == "red plain")
  }

  // MARK: - renderAppend content

  @Test func renderAppendEmptyWhenNothingChanged() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    let delta = TerminalRenderer.renderAppend(
      prev: state, buffer: buffer, attributes: Self.testAttrs)
    #expect(delta.length == 0)
  }

  @Test func renderAppendExtendsLastLine() {
    let buffer = TerminalBuffer()
    buffer.append("hel")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append("lo")
    let delta = TerminalRenderer.renderAppend(
      prev: state, buffer: buffer, attributes: Self.testAttrs)
    #expect(delta.string == "lo")
  }

  @Test func renderAppendAddsNewLines() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append("\nworld")
    let delta = TerminalRenderer.renderAppend(
      prev: state, buffer: buffer, attributes: Self.testAttrs)
    #expect(delta.string == "\nworld")
  }

  @Test func renderAppendExtendsLastLineThenAddsMore() {
    let buffer = TerminalBuffer()
    buffer.append("hel")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append("lo\nworld")
    let delta = TerminalRenderer.renderAppend(
      prev: state, buffer: buffer, attributes: Self.testAttrs)
    #expect(delta.string == "lo\nworld")
  }

  @Test func renderAppendWithNewEmptyLine() {
    let buffer = TerminalBuffer()
    buffer.append("hello")
    let state = TerminalRenderer.newState(for: buffer)
    buffer.append("\n")
    let delta = TerminalRenderer.renderAppend(
      prev: state, buffer: buffer, attributes: Self.testAttrs)
    #expect(delta.string == "\n")
  }

  // MARK: - equivalence (the big one)

  @Test func incrementalMatchesFullForCharacterStream() {
    let incrementalBuffer = TerminalBuffer()
    let fullBuffer = TerminalBuffer()
    let chunks = ["h", "e", "l", "l", "o", " ", "w", "o", "r", "l", "d"]

    let incremental = driveIncremental(ops: chunks, buffer: incrementalBuffer)
    for chunk in chunks { fullBuffer.append(chunk) }
    let full = TerminalRenderer.renderFull(buffer: fullBuffer, attributes: Self.testAttrs).string

    #expect(incremental == full)
    #expect(incremental == "hello world")
  }

  @Test func incrementalMatchesFullAcrossNewlines() {
    let a = TerminalBuffer()
    let b = TerminalBuffer()
    let ops = ["line1\n", "line2\n", "line3"]

    let inc = driveIncremental(ops: ops, buffer: a)
    for op in ops { b.append(op) }
    let full = TerminalRenderer.renderFull(buffer: b, attributes: Self.testAttrs).string

    #expect(inc == full)
    #expect(inc == "line1\nline2\nline3")
  }

  @Test func incrementalMatchesFullWithANSIColors() {
    let a = TerminalBuffer()
    let b = TerminalBuffer()
    let ops = [
      "\u{1B}[31m",
      "red",
      "\u{1B}[0m",
      " ",
      "\u{1B}[1;34m",
      "bold-blue\n",
      "plain",
    ]

    let inc = driveIncremental(ops: ops, buffer: a)
    for op in ops { b.append(op) }
    let full = TerminalRenderer.renderFull(buffer: b, attributes: Self.testAttrs).string

    #expect(inc == full)
    #expect(inc == "red bold-blue\nplain")
  }

  @Test func incrementalHandlesCarriageReturnViaRebuild() {
    // CR clears the current line's spans, which violates the "spans only grow"
    // assumption of the append path. Pin that the final characters match.
    let a = TerminalBuffer()
    let b = TerminalBuffer()
    let ops = ["progress 10%\r", "progress 50%\r", "progress 100%\ndone"]

    let inc = driveIncremental(ops: ops, buffer: a)
    for op in ops { b.append(op) }
    let full = TerminalRenderer.renderFull(buffer: b, attributes: Self.testAttrs).string

    #expect(inc == full)
  }

  @Test func incrementalHandlesClearMidStream() {
    let buffer = TerminalBuffer()
    let storage = NSTextStorage()
    var state = TerminalRenderState.empty

    for op in ["hello", " world", "\nmore"] {
      buffer.append(op)
      let action = TerminalRenderer.nextAction(prev: state, buffer: buffer, fontChanged: false)
      switch action {
      case .fullRebuild:
        storage.setAttributedString(
          TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs))
      case .appendOnly:
        storage.append(
          TerminalRenderer.renderAppend(prev: state, buffer: buffer, attributes: Self.testAttrs))
      }
      state = TerminalRenderer.newState(for: buffer)
    }

    buffer.clear()
    buffer.append("fresh\nstart")
    let action = TerminalRenderer.nextAction(prev: state, buffer: buffer, fontChanged: false)
    #expect(action == .fullRebuild)
    storage.setAttributedString(TerminalRenderer.renderFull(buffer: buffer, attributes: Self.testAttrs))

    #expect(storage.string == "fresh\nstart")
  }

  @Test func incrementalHandlesTrimMidStream() {
    let incremental = TerminalBuffer(maxLines: 4)
    let full = TerminalBuffer(maxLines: 4)
    let ops = ["a\n", "b\n", "c\n", "d\n", "e\n", "f"]

    let incText = driveIncremental(ops: ops, buffer: incremental)
    for op in ops { full.append(op) }
    let fullText = TerminalRenderer.renderFull(buffer: full, attributes: Self.testAttrs).string

    #expect(incText == fullText)
    #expect(incremental.lines.count <= 4)
  }

  @Test func randomOpSequencesStayEquivalent() {
    var rng = SystemRandomNumberGenerator()
    let candidates: [String] = [
      "a", "b", "c", " ", "x", "y",
      "\n", "\n\n",
      "\u{1B}[31m", "\u{1B}[32m", "\u{1B}[0m",
      "\u{1B}[1m",
      "longer text chunk ",
      "",
    ]

    for trial in 0..<25 {
      let incremental = TerminalBuffer(maxLines: 50)
      let full = TerminalBuffer(maxLines: 50)
      let opCount = Int.random(in: 5...40, using: &rng)
      var ops: [String] = []
      for _ in 0..<opCount {
        ops.append(candidates.randomElement(using: &rng)!)
      }

      let incText = driveIncremental(ops: ops, buffer: incremental)
      for op in ops { full.append(op) }
      let fullText = TerminalRenderer.renderFull(buffer: full, attributes: Self.testAttrs).string

      #expect(
        incText == fullText,
        "Mismatch on trial \(trial) with ops: \(ops)"
      )
    }
  }
}
