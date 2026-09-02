import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var resultWindows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .regular (not .accessory) so WSNH gets a Dock icon and shows up in
        // Cmd+Tab and Force Quit (⌘⌥Esc) like any other app -- accessory
        // apps are deliberately invisible to all three, which is exactly why
        // there was no way to force-quit it from the usual place during the
        // freeze.
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "wand.and.stars",
            accessibilityDescription: "WSNH"
        )

        let menu = NSMenu()
        let welcomeItem = NSMenuItem(title: "Welcome Guide…", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        let aboutItem = NSMenuItem(title: "About WSNH", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit WSNH", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        HotKeyManager.shared.onTrigger = { [weak self] action in
            self?.handleTrigger(action)
        }
        HotKeyManager.shared.registerAll(PromptStore.shared.actions)

        SnippetHotKeyManager.shared.onTrigger = { [weak self] snippet in
            self?.handleSnippetHotKey(snippet)
        }
        SnippetHotKeyManager.shared.registerAll(SnippetStore.shared.snippets)
        TypedTriggerWatcher.shared.reloadShortcuts(SnippetStore.shared.snippets)

        if !PermissionsHelper.isAccessibilityGranted {
            PermissionsHelper.requestAccessibilityIfNeeded()
        }
        if !PermissionsHelper.isInputMonitoringGranted {
            PermissionsHelper.requestInputMonitoringIfNeeded()
        }
        TypedTriggerWatcher.shared.startIfPermitted()

        if !FirstRunHelper.hasShownWelcome {
            FirstRunHelper.hasShownWelcome = true
            openWelcome()
        }
    }

    /// Accessory (menu bar-only) apps built with a plain NSApplicationDelegate
    /// don't get a default Edit menu the way SwiftUI's `App` lifecycle does.
    /// Without one, Cmd+C / Cmd+V / Cmd+A never reach text fields anywhere in
    /// the app (including the API key field in Preferences), because macOS
    /// routes those key equivalents through the app's main menu first. This
    /// menu is never shown on screen — it exists purely so those shortcuts work.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About WSNH", action: #selector(openAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit WSNH", action: #selector(quit), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "WSNH Preferences"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openWelcome() {
        if welcomeWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to WSNH"
            weak var weakWindow = window
            window.contentView = NSHostingView(rootView: WelcomeView(
                onOpenPreferences: { [weak self] in self?.openSettings() },
                onDismiss: { weakWindow?.close() }
            ))
            window.center()
            window.isReleasedWhenClosed = false
            welcomeWindow = window
        }
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About WSNH"
            window.contentView = NSHostingView(rootView: AboutView())
            window.center()
            window.isReleasedWhenClosed = false
            aboutWindow = window
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Hotkey trigger flow

    // Guards against a burst of hotkey presses firing a burst of AI calls.
    // Nothing visibly happens the instant you press the hotkey -- the popup
    // only appears once the network call finishes -- so pressing it again
    // (understandably) while impatient used to queue up another full
    // request on top, and another, and another. Enough of those stacking up
    // at once was enough to bog down the whole machine and blow through the
    // API's rate limit in one go. Now only one request runs at a time; a
    // repeat press while one's in flight just beeps instead of piling on.
    private var isPromptRequestInFlight = false

    private func handleTrigger(_ action: PromptAction) {
        guard PermissionsHelper.isAccessibilityGranted else {
            PermissionsHelper.requestAccessibilityIfNeeded()
            return
        }

        guard !isPromptRequestInFlight else {
            NSSound.beep()
            return
        }
        isPromptRequestInFlight = true

        SelectedTextGrabber.captureSelectedText { [weak self] text in
            guard let self else { return }
            guard let text, !text.isEmpty else {
                self.isPromptRequestInFlight = false
                return
            }

            Task {
                do {
                    let result = try await OpenAIClient.run(
                        model: action.model,
                        promptTemplate: action.promptTemplate,
                        selectedText: text
                    )
                    await MainActor.run {
                        self.isPromptRequestInFlight = false
                        self.deliverResult(result, for: action)
                    }
                } catch {
                    await MainActor.run {
                        self.isPromptRequestInFlight = false
                        self.showError(error)
                    }
                }
            }
        }
    }

    // MARK: - Snippet hotkey trigger flow

    private func handleSnippetHotKey(_ snippet: Snippet) {
        guard PermissionsHelper.isAccessibilityGranted else {
            PermissionsHelper.requestAccessibilityIfNeeded()
            return
        }
        SnippetInserter.insertAtCursor(snippet)
    }

    private func deliverResult(_ result: String, for action: PromptAction) {
        switch action.outputMode {
        case .autoPaste:
            TextPaster.pasteReplacingSelection(result)

        case .popup:
            showResultWindow(result)

        case .ask:
            let alert = NSAlert()
            alert.messageText = "Apply rewritten text?"
            alert.informativeText = result
            alert.addButton(withTitle: "Paste & Replace")
            alert.addButton(withTitle: "Copy Only")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                TextPaster.pasteReplacingSelection(result)
            case .alertSecondButtonReturn:
                TextPaster.copyToClipboard(result)
            default:
                break
            }
        }
    }

    private func showResultWindow(_ result: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WSNH Result"
        window.isReleasedWhenClosed = false
        window.level = .floating

        weak var weakWindow = window
        window.contentView = NSHostingView(rootView: ResultPopupView(text: result, onClose: {
            weakWindow?.close()
        }))
        window.center()
        resultWindows.append(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "WSNH Error"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
