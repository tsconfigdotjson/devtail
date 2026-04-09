import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessConfig
    var onToggle: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Process info header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(process.name)
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            StatusDot(isRunning: process.isRunning)
                            Text(process.isRunning ? "Running" : "Stopped")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
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

            // Tab picker for output sources
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

            // Terminal output
            ScrollView {
                Text(currentOutput)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isPlaceholder ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var currentOutput: String {
        if selectedTab == 0 {
            return process.commandOutput.isEmpty ? "Waiting for output..." : process.commandOutput
        }
        let auxIndex = selectedTab - 1
        guard auxIndex >= 0, auxIndex < process.auxiliaryCommands.count else {
            return ""
        }
        let aux = process.auxiliaryCommands[auxIndex]
        return aux.output.isEmpty ? "Waiting for output..." : aux.output
    }

    private var isPlaceholder: Bool {
        currentOutput == "Waiting for output..."
    }
}
