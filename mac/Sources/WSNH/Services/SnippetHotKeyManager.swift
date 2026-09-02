import AppKit
import HotKey

/// Registers/unregisters global hotkeys for Snippets that have one set,
/// mirroring HotKeyManager but for direct-insert Snippets rather than
/// AI-rewrite PromptActions. Snippets without a hotkey (typed-shortcut-only)
/// are simply skipped here.
final class SnippetHotKeyManager {
    static let shared = SnippetHotKeyManager()

    private var hotKeys: [UUID: HotKey] = [:]
    var onTrigger: ((Snippet) -> Void)?

    private init() {}

    func registerAll(_ snippets: [Snippet]) {
        hotKeys.removeAll()
        for snippet in snippets where snippet.hasHotkey {
            register(snippet)
        }
    }

    func register(_ snippet: Snippet) {
        guard let key = Key(carbonKeyCode: snippet.keyCode) else { return }
        let modifiers = NSEvent.ModifierFlags(rawValue: snippet.modifierFlags)
        let hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey.keyDownHandler = { [weak self] in
            self?.onTrigger?(snippet)
        }
        hotKeys[snippet.id] = hotKey
    }

    func unregister(_ snippetId: UUID) {
        hotKeys.removeValue(forKey: snippetId)
    }
}
