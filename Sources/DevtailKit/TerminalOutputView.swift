import SwiftUI
import AppKit

// MARK: - Full Output View (NSTextView-backed for performance + selection)

public struct TerminalOutputView: View {
    let buffer: TerminalBuffer
    var fontSize: CGFloat

    public init(buffer: TerminalBuffer, fontSize: CGFloat = 11) {
        self.buffer = buffer
        self.fontSize = fontSize
    }

    public var body: some View {
        // Reading version registers @Observable tracking
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

        func update(buffer: TerminalBuffer, fontSize: CGFloat) {
            guard let textView else { return }
            guard let storage = textView.textStorage else { return }

            let attrStr = buildAttributedString(buffer: buffer, fontSize: fontSize)

            storage.beginEditing()
            storage.setAttributedString(attrStr)
            storage.endEditing()

            // Auto-scroll to bottom
            textView.scrollToEndOfDocument(nil)
        }

        private func buildAttributedString(buffer: TerminalBuffer, fontSize: CGFloat) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            let defaultAttrs: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .foregroundColor: NSColor.labelColor
            ]

            for (i, line) in buffer.lines.enumerated() {
                if line.isEmpty {
                    result.append(NSAttributedString(string: " ", attributes: defaultAttrs))
                } else {
                    for span in line.spans {
                        var attrs = defaultAttrs
                        let style = span.style

                        if style.foreground != .default {
                            attrs[.foregroundColor] = style.foreground.nsColor
                        }
                        if style.bold {
                            attrs[.font] = boldFont
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

                        result.append(NSAttributedString(string: span.text, attributes: attrs))
                    }
                }
                if i < buffer.lines.count - 1 {
                    result.append(NSAttributedString(string: "\n", attributes: defaultAttrs))
                }
            }
            return result
        }
    }
}

// MARK: - Preview Text (for cards, compact display)

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

// MARK: - ANSIColor → SwiftUI Color

extension ANSIColor {
    public var swiftUIColor: Color {
        switch self {
        case .default:
            return .primary
        case .standard(let n):
            return Self.standardSwiftUIColor(n)
        case .bright(let n):
            return Self.brightSwiftUIColor(n)
        case .palette(let n):
            return Self.paletteSwiftUIColor(n)
        case .rgb(let r, let g, let b):
            return Color(
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255
            )
        }
    }

    private static func standardSwiftUIColor(_ index: UInt8) -> Color {
        switch index {
        case 0: Color(red: 0.2, green: 0.2, blue: 0.2)
        case 1: Color(red: 0.85, green: 0.25, blue: 0.25)
        case 2: Color(red: 0.25, green: 0.75, blue: 0.35)
        case 3: Color(red: 0.85, green: 0.75, blue: 0.25)
        case 4: Color(red: 0.35, green: 0.45, blue: 0.9)
        case 5: Color(red: 0.8, green: 0.35, blue: 0.8)
        case 6: Color(red: 0.3, green: 0.8, blue: 0.85)
        case 7: Color(red: 0.8, green: 0.8, blue: 0.8)
        default: .primary
        }
    }

    private static func brightSwiftUIColor(_ index: UInt8) -> Color {
        switch index {
        case 0: Color(red: 0.5, green: 0.5, blue: 0.5)
        case 1: Color(red: 1.0, green: 0.35, blue: 0.35)
        case 2: Color(red: 0.35, green: 0.95, blue: 0.45)
        case 3: Color(red: 1.0, green: 0.95, blue: 0.35)
        case 4: Color(red: 0.45, green: 0.55, blue: 1.0)
        case 5: Color(red: 0.95, green: 0.45, blue: 0.95)
        case 6: Color(red: 0.4, green: 0.95, blue: 1.0)
        case 7: Color(red: 1.0, green: 1.0, blue: 1.0)
        default: .primary
        }
    }

    private static func paletteSwiftUIColor(_ index: UInt8) -> Color {
        let n = Int(index)
        if n < 8 {
            return standardSwiftUIColor(index)
        } else if n < 16 {
            return brightSwiftUIColor(UInt8(n - 8))
        } else if n < 232 {
            let adjusted = n - 16
            let r = adjusted / 36
            let g = (adjusted % 36) / 6
            let b = adjusted % 6
            return Color(
                red: r == 0 ? 0 : Double(r * 40 + 55) / 255,
                green: g == 0 ? 0 : Double(g * 40 + 55) / 255,
                blue: b == 0 ? 0 : Double(b * 40 + 55) / 255
            )
        } else {
            let gray = Double((n - 232) * 10 + 8) / 255
            return Color(red: gray, green: gray, blue: gray)
        }
    }
}

// MARK: - ANSIColor → NSColor

extension ANSIColor {
    public var nsColor: NSColor {
        switch self {
        case .default:
            return .labelColor
        case .standard(let n):
            return Self.standardNSColor(n)
        case .bright(let n):
            return Self.brightNSColor(n)
        case .palette(let n):
            return Self.paletteNSColor(n)
        case .rgb(let r, let g, let b):
            return NSColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1
            )
        }
    }

    private static func standardNSColor(_ index: UInt8) -> NSColor {
        switch index {
        case 0: NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        case 1: NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1)
        case 2: NSColor(red: 0.25, green: 0.75, blue: 0.35, alpha: 1)
        case 3: NSColor(red: 0.85, green: 0.75, blue: 0.25, alpha: 1)
        case 4: NSColor(red: 0.35, green: 0.45, blue: 0.9, alpha: 1)
        case 5: NSColor(red: 0.8, green: 0.35, blue: 0.8, alpha: 1)
        case 6: NSColor(red: 0.3, green: 0.8, blue: 0.85, alpha: 1)
        case 7: NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        default: .labelColor
        }
    }

    private static func brightNSColor(_ index: UInt8) -> NSColor {
        switch index {
        case 0: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case 1: NSColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1)
        case 2: NSColor(red: 0.35, green: 0.95, blue: 0.45, alpha: 1)
        case 3: NSColor(red: 1.0, green: 0.95, blue: 0.35, alpha: 1)
        case 4: NSColor(red: 0.45, green: 0.55, blue: 1.0, alpha: 1)
        case 5: NSColor(red: 0.95, green: 0.45, blue: 0.95, alpha: 1)
        case 6: NSColor(red: 0.4, green: 0.95, blue: 1.0, alpha: 1)
        case 7: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        default: .labelColor
        }
    }

    private static func paletteNSColor(_ index: UInt8) -> NSColor {
        let n = Int(index)
        if n < 8 {
            return standardNSColor(index)
        } else if n < 16 {
            return brightNSColor(UInt8(n - 8))
        } else if n < 232 {
            let adjusted = n - 16
            let r = adjusted / 36
            let g = (adjusted % 36) / 6
            let b = adjusted % 6
            return NSColor(
                red: r == 0 ? 0 : CGFloat(r * 40 + 55) / 255,
                green: g == 0 ? 0 : CGFloat(g * 40 + 55) / 255,
                blue: b == 0 ? 0 : CGFloat(b * 40 + 55) / 255,
                alpha: 1
            )
        } else {
            let gray = CGFloat((n - 232) * 10 + 8) / 255
            return NSColor(red: gray, green: gray, blue: gray, alpha: 1)
        }
    }
}
