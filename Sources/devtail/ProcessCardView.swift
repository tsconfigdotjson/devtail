import DevtailKit
import SwiftUI

struct ProcessCardView: View {
  let process: DevProcess
  var onSelect: () -> Void
  var onToggle: () -> Void
  var onDelete: () -> Void

  @State private var isHovered = false

  private func popOutButton(buffer: TerminalBuffer, title: String) -> some View {
    Button {
      PopOutWindowManager.shared.openWindow(buffer: buffer, title: title)
    } label: {
      Image(systemName: "arrow.up.forward.app")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(4)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Pop out")
  }

  var body: some View {
    Button(action: onSelect) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Text(process.name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          if process.isRunning, !process.detectedPorts.isEmpty {
            PortBadges(ports: process.detectedPorts)
          }

          StatusDot(isRunning: process.isRunning)
        }

        if process.isRunning, process.buffer.hasContent {
          TerminalBlock {
            TerminalPreviewText(
              buffer: process.buffer,
              lineLimit: 3,
              fontSize: 10
            )
          }
          .overlay(alignment: .topTrailing) {
            popOutButton(buffer: process.buffer, title: process.name)
          }
        }

        if process.isRunning {
          ForEach(process.auxiliaryCommands) { aux in
            let auxBuf = process.bufferFor(auxiliary: aux.id)
            VStack(alignment: .leading, spacing: 2) {
              Text(aux.name.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(0.5)

              TerminalBlock {
                if auxBuf.hasContent {
                  TerminalPreviewText(
                    buffer: auxBuf,
                    lineLimit: 2,
                    fontSize: 10
                  )
                } else {
                  Text(aux.command)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              .overlay(alignment: .topTrailing) {
                popOutButton(
                  buffer: auxBuf,
                  title: "\(process.name) — \(aux.name)"
                )
              }
            }
          }
        }
      }
      .padding(12)
      .liquidGlassBackground(
        in: RoundedRectangle(cornerRadius: 10, style: .continuous),
        fallback: AnyShapeStyle(.thinMaterial)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(
            isHovered
              ? Color.accentColor.opacity(0.35)
              : Color(nsColor: .separatorColor).opacity(0.6),
            lineWidth: 0.5
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(PressableCardButtonStyle())
    .onHover { hovering in
      isHovered = hovering
    }
    .contextMenu {
      Button(process.isRunning ? "Stop Process" : "Start Process") {
        onToggle()
      }
      Divider()
      Button("Delete", role: .destructive) {
        onDelete()
      }
    }
  }
}

enum PortFormatter {
  static func label(for port: Int) -> String { ":" + String(port) }
  static func overflow(for extra: Int) -> String { "+" + String(extra) }
}

struct PortBadges: View {
  let ports: [Int]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(ports.prefix(3), id: \.self) { port in
        Text(PortFormatter.label(for: port))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(
            Capsule()
              .fill(Color.accentColor.opacity(0.12))
          )
      }
      if ports.count > 3 {
        Text(PortFormatter.overflow(for: ports.count - 3))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.tertiary)
      }
    }
  }
}

struct StatusDot: View {
  let isRunning: Bool

  var body: some View {
    Circle()
      .fill(isRunning ? Color.green : Color(nsColor: .separatorColor))
      .frame(width: 10, height: 10)
      .shadow(color: isRunning ? .green.opacity(0.6) : .clear, radius: 4)
  }
}

struct TerminalBlock<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .liquidGlassBackground(
        in: RoundedRectangle(cornerRadius: 6, style: .continuous),
        fallback: AnyShapeStyle(.ultraThinMaterial)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
      )
  }
}

extension View {
  @ViewBuilder
  func liquidGlassBackground<S: Shape>(in shape: S, fallback: AnyShapeStyle) -> some View {
    if #available(macOS 26.0, *) {
      self.glassEffect(.clear, in: shape)
    } else {
      self.background(shape.fill(fallback))
    }
  }
}

struct PressableCardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.75 : 1)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}
