import SwiftUI

/// Add/edit form for a single Snippet: name, hotkey, typed shortcut, and the
/// rich text content itself.
struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = SnippetStore.shared

    @State var snippet: Snippet
    var isNew: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Snippet" : "Edit Snippet")
                .font(.headline)

            Form {
                TextField("Name", text: $snippet.name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Hotkey (optional)")
                    HotKeyRecorderView(keyCode: $snippet.keyCode, modifierFlags: $snippet.modifierFlags)
                        .frame(width: 220, height: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Typed shortcut (optional) — type this anywhere, then press Space/Tab/Return to expand it")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. ;sig1", text: $snippet.shortcut)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .frame(width: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.6), lineWidth: 1.5)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    RichTextEditorView(rtfData: $snippet.rtfData, plainText: $snippet.plainText)
                        .frame(minHeight: 220)
                }
            }

            if !saveDisabledReason.isEmpty {
                Text(saveDisabledReason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if isNew {
                        store.add(snippet)
                    } else {
                        store.update(snippet)
                    }
                    SnippetHotKeyManager.shared.registerAll(store.snippets)
                    TypedTriggerWatcher.shared.reloadShortcuts(store.snippets)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!saveDisabledReason.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    /// Empty string means Save is enabled; otherwise this is shown right
    /// above the buttons so it's obvious what's missing.
    private var saveDisabledReason: String {
        if snippet.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Add a name before saving."
        }
        if !snippet.hasHotkey && !snippet.hasShortcut {
            return "Add a hotkey, a typed shortcut, or both before saving."
        }
        return ""
    }
}
