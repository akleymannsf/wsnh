import AppKit
import HotKey

/// Registers/unregisters global hotkeys for each saved PromptAction using the
/// HotKey package (a thin wrapper around Carbon's RegisterEventHotKey).
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeys: [UUID: HotKey] = [:]
    var onTrigger: ((PromptAction) -> Void)?

    private init() {}

    func registerAll(_ actions: [PromptAction]) {
        hotKeys.removeAll()
        for action in actions {
            register(action)
        }
    }

    func register(_ action: PromptAction) {
        guard let key = Key(carbonKeyCode: action.keyCode) else { return }
        let modifiers = NSEvent.ModifierFlags(rawValue: action.modifierFlags)
        let hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey.keyDownHandler = { [weak self] in
            self?.onTrigger?(action)
        }
        hotKeys[action.id] = hotKey
    }

    func unregister(_ actionId: UUID) {
        hotKeys.removeValue(forKey: actionId)
    }
}
