import SwiftUI

enum ViewState: Equatable {
    case list
    case detail(UUID)
    case add
}

struct ContentView: View {
    var store: ProcessStore
    @State private var viewState: ViewState = .list

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            contentArea
                .frame(maxHeight: .infinity)

            Divider()
            footerBar
        }
        .frame(width: 360, height: 500)
        .background(.background)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            if viewState != .list {
                Button {
                    withAnimation(.spring(duration: 0.25)) { viewState = .list }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Image(systemName: "terminal.fill")
                .font(.system(size: 16))
                .foregroundStyle(.tint)

            Text("Devtail")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            if viewState == .list {
                Button {
                    withAnimation(.spring(duration: 0.25)) { viewState = .add }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: viewState)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch viewState {
        case .list:
            listContent
                .transition(.move(edge: .leading).combined(with: .opacity))

        case .detail(let id):
            if let process = store.processes.first(where: { $0.id == id }) {
                ProcessDetailView(
                    process: process,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            process.toggle()
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                listContent
            }

        case .add:
            AddProcessView(store: store) {
                withAnimation(.spring(duration: 0.25)) { viewState = .list }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var listContent: some View {
        Group {
            if store.processes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.processes) { process in
                            ProcessCardView(
                                process: process,
                                onSelect: {
                                    withAnimation(.spring(duration: 0.3)) {
                                        viewState = .detail(process.id)
                                    }
                                },
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        process.toggle()
                                    }
                                },
                                onDelete: { store.removeProcess(id: process.id) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No processes configured")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Tap + to add your first process")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button("Quit Devtail") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
