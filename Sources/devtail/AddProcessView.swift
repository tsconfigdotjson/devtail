import SwiftUI

struct AddProcessView: View {
    var store: ProcessStore
    var onDismiss: () -> Void

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = ""
    @State private var auxEntries: [AuxEntry] = []
    @State private var isAddingAux = false
    @State private var newAuxName = ""
    @State private var newAuxCommand = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("New Process")
                        .font(.system(size: 15, weight: .semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        formField(label: "Name", placeholder: "my-server", text: $name)
                        formField(label: "Command", placeholder: "npm run dev", text: $command, monospaced: true)
                        formField(label: "Working Directory", placeholder: "~/projects/app", text: $workingDirectory, monospaced: true)
                    }

                    // Auxiliary commands section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("LOG WATCHERS")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .tracking(0.5)

                            Spacer()

                            Button {
                                withAnimation(.spring(duration: 0.2)) { isAddingAux = true }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(auxEntries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.system(size: 11, weight: .medium))
                                    Text(entry.command)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    withAnimation {
                                        auxEntries.removeAll { $0.id == entry.id }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                        }

                        if isAddingAux {
                            VStack(spacing: 8) {
                                TextField("Log name", text: $newAuxName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                                TextField("tail -f /path/to/log", text: $newAuxCommand)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                                HStack {
                                    Button("Cancel") {
                                        isAddingAux = false
                                        newAuxName = ""
                                        newAuxCommand = ""
                                    }
                                    .controlSize(.small)

                                    Spacer()

                                    Button("Add") {
                                        guard !newAuxName.isEmpty, !newAuxCommand.isEmpty else { return }
                                        auxEntries.append(AuxEntry(name: newAuxName, command: newAuxCommand))
                                        newAuxName = ""
                                        newAuxCommand = ""
                                        isAddingAux = false
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(newAuxName.isEmpty || newAuxCommand.isEmpty)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)

            Divider()

            Button(action: save) {
                Text("Create Process")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.isEmpty || command.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func formField(label: String, placeholder: String, text: Binding<String>, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
        }
    }

    private func save() {
        let auxCommands = auxEntries.map {
            AuxiliaryCommand(name: $0.name, command: $0.command)
        }
        store.addProcess(
            name: name,
            command: command,
            workingDirectory: workingDirectory,
            auxiliaryCommands: auxCommands
        )
        onDismiss()
    }
}

private struct AuxEntry: Identifiable {
    let id = UUID()
    var name: String
    var command: String
}

