import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Inserts a Snippet's rich content at the current cursor position, either
/// directly (hotkey trigger, no selection involved -- a plain paste, same as
/// if you'd pressed Cmd+V yourself) or after first deleting a just-typed
/// shortcut (typed-trigger expansion).
enum SnippetInserter {
    /// Hotkey trigger: paste the snippet at the cursor.
    static func insertAtCursor(_ snippet: Snippet) {
        pasteSnippet(snippet)
    }

    /// Typed-shortcut trigger: remove what was just typed (the shortcut plus
    /// the delimiter key that confirmed it), insert the snippet, then retype
    /// the delimiter so the word-break you typed is still there afterward.
    static func expandTypedTrigger(_ snippet: Snippet, deleteCount: Int, thenRetype delimiterKeyCode: CGKeyCode) {
        sendBackspaces(deleteCount)

        // Give the frontmost app a moment to process the deletions before pasting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pasteSnippet(snippet)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                sendKey(delimiterKeyCode)
            }
        }
    }

    private static func pasteSnippet(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first, let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        }

        pasteboard.clearContents()
        pasteboard.setData(snippet.rtfData, forType: .rtf)
        pasteboard.setString(snippet.plainText, forType: .string)

        simulatePaste()

        // Give the paste a moment to land before restoring the user's old clipboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let previousItems, !previousItems.isEmpty else { return }
            pasteboard.clearContents()
            for (typeRaw, data) in previousItems {
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
            }
        }
    }

    private static func sendBackspaces(_ count: Int) {
        guard count > 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Delete), keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    private static func sendKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
