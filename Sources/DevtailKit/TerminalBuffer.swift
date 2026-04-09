import SwiftUI

// MARK: - Terminal Line

public struct TerminalLine: Sendable {
    public var spans: [StyledSpan]

    public init(spans: [StyledSpan] = []) {
        self.spans = spans
    }

    public var isEmpty: Bool {
        spans.isEmpty || spans.allSatisfy { $0.text.isEmpty }
    }

    public var plainText: String {
        spans.map(\.text).joined()
    }
}

// MARK: - Terminal Buffer

@MainActor
@Observable
public final class TerminalBuffer {
    public private(set) var lines: [TerminalLine] = [TerminalLine()]
    public private(set) var version: Int = 0

    private var parser = ANSIParser()
    private var cursorRow: Int = 0
    private let maxLines: Int

    public init(maxLines: Int = 10_000) {
        self.maxLines = maxLines
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

            case .newline:
                cursorRow += 1
                if cursorRow >= lines.count {
                    lines.append(TerminalLine())
                }

            case .carriageReturn:
                ensureCursorValid()
                lines[cursorRow].spans = []

            case .eraseLine:
                ensureCursorValid()
                lines[cursorRow].spans = []

            case .eraseToEndOfLine:
                ensureCursorValid()
                lines[cursorRow].spans = []

            case .cursorUp(let n):
                cursorRow = max(0, cursorRow - n)
                ensureCursorValid()
                lines[cursorRow].spans = []
            }
        }

        trimLines()
        version += 1
    }

    public func clear() {
        lines = [TerminalLine()]
        cursorRow = 0
        parser = ANSIParser()
        version += 1
    }

    private func ensureCursorValid() {
        while cursorRow >= lines.count {
            lines.append(TerminalLine())
        }
    }

    private func trimLines() {
        if lines.count > maxLines {
            let excess = lines.count - maxLines
            lines.removeFirst(excess)
            cursorRow = max(0, cursorRow - excess)
        }
    }
}
