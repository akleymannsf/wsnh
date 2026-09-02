import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Puts text on the clipboard and (optionally) simulates Cmd+V to paste it into
/// whatever app is frontmost, replacing the current selection.
enum TextPaster {
    static func pasteReplacingSelection(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first, let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

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

    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
