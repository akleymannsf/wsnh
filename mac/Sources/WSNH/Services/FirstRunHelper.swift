import Foundation

/// Tracks whether the one-time welcome screen has already been shown, so it
/// appears automatically on first launch and never again on its own --
/// though it stays reachable any time afterward from the menu bar.
enum FirstRunHelper {
    private static let key = "hasShownWelcome"

    static var hasShownWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
