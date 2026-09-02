import AppKit
import Carbon.HIToolbox
import HotKey

/// A second, belt-and-suspenders check on top of `ReservedHotKeys`: actually
/// attempts to register the candidate combo with Carbon for a split second
/// to see whether the OS rejects it outright.
///
/// This exists for a different class of conflict than `ReservedHotKeys`
/// covers. Plain app shortcuts like Cmd+C/Cmd+V aren't globally registered
/// by anyone, so trying to register them here would "succeed" even though
/// binding them is still a bad idea (that's what the hardcoded list is for).
/// But combos already claimed as an actual global hotkey by some *other*
/// running app -- Raycast, Alfred, BetterTouchTool, Keyboard Maestro,
/// screenshot utilities, a corporate IT tool, etc. -- genuinely do get
/// rejected by Carbon with an error, and this is the only way to catch those:
/// there's no static list of "every hotkey every app on this Mac might have
/// already grabbed."
enum HotKeyAvailability {
    /// Returns true if this exact combo can be registered as a global
    /// hotkey right now (i.e. nothing else already holds it).
    static func isAvailable(keyCode: UInt32, modifiers: UInt) -> Bool {
        let carbonModifiers = NSEvent.ModifierFlags(rawValue: modifiers).carbonFlags
        var hotKeyRef: EventHotKeyRef?
        let testID = EventHotKeyID(signature: OSType(0x5753_4E48), id: 0xFFFF_FFFE) // "WSNH", a ref no real snippet/action uses

        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            testID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            return false
        }

        // We only wanted to know if it *could* be registered -- release it
        // immediately so this probe never actually holds the hotkey.
        UnregisterEventHotKey(ref)
        return true
    }
}
