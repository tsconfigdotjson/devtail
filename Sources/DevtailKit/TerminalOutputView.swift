import SwiftUI

// MARK: - Full Output View (for detail/scroll)

public struct TerminalOutputView: View {
    let buffer: TerminalBuffer
    var fontSize: CGFloat

    public init(buffer: TerminalBuffer, fontSize: CGFloat = 11) {
        self.buffer = buffer
        self.fontSize = fontSize
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(buffer.lines.enumerated()), id: \.offset) { index, line in
                        lineView(line)
                            .id(index)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: buffer.version) {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(buffer.lines.count - 1, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: TerminalLine) -> some View {
        if line.isEmpty {
            Text(" ")
                .font(.system(size: fontSize, design: .monospaced))
        } else {
            Text(attributedString(for: line))
                .font(.system(size: fontSize, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func attributedString(for line: TerminalLine) -> AttributedString {
        var result = AttributedString()
        for span in line.spans {
            var attr = AttributedString(span.text)
            applyStyle(span.style, to: &attr)
            result.append(attr)
        }
        return result
    }

    private func applyStyle(_ style: ANSIStyle, to attr: inout AttributedString) {
        if style.foreground != .default {
            attr.foregroundColor = style.foreground.swiftUIColor
        }
        if style.bold {
            attr.font = .system(size: fontSize, weight: .bold, design: .monospaced)
        }
        if style.dim {
            if style.foreground == .default {
                attr.foregroundColor = .secondary
            }
        }
        if style.underline {
            attr.underlineStyle = .single
        }
        if style.strikethrough {
            attr.strikethroughStyle = .single
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
            return Self.standardColor(n)
        case .bright(let n):
            return Self.brightColor(n)
        case .palette(let n):
            return Self.paletteColor(n)
        case .rgb(let r, let g, let b):
            return Color(
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255
            )
        }
    }

    private static func standardColor(_ index: UInt8) -> Color {
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

    private static func brightColor(_ index: UInt8) -> Color {
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

    private static func paletteColor(_ index: UInt8) -> Color {
        let n = Int(index)
        if n < 8 {
            return standardColor(index)
        } else if n < 16 {
            return brightColor(UInt8(n - 8))
        } else if n < 232 {
            // 6×6×6 color cube
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
            // Grayscale ramp (232-255)
            let gray = Double((n - 232) * 10 + 8) / 255
            return Color(red: gray, green: gray, blue: gray)
        }
    }
}
