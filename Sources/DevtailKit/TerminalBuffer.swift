import SwiftUI

public struct TerminalLine: Sendable, Identifiable {
  public let id: Int
  public var spans: [StyledSpan]

  public init(id: Int, spans: [StyledSpan] = []) {
    self.id = id
    self.spans = spans
  }

  public var isEmpty: Bool {
    spans.isEmpty || spans.allSatisfy { $0.text.isEmpty }
  }
}

@MainActor
@Observable
public final class TerminalBuffer {
  public private(set) var lines: [TerminalLine] = []
  public private(set) var version: Int = 0

  private var parser = ANSIParser()
  private var cursorRow: Int = 0
  private var nextLineID: Int = 0
  private let maxLines: Int
  private let maxBytes: Int
  private var approxByteCount: Int = 0

  // A styled span's overhead (per-span allocation, style struct) is not free;
  // approximate each span as text bytes + 32 to bound memory on styled streams.
  private static let spanOverheadBytes = 32

  public init(maxLines: Int = 2000, maxBytes: Int = 2_000_000) {
    self.maxLines = maxLines
    self.maxBytes = maxBytes
    lines.append(makeLine())
  }

  public var hasContent: Bool {
    lines.count > 1 || !(lines.first?.isEmpty ?? true)
  }

  public func append(_ data: String) {
    let actions = parser.parse(data)

    for action in actions {
      switch action {
      case .text(let span):
        ensureCursorValid()
        lines[cursorRow].spans.append(span)
        approxByteCount += Self.byteWeight(of: span)

      case .newline:
        cursorRow += 1
        if cursorRow >= lines.count {
          lines.append(makeLine())
        }

      case .carriageReturn:
        ensureCursorValid()
        approxByteCount -= Self.byteWeight(of: lines[cursorRow])
        lines[cursorRow].spans = []

      case .eraseLine:
        ensureCursorValid()
        approxByteCount -= Self.byteWeight(of: lines[cursorRow])
        lines[cursorRow].spans = []

      case .eraseToEndOfLine:
        ensureCursorValid()
        approxByteCount -= Self.byteWeight(of: lines[cursorRow])
        lines[cursorRow].spans = []

      case .cursorUp(let n):
        cursorRow = max(0, cursorRow - n)
        ensureCursorValid()
        approxByteCount -= Self.byteWeight(of: lines[cursorRow])
        lines[cursorRow].spans = []
      }
    }

    trimLines()
    version += 1
  }

  public func clear() {
    lines = [makeLine()]
    cursorRow = 0
    approxByteCount = 0
    parser = ANSIParser()
    version += 1
  }

  private func makeLine() -> TerminalLine {
    let line = TerminalLine(id: nextLineID)
    nextLineID += 1
    return line
  }

  private func ensureCursorValid() {
    while cursorRow >= lines.count {
      lines.append(makeLine())
    }
  }

  private func trimLines() {
    while (lines.count > maxLines || approxByteCount > maxBytes) && lines.count > 1 {
      let removed = lines.removeFirst()
      approxByteCount -= Self.byteWeight(of: removed)
      cursorRow = max(0, cursorRow - 1)
    }
  }

  private static func byteWeight(of span: StyledSpan) -> Int {
    span.text.utf8.count + spanOverheadBytes
  }

  private static func byteWeight(of line: TerminalLine) -> Int {
    line.spans.reduce(0) { $0 + byteWeight(of: $1) }
  }
}
