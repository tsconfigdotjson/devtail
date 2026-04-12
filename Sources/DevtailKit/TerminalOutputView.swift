import AppKit
import SwiftUI

public struct TerminalOutputView: View {
  let buffer: TerminalBuffer
  var fontSize: CGFloat

  public init(buffer: TerminalBuffer, fontSize: CGFloat = 11) {
    self.buffer = buffer
    self.fontSize = fontSize
  }

  public var body: some View {
    let _ = buffer.version
    TerminalNSView(buffer: buffer, version: buffer.version, fontSize: fontSize)
  }
}

private struct TerminalNSView: NSViewRepresentable {
  let buffer: TerminalBuffer
  let version: Int
  let fontSize: CGFloat

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    textView.textContainerInset = NSSize(width: 8, height: 8)
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isRichText = false
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.lineFragmentPadding = 4
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.drawsBackground = false
    scrollView.autohidesScrollers = true

    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.update(buffer: buffer, fontSize: fontSize)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  @MainActor
  class Coordinator {
    weak var textView: NSTextView?

    private var cachedFontSize: CGFloat = 0
    private var regularFont: NSFont?
    private var boldFont: NSFont?
    private var colorCache: [ANSIColor: NSColor] = [:]
    private var isFirstUpdate = true

    // Incremental render state. We append to textStorage instead of rebuilding
    // on every version change, which is O(new spans) instead of O(all spans).
    private var renderedFirstLineID: Int = -1
    private var renderedLineCount: Int = 0
    private var renderedLastLineSpanCount: Int = 0

    func update(buffer: TerminalBuffer, fontSize: CGFloat) {
      guard let textView else { return }
      guard let storage = textView.textStorage else { return }
      guard let scrollView = textView.enclosingScrollView else { return }

      let clipView = scrollView.contentView
      let maxScrollY = max(textView.frame.height - clipView.bounds.height, 0)
      let isAtBottom = isFirstUpdate || clipView.bounds.origin.y >= maxScrollY - 20

      let fontChanged = fontSize != cachedFontSize
      ensureFontCache(fontSize: fontSize)

      let currentFirstID = buffer.lines.first?.id ?? -1
      let trimmedOrCleared =
        renderedFirstLineID != currentFirstID
        || buffer.lines.count < renderedLineCount

      storage.beginEditing()
      if fontChanged || trimmedOrCleared || renderedLineCount == 0 {
        storage.setAttributedString(buildFullAttributedString(buffer: buffer))
      } else {
        appendIncremental(buffer: buffer, storage: storage)
      }
      storage.endEditing()

      renderedFirstLineID = currentFirstID
      renderedLineCount = buffer.lines.count
      renderedLastLineSpanCount = buffer.lines.last?.spans.count ?? 0

      if isAtBottom {
        if isFirstUpdate {
          isFirstUpdate = false
          DispatchQueue.main.async { [weak textView] in
            guard let textView, let sv = textView.enclosingScrollView else { return }
            sv.layoutSubtreeIfNeeded()
            textView.scrollToEndOfDocument(nil)
          }
        } else {
          textView.scrollToEndOfDocument(nil)
        }
      }
    }

    private func ensureFontCache(fontSize: CGFloat) {
      guard fontSize != cachedFontSize else { return }
      cachedFontSize = fontSize
      regularFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
      boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
      colorCache.removeAll()
    }

    private func resolveColor(_ color: ANSIColor) -> NSColor {
      if let cached = colorCache[color] { return cached }
      let resolved = color.nsColor
      colorCache[color] = resolved
      return resolved
    }

    private var defaultAttrs: [NSAttributedString.Key: Any] {
      [.font: regularFont!, .foregroundColor: NSColor.labelColor]
    }

    private func attributes(for style: ANSIStyle) -> [NSAttributedString.Key: Any] {
      var attrs = defaultAttrs
      if style.foreground != .default {
        attrs[.foregroundColor] = resolveColor(style.foreground)
      }
      if style.bold {
        attrs[.font] = boldFont!
      }
      if style.dim, style.foreground == .default {
        attrs[.foregroundColor] = NSColor.secondaryLabelColor
      }
      if style.underline {
        attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
      }
      if style.strikethrough {
        attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
      }
      return attrs
    }

    private func buildFullAttributedString(buffer: TerminalBuffer) -> NSAttributedString {
      let result = NSMutableAttributedString()
      for (i, line) in buffer.lines.enumerated() {
        for span in line.spans {
          result.append(NSAttributedString(string: span.text, attributes: attributes(for: span.style)))
        }
        if i < buffer.lines.count - 1 {
          result.append(NSAttributedString(string: "\n", attributes: defaultAttrs))
        }
      }
      return result
    }

    private func appendIncremental(buffer: TerminalBuffer, storage: NSTextStorage) {
      let oldCount = renderedLineCount
      guard oldCount > 0 else { return }

      let oldLastIndex = oldCount - 1
      let append = NSMutableAttributedString()

      // Extend the previously-last line with any new spans.
      let oldLastLine = buffer.lines[oldLastIndex]
      if oldLastLine.spans.count > renderedLastLineSpanCount {
        for span in oldLastLine.spans[renderedLastLineSpanCount...] {
          append.append(NSAttributedString(string: span.text, attributes: attributes(for: span.style)))
        }
      }

      // Append any new lines after the old last line.
      for i in oldCount..<buffer.lines.count {
        append.append(NSAttributedString(string: "\n", attributes: defaultAttrs))
        for span in buffer.lines[i].spans {
          append.append(NSAttributedString(string: span.text, attributes: attributes(for: span.style)))
        }
      }

      if append.length > 0 {
        storage.append(append)
      }
    }
  }
}

public struct TerminalPreviewText: View {
  let buffer: TerminalBuffer
  var lineLimit: Int
  var fontSize: CGFloat

  public init(buffer: TerminalBuffer, lineLimit: Int = 3, fontSize: CGFloat = 10) {
    self.buffer = buffer
    self.lineLimit = lineLimit
    self.fontSize = fontSize
  }

  public var body: some View {
    Text(previewAttributedString())
      .font(.system(size: fontSize, design: .monospaced))
      .lineLimit(lineLimit)
      .truncationMode(.tail)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func previewAttributedString() -> AttributedString {
    let nonEmptyLines = buffer.lines.filter { !$0.isEmpty }
    let lastLines = nonEmptyLines.suffix(lineLimit)

    var result = AttributedString()
    for (i, line) in lastLines.enumerated() {
      for span in line.spans {
        var attr = AttributedString(span.text)
        if span.style.foreground != .default {
          attr.foregroundColor = span.style.foreground.swiftUIColor
        }
        if span.style.bold {
          attr.font = .system(size: fontSize, weight: .bold, design: .monospaced)
        }
        if span.style.dim, span.style.foreground == .default {
          attr.foregroundColor = .secondary
        }
        if span.style.underline {
          attr.underlineStyle = .single
        }
        result.append(attr)
      }
      if i < lastLines.count - 1 {
        result.append(AttributedString("\n"))
      }
    }

    if result.characters.isEmpty {
      var placeholder = AttributedString("Waiting for output...")
      placeholder.foregroundColor = .secondary
      return placeholder
    }

    return result
  }
}

extension ANSIColor {
  // Shared palette math. Returns 0-1 RGB components; SwiftUI + AppKit wrappers
  // consume this to avoid ~80 lines of duplicated switch statements.
  fileprivate var rgbComponents: (r: Double, g: Double, b: Double)? {
    switch self {
    case .default:
      return nil
    case .standard(let n):
      return Self.standardRGB(n)
    case .bright(let n):
      return Self.brightRGB(n)
    case .palette(let n):
      return Self.paletteRGB(n)
    case .rgb(let r, let g, let b):
      return (Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
  }

  public var swiftUIColor: Color {
    guard let rgb = rgbComponents else { return .primary }
    return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
  }

  public var nsColor: NSColor {
    guard let rgb = rgbComponents else { return .labelColor }
    return NSColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
  }

  private static func standardRGB(_ index: UInt8) -> (Double, Double, Double) {
    switch index {
    case 0: (0.2, 0.2, 0.2)
    case 1: (0.85, 0.25, 0.25)
    case 2: (0.25, 0.75, 0.35)
    case 3: (0.85, 0.75, 0.25)
    case 4: (0.35, 0.45, 0.9)
    case 5: (0.8, 0.35, 0.8)
    case 6: (0.3, 0.8, 0.85)
    case 7: (0.8, 0.8, 0.8)
    default: (1, 1, 1)
    }
  }

  private static func brightRGB(_ index: UInt8) -> (Double, Double, Double) {
    switch index {
    case 0: (0.5, 0.5, 0.5)
    case 1: (1.0, 0.35, 0.35)
    case 2: (0.35, 0.95, 0.45)
    case 3: (1.0, 0.95, 0.35)
    case 4: (0.45, 0.55, 1.0)
    case 5: (0.95, 0.45, 0.95)
    case 6: (0.4, 0.95, 1.0)
    case 7: (1.0, 1.0, 1.0)
    default: (1, 1, 1)
    }
  }

  private static func paletteRGB(_ index: UInt8) -> (Double, Double, Double) {
    let n = Int(index)
    if n < 8 {
      return standardRGB(index)
    } else if n < 16 {
      return brightRGB(UInt8(n - 8))
    } else if n < 232 {
      let adjusted = n - 16
      let r = adjusted / 36
      let g = (adjusted % 36) / 6
      let b = adjusted % 6
      return (
        r == 0 ? 0 : Double(r * 40 + 55) / 255,
        g == 0 ? 0 : Double(g * 40 + 55) / 255,
        b == 0 ? 0 : Double(b * 40 + 55) / 255
      )
    } else {
      let gray = Double((n - 232) * 10 + 8) / 255
      return (gray, gray, gray)
    }
  }
}
