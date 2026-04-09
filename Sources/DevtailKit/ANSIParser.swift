import Foundation

// MARK: - Types

public enum ANSIColor: Sendable, Hashable {
  case `default`
  case standard(UInt8)  // 0-7: black, red, green, yellow, blue, magenta, cyan, white
  case bright(UInt8)  // 0-7: bright variants
  case palette(UInt8)  // 0-255
  case rgb(UInt8, UInt8, UInt8)
}

public struct ANSIStyle: Sendable, Hashable {
  public var foreground: ANSIColor = .default
  public var background: ANSIColor = .default
  public var bold: Bool = false
  public var dim: Bool = false
  public var italic: Bool = false
  public var underline: Bool = false
  public var strikethrough: Bool = false

  public init() {}
}

public struct StyledSpan: Sendable {
  public var text: String
  public var style: ANSIStyle

  public init(text: String, style: ANSIStyle) {
    self.text = text
    self.style = style
  }
}

public enum TerminalAction: Sendable {
  case text(StyledSpan)
  case newline
  case carriageReturn
  case eraseLine
  case eraseToEndOfLine
  case cursorUp(Int)
}

// MARK: - Parser

public struct ANSIParser: Sendable {
  public var currentStyle = ANSIStyle()

  public init() {}

  public mutating func parse(_ input: String) -> [TerminalAction] {
    var actions: [TerminalAction] = []
    var textBuf = ""
    var i = input.startIndex

    func flushText() {
      if !textBuf.isEmpty {
        actions.append(.text(StyledSpan(text: textBuf, style: currentStyle)))
        textBuf = ""
      }
    }

    while i < input.endIndex {
      let ch = input[i]

      switch ch {
      case "\u{1B}":  // ESC
        flushText()
        let next = input.index(after: i)
        if next < input.endIndex && input[next] == "[" {
          let csiStart = input.index(after: next)
          if let (action, end) = parseCSI(input, from: csiStart) {
            if let action = action {
              actions.append(action)
            }
            i = end
            continue
          }
        }
        // Skip unrecognized escape — advance past ESC
        i = input.index(after: i)
        continue

      case "\r":
        flushText()
        let next = input.index(after: i)
        if next < input.endIndex && input[next] == "\n" {
          actions.append(.newline)
          i = input.index(after: next)
          continue
        }
        actions.append(.carriageReturn)

      case "\n":
        flushText()
        actions.append(.newline)

      default:
        if let ascii = ch.asciiValue, ascii < 32, ascii != 9 {
          // Skip control characters except tab
        } else {
          textBuf.append(ch)
        }
      }

      i = input.index(after: i)
    }

    flushText()
    return actions
  }

  // MARK: - CSI Parsing

  private mutating func parseCSI(_ input: String, from start: String.Index) -> (TerminalAction?, String.Index)? {
    var paramStr = ""
    var i = start

    while i < input.endIndex {
      let ch = input[i]
      if ch.isLetter || ch == "@" || ch == "`" {
        let result = handleCSI(params: paramStr, final: ch)
        return (result, input.index(after: i))
      } else if ch == ";" || ch == ":" || ch.isNumber || ch == "?" {
        paramStr.append(ch)
      } else {
        return nil
      }
      i = input.index(after: i)
    }

    return nil  // Incomplete sequence
  }

  private mutating func handleCSI(params: String, final: Character) -> TerminalAction? {
    let parts = params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) }

    switch final {
    case "m":  // SGR — Select Graphic Rendition
      applySGR(parts)
      return nil

    case "K":  // Erase in Line
      let mode = parts.first.flatMap({ $0 }) ?? 0
      return mode == 2 ? .eraseLine : .eraseToEndOfLine

    case "A":  // Cursor Up
      let n = parts.first.flatMap({ $0 }) ?? 1
      return .cursorUp(max(1, n))

    default:
      return nil
    }
  }

  // MARK: - SGR

  private mutating func applySGR(_ params: [Int?]) {
    if params.isEmpty || (params.count == 1 && params[0] == nil) {
      currentStyle = ANSIStyle()
      return
    }

    var i = 0
    while i < params.count {
      let code = params[i] ?? 0

      switch code {
      case 0: currentStyle = ANSIStyle()
      case 1: currentStyle.bold = true
      case 2: currentStyle.dim = true
      case 3: currentStyle.italic = true
      case 4: currentStyle.underline = true
      case 9: currentStyle.strikethrough = true
      case 22:
        currentStyle.bold = false
        currentStyle.dim = false
      case 23: currentStyle.italic = false
      case 24: currentStyle.underline = false
      case 29: currentStyle.strikethrough = false

      // Foreground colors
      case 30...37:
        currentStyle.foreground = .standard(UInt8(code - 30))
      case 38:
        if let (color, advance) = parseExtendedColor(params, from: i + 1) {
          currentStyle.foreground = color
          i += advance
        }
      case 39:
        currentStyle.foreground = .default

      // Background colors
      case 40...47:
        currentStyle.background = .standard(UInt8(code - 40))
      case 48:
        if let (color, advance) = parseExtendedColor(params, from: i + 1) {
          currentStyle.background = color
          i += advance
        }
      case 49:
        currentStyle.background = .default

      // Bright foreground
      case 90...97:
        currentStyle.foreground = .bright(UInt8(code - 90))

      // Bright background
      case 100...107:
        currentStyle.background = .bright(UInt8(code - 100))

      default:
        break
      }

      i += 1
    }
  }

  private func parseExtendedColor(_ params: [Int?], from index: Int) -> (ANSIColor, Int)? {
    guard index < params.count else { return nil }
    let mode = params[index] ?? 0

    switch mode {
    case 5:  // 256-color palette
      guard index + 1 < params.count, let n = params[index + 1] else { return nil }
      return (.palette(UInt8(clamping: n)), 2)
    case 2:  // Truecolor RGB
      guard index + 3 < params.count else { return nil }
      let r = UInt8(clamping: params[index + 1] ?? 0)
      let g = UInt8(clamping: params[index + 2] ?? 0)
      let b = UInt8(clamping: params[index + 3] ?? 0)
      return (.rgb(r, g, b), 4)
    default:
      return nil
    }
  }
}
