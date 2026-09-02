import SwiftUI
import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

/// Preferences window: OpenAI API key, Accessibility permission status,
/// launch-at-login toggle, and the list of saved prompt actions.
struct SettingsView: View {
    @ObservedObject var store = PromptStore.shared
    @State private var apiKeyInput: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var baseURLInput: String = AppSettings.baseURL
    @ObservedObject var snippetStore = SnippetStore.shared
    @State private var editingAction: PromptAction?
    @State private var isAddingNew = false
    @State private var editingSnippet: Snippet?
    @State private var isAddingNewSnippet = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = PermissionsHelper.isAccessibilityGranted
    @State private var inputMonitoringGranted = PermissionsHelper.isInputMonitoringGranted
    @State private var savedKeyConfirmation = false
    @State private var backupMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WSNH Preferences").font(.title2).bold()

                GroupBox("AI Connection") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            SecureField("sk-...", text: $apiKeyInput)
                            Button("Save") {
                                let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                let trimmedURL = baseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                apiKeyInput = trimmedKey
                                baseURLInput = trimmedURL
                                KeychainHelper.saveAPIKey(trimmedKey)
                                AppSettings.baseURL = trimmedURL
                                savedKeyConfirmation = true
                            }
                        }

                        Text("API Base URL — Salesforce employees: leave this as the LLM Gateway Express URL below. Using your own OpenAI account instead? Change it to https://api.openai.com/v1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(AppSettings.defaultBaseURL, text: $baseURLInput)

                        if savedKeyConfirmation {
                            Text("Saved.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                GroupBox("Accessibility Permission") {
                    HStack {
                        Text(accessibilityGranted
                             ? "Granted ✅"
                             : "Not granted — required to read selected text and paste results")
                        Spacer()
                        Button("Open System Settings") {
                            PermissionsHelper.openAccessibilitySettings()
                        }
                    }
                }

                GroupBox("Input Monitoring Permission") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Needed only for typed-shortcut Snippets (e.g. type \";sig1\" then Space) — it's what lets WSNH watch for a shortcut as you type. Hotkey-triggered Snippets and Prompt Actions don't need this.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(inputMonitoringGranted
                                 ? "Granted ✅"
                                 : "Not granted — typed-shortcut Snippets won't expand until this is on")
                            Spacer()
                            Button("Open System Settings") {
                                PermissionsHelper.openInputMonitoringSettings()
                            }
                        }
                        if !inputMonitoringGranted {
                            Button("Try requesting permission again") {
                                PermissionsHelper.requestInputMonitoringIfNeeded()
                            }
                            .font(.caption)
                        }
                    }
                }

                GroupBox("Startup") {
                    Toggle("Launch WSNH at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            LaunchAtLogin.isEnabled = newValue
                        }
                }

                GroupBox("Prompt Actions") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.actions) { action in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(action.name).bold()
                                    Text("\(action.hotKeyDisplayString)  ·  \(action.model)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Edit") { editingAction = action }
                                Button(role: .destructive) {
                                    store.remove(action)
                                    HotKeyManager.shared.registerAll(store.actions)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                        Button {
                            isAddingNew = true
                        } label: {
                            Label("Add Prompt Action", systemImage: "plus")
                        }
                        .padding(.top, 6)
                    }
                }

                GroupBox("Snippets") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reusable formatted text (bold, links, etc.) inserted via a hotkey or a typed shortcut — no AI involved, always exactly what you wrote.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(snippetStore.snippets) { snippet in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(snippet.name).bold()
                                    Text(snippet.triggerSummary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Edit") { editingSnippet = snippet }
                                Button(role: .destructive) {
                                    snippetStore.remove(snippet)
                                    SnippetHotKeyManager.shared.registerAll(snippetStore.snippets)
                                    TypedTriggerWatcher.shared.reloadShortcuts(snippetStore.snippets)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                        Button {
                            isAddingNewSnippet = true
                        } label: {
                            Label("Add Snippet", systemImage: "plus")
                        }
                        .padding(.top, 6)
                    }
                }

                GroupBox("Backup & Restore") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Back up your API key, API base URL, all prompt actions, and all snippets to a file, or restore from one. The file contains your API key in plain text — store it somewhere secure and don't share it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Button("Export Backup…") { exportBackup() }
                            Button("Import Backup…") { importBackup() }
                        }
                        if let backupMessage {
                            Text(backupMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 560, height: 720)
        .sheet(item: $editingAction) { action in
            PromptEditorView(action: action, isNew: false)
        }
        .sheet(isPresented: $isAddingNew) {
            PromptEditorView(
                action: PromptAction(
                    name: "New Action",
                    keyCode: UInt32(kVK_ANSI_J),
                    modifierFlags: NSEvent.ModifierFlags([.command, .option]).rawValue,
                    model: "gpt-4o-mini",
                    promptTemplate: "Rewrite the following text:\n\n{selectedText}",
                    outputMode: .popup
                ),
                isNew: true
            )
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorView(snippet: snippet, isNew: false)
        }
        .sheet(isPresented: $isAddingNewSnippet) {
            SnippetEditorView(snippet: Snippet.empty(), isNew: true)
        }
        .onAppear {
            accessibilityGranted = PermissionsHelper.isAccessibilityGranted
            inputMonitoringGranted = PermissionsHelper.isInputMonitoringGranted
            // In case permission was just granted in System Settings while
            // WSNH was already running, start the watcher without requiring
            // a relaunch.
            TypedTriggerWatcher.shared.startIfPermitted()
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export WSNH Backup"
        panel.nameFieldStringValue = "WSNH-Backup-\(Self.dateStamp()).json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try BackupManager.exportData().write(to: url)
            backupMessage = "Exported to \(url.lastPathComponent)."
        } catch {
            backupMessage = "Couldn't write the backup file: \(error.localizedDescription)"
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Import WSNH Backup"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let alert = NSAlert()
        alert.messageText = "Replace current settings?"
        alert.informativeText = "Importing will overwrite your current API key, base URL, prompt actions, and snippets with what's in this backup."
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let data = try Data(contentsOf: url)
            let payload = try BackupManager.restore(from: data)

            apiKeyInput = KeychainHelper.loadAPIKey() ?? ""
            baseURLInput = AppSettings.baseURL

            if payload.platform != "mac" {
                backupMessage = "Imported \(payload.actions.count) prompt action(s) and \(payload.snippets.count) snippet(s) from a \(payload.platform) backup — you may need to re-set hotkeys, since key codes don't carry over between platforms."
            } else {
                backupMessage = "Imported \(payload.actions.count) prompt action(s) and \(payload.snippets.count) snippet(s)."
            }
        } catch {
            backupMessage = "Couldn't import that file: \(error.localizedDescription)"
        }
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
