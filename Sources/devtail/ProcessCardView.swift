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
        .font(.system(size: 9, weight: .medium))
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
        HStack {
          Text(process.name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          StatusDot(isRunning: process.isRunning)
        }

        if process.buffer.hasContent {
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
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(
            isHovered
              ? Color.accentColor.opacity(0.3)
              : Color(nsColor: .separatorColor),
            lineWidth: isHovered ? 1.5 : 1
          )
      )
      .scaleEffect(isHovered ? 1.01 : 1.0)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
      }
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
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color(nsColor: .textBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
      )
  }
}
