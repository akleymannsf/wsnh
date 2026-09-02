import SwiftUI

/// Floating window shown after a prompt action runs in "popup" or "ask" mode
/// (ask mode uses a native NSAlert instead; this view backs the popup mode).
struct ResultPopupView: View {
    @State var text: String
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WSNH Result").font(.headline)

            TextEditor(text: $text)
                .font(.system(.body))
                .frame(minHeight: 200)
                .border(Color.gray.opacity(0.3))

            HStack {
                Button("Copy") {
                    TextPaster.copyToClipboard(text)
                }
                Button("Paste & Replace") {
                    TextPaster.pasteReplacingSelection(text)
                    onClose()
                }
                Spacer()
                Button("Close") { onClose() }
            }
        }
        .padding(16)
        .frame(width: 460, height: 320)
    }
}
