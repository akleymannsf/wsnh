import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Grabs whatever text is currently selected in the frontmost app by simulating
/// Cmd+C and reading the pasteboard, then restores whatever was on the
/// clipboard beforehand so we don't clobber the user's existing clipboard.
enum SelectedTextGrabber {
    static func captureSelectedText(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        let previousItems = snapshot(of: pasteboard)

        simulateCopy()

        // Give the frontmost app a moment to place the copy on the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let changed = pasteboard.changeCount != previousChangeCount
            let text = changed ? pasteboard.string(forType: .string) : nil

            if changed {
                restore(previousItems, to: pasteboard)
            }

            completion(text)
        }
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [(String, Data)] {
        pasteboard.pasteboardItems?.compactMap { item in
            guard let type = item.types.first, let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        } ?? []
    }

    private static func restore(_ items: [(String, Data)], to pasteboard: NSPasteboard) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        for (typeRaw, data) in items {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeRaw))
        }
    }

    private static func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
    }
}
