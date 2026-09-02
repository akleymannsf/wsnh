import AppKit
import Carbon.HIToolbox

/// Standard macOS / app-editing shortcuts that WSNH should never let a user
/// bind to a Prompt Action or Snippet hotkey.
///
/// This matters because Carbon's `RegisterEventHotKey` (which the `HotKey`
/// package wraps) does NOT protect these on its own. Things like Cmd+C,
/// Cmd+V, Cmd+Z, etc. aren't OS-level "reserved" hotkeys -- every app just
/// implements them itself via ordinary Edit-menu key equivalents. So if WSNH
/// registers one of those same combos as a *global* hotkey, the registration
/// succeeds without any error, and from then on WSNH silently steals that
/// keystroke everywhere, in every app, before it ever reaches whatever app
/// you're actually using -- which is exactly what broke native copy/paste
/// while WSNH was running.
enum ReservedHotKeys {
    struct Combo: Hashable {
        let keyCode: UInt32
        /// Just the four modifier bits (command/option/control/shift),
        /// already normalized so callers don't need to mask it themselves.
        let modifiers: UInt
    }

    private static func combo(_ keyCode: Int, _ modifiers: NSEvent.ModifierFlags) -> Combo {
        Combo(keyCode: UInt32(keyCode), modifiers: modifiers.rawValue)
    }

    /// Combo -> human-readable name of what it's already used for, shown in
    /// the "that combo is taken" message.
    static let blocked: [Combo: String] = {
        let cmd = NSEvent.ModifierFlags.command
        let cmdShift = NSEvent.ModifierFlags([.command, .shift])
        let ctrl = NSEvent.ModifierFlags.control

        var map: [Combo: String] = [:]
        map[combo(kVK_ANSI_C, cmd)] = "Copy (⌘C)"
        map[combo(kVK_ANSI_V, cmd)] = "Paste (⌘V)"
        map[combo(kVK_ANSI_X, cmd)] = "Cut (⌘X)"
        map[combo(kVK_ANSI_A, cmd)] = "Select All (⌘A)"
        map[combo(kVK_ANSI_Z, cmd)] = "Undo (⌘Z)"
        map[combo(kVK_ANSI_Z, cmdShift)] = "Redo (⌘⇧Z)"
        map[combo(kVK_ANSI_S, cmd)] = "Save (⌘S)"
        map[combo(kVK_ANSI_P, cmd)] = "Print (⌘P)"
        map[combo(kVK_ANSI_W, cmd)] = "Close Window (⌘W)"
        map[combo(kVK_ANSI_Q, cmd)] = "Quit (⌘Q)"
        map[combo(kVK_ANSI_N, cmd)] = "New (⌘N)"
        map[combo(kVK_ANSI_O, cmd)] = "Open (⌘O)"
        map[combo(kVK_ANSI_F, cmd)] = "Find (⌘F)"
        map[combo(kVK_ANSI_H, cmd)] = "Hide (⌘H)"
        map[combo(kVK_ANSI_M, cmd)] = "Minimize (⌘M)"
        map[combo(kVK_Tab, cmd)] = "App Switcher (⌘Tab)"
        map[combo(kVK_Space, cmd)] = "Spotlight (⌘Space)"
        map[combo(kVK_Space, ctrl)] = "Input Source Switch (⌃Space)"
        map[combo(kVK_ANSI_3, cmdShift)] = "Screenshot (⌘⇧3)"
        map[combo(kVK_ANSI_4, cmdShift)] = "Screenshot (⌘⇧4)"
        map[combo(kVK_ANSI_5, cmdShift)] = "Screenshot Tool (⌘⇧5)"

        // macOS's text system supports classic Emacs-style navigation with
        // plain Control, inside essentially every text field/text view on
        // the whole system (Mail, Messages, Notes, browsers, this app's own
        // fields -- all of it). These are just as easy to accidentally
        // clobber as the Cmd-based ones above, and arguably more disruptive
        // since they fire while you're mid-typing anywhere.
        map[combo(kVK_ANSI_A, ctrl)] = "Move to start of line (⌃A)"
        map[combo(kVK_ANSI_E, ctrl)] = "Move to end of line (⌃E)"
        map[combo(kVK_ANSI_F, ctrl)] = "Move forward one character (⌃F)"
        map[combo(kVK_ANSI_B, ctrl)] = "Move back one character (⌃B)"
        map[combo(kVK_ANSI_N, ctrl)] = "Move down a line (⌃N)"
        map[combo(kVK_ANSI_P, ctrl)] = "Move up a line (⌃P)"
        map[combo(kVK_ANSI_D, ctrl)] = "Delete forward (⌃D)"
        map[combo(kVK_ANSI_H, ctrl)] = "Delete backward (⌃H)"
        map[combo(kVK_ANSI_K, ctrl)] = "Delete to end of line (⌃K)"
        map[combo(kVK_ANSI_O, ctrl)] = "Insert line break (⌃O)"
        map[combo(kVK_ANSI_T, ctrl)] = "Transpose characters (⌃T)"
        map[combo(kVK_ANSI_V, ctrl)] = "Page down (⌃V)"
        map[combo(kVK_ANSI_Y, ctrl)] = "Paste from kill buffer (⌃Y)"
        return map
    }()

    /// Returns what a combo is already used for, or nil if it's free to bind.
    static func label(forKeyCode keyCode: UInt32, modifiers: UInt) -> String? {
        blocked[Combo(keyCode: keyCode, modifiers: modifiers)]
    }
}
