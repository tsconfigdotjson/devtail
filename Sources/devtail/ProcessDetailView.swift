import DevtailKit
import SwiftUI

struct ProcessDetailView: View {
  let process: DevProcess
  var onToggle: () -> Void
  var onEdit: () -> Void

  @State private var selectedTab = 0
  @State private var isTerminalHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(process.name)
            .font(.system(size: 15, weight: .semibold))

          Spacer()

          Button(action: onEdit) {
            Image(systemName: "gearshape")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)

          Button(action: onToggle) {
            HStack(spacing: 6) {
              StatusDot(isRunning: process.isRunning)
              Text(process.isRunning ? "Running" : "Stopped")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .liquidGlassBackground(
              in: Capsule(),
              fallback: AnyShapeStyle(.ultraThinMaterial)
            )
            .overlay(
              Capsule()
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            )
          }
          .buttonStyle(.plain)
        }

        HStack(spacing: 4) {
          Image(systemName: "chevron.right")
            .font(.system(size: 8))
          Text(process.command)
            .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(.tertiary)

        if !process.workingDirectory.isEmpty {
          HStack(spacing: 4) {
            Image(systemName: "folder")
              .font(.system(size: 8))
            Text(process.workingDirectory)
              .font(.system(size: 10))
          }
          .foregroundStyle(.quaternary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      if !process.auxiliaryCommands.isEmpty {
        Picker("", selection: $selectedTab) {
          Text("Output").tag(0)
          ForEach(Array(process.auxiliaryCommands.enumerated()), id: \.element.id) { pair in
            Text(pair.element.name).tag(pair.offset + 1)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }

      Group {
        if currentBuffer.hasContent {
          TerminalOutputView(buffer: currentBuffer)
        } else {
          Text("Waiting for output...")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .liquidGlassBackground(
        in: RoundedRectangle(cornerRadius: 8, style: .continuous),
        fallback: AnyShapeStyle(.ultraThinMaterial)
      )
      .overlay(alignment: .bottom) {
        if isTerminalHovered {
          Button {
            let title: String
            let auxIndex = selectedTab - 1
            if selectedTab == 0 || auxIndex >= process.auxiliaryCommands.count {
              title = process.name
            } else {
              let aux = process.auxiliaryCommands[auxIndex]
              title = "\(process.name) — \(aux.name)"
            }
            PopOutWindowManager.shared.openWindow(buffer: currentBuffer, title: title)
          } label: {
            HStack(spacing: 4) {
              Text("Pop Out")
                .font(.system(size: 11, weight: .medium))
              Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
          }
          .buttonStyle(.plain)
          .transition(.opacity)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
      )
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.15)) {
          isTerminalHovered = hovering
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
    }
    .onChange(of: process.auxiliaryCommands.count) {
      if selectedTab > process.auxiliaryCommands.count {
        selectedTab = 0
      }
    }
  }

  private var currentBuffer: TerminalBuffer {
    let auxIndex = selectedTab - 1
    if selectedTab > 0, auxIndex < process.auxiliaryCommands.count {
      return process.bufferFor(auxiliary: process.auxiliaryCommands[auxIndex].id)
    }
    return process.buffer
  }
}
