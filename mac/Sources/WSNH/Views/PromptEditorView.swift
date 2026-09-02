import SwiftUI

/// Add/edit form for a single PromptAction: name, hotkey, model, output mode,
/// and the prompt template itself (with a {selectedText} placeholder).
struct PromptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = PromptStore.shared

    @State var action: PromptAction
    var isNew: Bool

    private let commonModels = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini", "o3-mini", "o4-mini"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Prompt Action" : "Edit Prompt Action")
                .font(.headline)

            Form {
                TextField("Name", text: $action.name)

                HStack {
                    Text("Hotkey")
                    HotKeyRecorderView(keyCode: $action.keyCode, modifierFlags: $action.modifierFlags)
                        .frame(width: 220, height: 28)
                }

                Picker("Model", selection: $action.model) {
                    ForEach(commonModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                TextField("Or type any model name", text: $action.model)
                    .font(.caption)

                Picker("After running", selection: $action.outputMode) {
                    ForEach(OutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt — use {selectedText} where the copied text should go")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $action.promptTemplate)
                        .frame(minHeight: 220)
                        .font(.system(.body, design: .monospaced))
                        .border(Color.gray.opacity(0.3))
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if isNew {
                        store.add(action)
                    } else {
                        store.update(action)
                    }
                    HotKeyManager.shared.registerAll(store.actions)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(action.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
