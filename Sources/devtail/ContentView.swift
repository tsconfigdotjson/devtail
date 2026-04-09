import ServiceManagement
import SwiftUI

enum ViewState: Equatable {
  case list
  case detail(UUID)
  case add
  case edit(UUID)
}

struct ContentView: View {
  var store: ProcessStore
  @State private var viewState: ViewState = .list
  @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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
          withAnimation(.spring(duration: 0.25)) {
            switch viewState {
            case .edit(let id):
              viewState = .detail(id)
            default:
              viewState = .list
            }
          }
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

      Text("devtail")
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
          },
          onEdit: {
            withAnimation(.spring(duration: 0.25)) {
              viewState = .edit(id)
            }
          }
        )
        .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        listContent
      }

    case .add:
      ProcessFormView(store: store) {
        withAnimation(.spring(duration: 0.25)) { viewState = .list }
      }
      .transition(.move(edge: .trailing).combined(with: .opacity))

    case .edit(let id):
      if let process = store.processes.first(where: { $0.id == id }) {
        ProcessFormView(store: store, editing: process) {
          withAnimation(.spring(duration: 0.25)) { viewState = .detail(id) }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
      } else {
        listContent
      }
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
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "terminal")
        .font(.system(size: 36))
        .foregroundStyle(.quaternary)

      VStack(spacing: 4) {
        Text("No processes yet")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
        Text("Add a dev server, build command, or any\nlong-running process to manage from here.")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
          .lineSpacing(2)
      }

      Button {
        withAnimation(.spring(duration: 0.25)) { viewState = .add }
      } label: {
        Label("Add Process", systemImage: "plus")
          .font(.system(size: 12, weight: .medium))
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 24)
  }

  // MARK: - Footer

  /// SMAppService requires a proper .app bundle to work.
  private var canManageLaunchAtLogin: Bool {
    Bundle.main.bundlePath.hasSuffix(".app")
  }

  private var footerBar: some View {
    HStack {
      Button("Quit devtail") {
        NSApplication.shared.terminate(nil)
      }
      .buttonStyle(.plain)
      .font(.system(size: 11))
      .foregroundStyle(.secondary)

      Spacer()

      if canManageLaunchAtLogin {
        Toggle(isOn: $launchAtLogin) {
          Text("Launch at Login")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .onChange(of: launchAtLogin) { _, newValue in
          do {
            if newValue {
              try SMAppService.mainApp.register()
            } else {
              try SMAppService.mainApp.unregister()
            }
          } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }
}
