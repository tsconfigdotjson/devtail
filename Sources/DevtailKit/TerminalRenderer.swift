import AppKit

// Pure, testable logic for incremental terminal rendering.
//
// The view layer (TerminalOutputView.Coordinator) owns an NSTextStorage and a
// small amount of cached state (font, color lookup). Every time the buffer's
// version bumps, it has to decide:
//   - rebuild the entire NSAttributedString, or
//   - append only the bytes that are new since last render?
//
// Moving that decision + the NSAttributedString construction here keeps the
// Coordinator thin and lets us unit-test the state machine directly — which
// matters because an off-by-one in the append path would silently corrupt
// output on fast-streaming processes.

public struct TerminalRenderState: Sendable, Equatable {
  public var firstLineID: Int
  public var lineCount: Int
  public var lastLineSpanCount: Int

  public init(firstLineID: Int = -1, lineCount: Int = 0, lastLineSpanCount: Int = 0) {
    self.firstLineID = firstLineID
    self.lineCount = lineCount
    self.lastLineSpanCount = lastLineSpanCount
  }

  public static let empty = TerminalRenderState()
}

public enum TerminalRenderAction: Sendable, Equatable {
  case fullRebuild
  case appendOnly
}

public enum TerminalRenderer {
  @MainActor
  public static func nextAction(
    prev: TerminalRenderState,
    buffer: TerminalBuffer,
    fontChanged: Bool
  ) -> TerminalRenderAction {
    let firstID = buffer.lines.first?.id ?? -1
    if fontChanged
      || prev.lineCount == 0
      || prev.firstLineID != firstID
      || buffer.lines.count < prev.lineCount
    {
      return .fullRebuild
    }
    return .appendOnly
  }

  @MainActor
  public static func newState(for buffer: TerminalBuffer) -> TerminalRenderState {
    TerminalRenderState(
      firstLineID: buffer.lines.first?.id ?? -1,
      lineCount: buffer.lines.count,
      lastLineSpanCount: buffer.lines.last?.spans.count ?? 0
    )
  }

  @MainActor
  public static func renderFull(
    buffer: TerminalBuffer,
    attributes: (ANSIStyle) -> [NSAttributedString.Key: Any]
  ) -> NSAttributedString {
    let defaults = attributes(ANSIStyle())
    let result = NSMutableAttributedString()
    for (i, line) in buffer.lines.enumerated() {
      for span in line.spans {
        result.append(NSAttributedString(string: span.text, attributes: attributes(span.style)))
      }
      if i < buffer.lines.count - 1 {
        result.append(NSAttributedString(string: "\n", attributes: defaults))
      }
    }
    return result
  }

  @MainActor
  public static func renderAppend(
    prev: TerminalRenderState,
    buffer: TerminalBuffer,
    attributes: (ANSIStyle) -> [NSAttributedString.Key: Any]
  ) -> NSAttributedString {
    guard prev.lineCount > 0 else { return NSAttributedString() }

    let defaults = attributes(ANSIStyle())
    let result = NSMutableAttributedString()
    let oldLastIndex = prev.lineCount - 1

    // Extend the previously-last line with any newly added spans.
    let oldLastLine = buffer.lines[oldLastIndex]
    if oldLastLine.spans.count > prev.lastLineSpanCount {
      for span in oldLastLine.spans[prev.lastLineSpanCount...] {
        result.append(NSAttributedString(string: span.text, attributes: attributes(span.style)))
      }
    }

    // Append any new lines that appeared after the old last line.
    for i in prev.lineCount..<buffer.lines.count {
      result.append(NSAttributedString(string: "\n", attributes: defaults))
      for span in buffer.lines[i].spans {
        result.append(NSAttributedString(string: span.text, attributes: attributes(span.style)))
      }
    }

    return result
  }
}
