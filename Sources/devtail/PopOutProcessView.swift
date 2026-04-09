import SwiftUI
import DevtailKit

struct PopOutProcessView: View {
    let buffer: TerminalBuffer
    let title: String

    var body: some View {
        Group {
            if buffer.hasContent {
                TerminalOutputView(buffer: buffer)
            } else {
                Text("Waiting for output...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
