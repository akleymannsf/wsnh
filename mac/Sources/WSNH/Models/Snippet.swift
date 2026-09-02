import AppKit

/// A saved, reusable block of formatted text (bold/italic/underline/links,
/// etc.) that can be inserted either via a global hotkey (paste at cursor,
/// no selection needed) or by typing a short text shortcut anywhere and
/// confirming it with a delimiter key (space/tab/return/comma/period).
///
/// Unlike PromptAction, a Snippet never touches the AI -- it always inserts
/// exactly the content you wrote, instantly and offline.
struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String

    /// RTF-encoded rich content -- the source of truth for formatting.
    var rtfData: Data
    /// Plain-text fallback, kept in sync automatically as you edit, for
    /// apps/fields that only accept plain text on paste.
    var plainText: String

    /// 0 for both means "no hotkey set."
    var keyCode: UInt32 = 0
    var modifierFlags: UInt = 0

    /// Empty means "no typed shortcut set."
    var shortcut: String = ""

    // Equatable is auto-synthesized field-by-field (every stored property
    // here is itself Equatable) -- deliberately not overridden to compare
    // only `id`, since that would make SwiftUI's change-detection treat two
    // Snippets with different content/hotkey/shortcut as "equal" whenever
    // their id happens to match, which is exactly the wrong behavior while
    // editing one in a form.

    var hasHotkey: Bool { keyCode != 0 || modifierFlags != 0 }

    var hasShortcut: Bool {
        !shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hotKeyDisplayString: String {
        hasHotkey ? HotKeyFormatter.string(keyCode: keyCode, modifierFlags: modifierFlags) : "No hotkey"
    }

    /// Short human-readable summary of however this snippet can be triggered,
    /// used in the Snippets list in Preferences.
    var triggerSummary: String {
        var parts: [String] = []
        if hasHotkey { parts.append(hotKeyDisplayString) }
        if hasShortcut {
            parts.append("type \"\(shortcut.trimmingCharacters(in: .whitespacesAndNewlines))\"")
        }
        return parts.isEmpty ? "No trigger set — add a hotkey or shortcut below" : parts.joined(separator: "  ·  ")
    }

    static func empty() -> Snippet {
        let emptyAttributed = NSAttributedString(string: "")
        let rtf = try? emptyAttributed.data(
            from: NSRange(location: 0, length: 0),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        return Snippet(name: "New Snippet", rtfData: rtf ?? Data(), plainText: "")
    }
}
