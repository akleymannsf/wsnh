import AppKit
import ApplicationServices
import IOKit.hid

/// WSNH needs two separate macOS permissions:
/// - Accessibility: to simulate Cmd+C / Cmd+V, which is how it reads the
///   current selection from any app and pastes results/snippets back.
/// - Input Monitoring: to watch keystrokes system-wide, which is how typed
///   Snippet shortcuts (e.g. type ";sig" then Space) get detected. This is a
///   separate TCC category from Accessibility -- Accessibility alone does
///   not cover watching raw keystrokes.
enum PermissionsHelper {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility permission dialog if not already granted.
    static func requestAccessibilityIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static var isInputMonitoringGranted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Prompts the system Input Monitoring dialog the first time; if the
    /// user already denied it once, macOS won't re-prompt and System
    /// Settings is the only way back in (see openInputMonitoringSettings).
    static func requestInputMonitoringIfNeeded() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
