import SwiftUI

struct ProcessCardView: View {
    let process: ProcessConfig
    var onSelect: () -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Name and status
                HStack {
                    Text(process.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    StatusDot(isRunning: process.isRunning)
                }

                // Command output preview
                if !process.commandOutput.isEmpty {
                    TerminalBlock(
                        text: process.commandOutput,
                        lineLimit: 3,
                        compact: true
                    )
                }

                // Auxiliary command previews
                ForEach(process.auxiliaryCommands) { aux in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(aux.name.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(0.5)

                        TerminalBlock(
                            text: aux.output.isEmpty ? aux.command : aux.output,
                            lineLimit: 2,
                            compact: true,
                            dimmed: aux.output.isEmpty
                        )
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

// MARK: - Shared Components

struct StatusDot: View {
    let isRunning: Bool

    var body: some View {
        Circle()
            .fill(isRunning ? Color.green : Color(nsColor: .separatorColor))
            .frame(width: 10, height: 10)
            .shadow(color: isRunning ? .green.opacity(0.6) : .clear, radius: 4)
    }
}

struct TerminalBlock: View {
    let text: String
    var lineLimit: Int? = nil
    var compact: Bool = false
    var dimmed: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 10 : 11, design: .monospaced))
            .foregroundStyle(dimmed ? .tertiary : .secondary)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compact ? 8 : 10)
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
