import Foundation

/// A single saved "prompt action": a hotkey, a model, and a prompt template
/// containing a {selectedText} placeholder.
struct PromptAction: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var keyCode: UInt32      // Carbon virtual key code
    var modifierFlags: UInt  // NSEvent.ModifierFlags raw value
    var model: String
    var promptTemplate: String
    var outputMode: OutputMode

    static func == (lhs: PromptAction, rhs: PromptAction) -> Bool { lhs.id == rhs.id }

    var hotKeyDisplayString: String {
        HotKeyFormatter.string(keyCode: keyCode, modifierFlags: modifierFlags)
    }
}
