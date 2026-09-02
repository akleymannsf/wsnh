using System.Windows.Forms;

namespace WSNH.Services;

/// <summary>
/// Standard Windows/app editing and system shortcuts that WSNH should never
/// let a user bind to a Prompt Action or Snippet hotkey.
///
/// RegisterHotKey itself already blocks combos another *app* has claimed
/// (see HotKeyRegistry.IsAvailable), but plain editing shortcuts like
/// Ctrl+C/Ctrl+V aren't globally registered by anyone -- every app just
/// implements them itself. So RegisterHotKey would happily let WSNH grab
/// Ctrl+V as its own global hotkey, and from then on WSNH would silently
/// swallow that keystroke everywhere, in every app, exactly the way it did
/// on the Mac side before this same protection was added there.
/// </summary>
public static class ReservedHotKeys
{
    public readonly record struct Combo(int KeyCode, uint Modifiers);

    private static Combo C(Keys key, uint modifiers) => new((int)key, modifiers);

    public static readonly Dictionary<Combo, string> Blocked = BuildBlockedList();

    private static Dictionary<Combo, string> BuildBlockedList()
    {
        const uint ctrl = HotKeyModifiers.Control;
        const uint ctrlShift = HotKeyModifiers.Control | HotKeyModifiers.Shift;
        const uint alt = HotKeyModifiers.Alt;
        const uint win = HotKeyModifiers.Win;

        var map = new Dictionary<Combo, string>
        {
            [C(Keys.C, ctrl)] = "Copy (Ctrl+C)",
            [C(Keys.V, ctrl)] = "Paste (Ctrl+V)",
            [C(Keys.X, ctrl)] = "Cut (Ctrl+X)",
            [C(Keys.A, ctrl)] = "Select All (Ctrl+A)",
            [C(Keys.Z, ctrl)] = "Undo (Ctrl+Z)",
            [C(Keys.Y, ctrl)] = "Redo (Ctrl+Y)",
            [C(Keys.S, ctrl)] = "Save (Ctrl+S)",
            [C(Keys.P, ctrl)] = "Print (Ctrl+P)",
            [C(Keys.N, ctrl)] = "New (Ctrl+N)",
            [C(Keys.O, ctrl)] = "Open (Ctrl+O)",
            [C(Keys.F, ctrl)] = "Find (Ctrl+F)",
            [C(Keys.W, ctrl)] = "Close Tab/Window (Ctrl+W)",
            [C(Keys.Tab, ctrl)] = "Next Tab (Ctrl+Tab)",
            [C(Keys.Escape, ctrlShift)] = "Task Manager (Ctrl+Shift+Esc)",
            [C(Keys.Escape, ctrl)] = "Start Menu (Ctrl+Esc)",
            [C(Keys.Tab, alt)] = "App Switcher (Alt+Tab)",
            [C(Keys.F4, alt)] = "Close Window (Alt+F4)",
            [C(Keys.L, win)] = "Lock Screen (Win+L)",
            [C(Keys.D, win)] = "Show Desktop (Win+D)",
            [C(Keys.E, win)] = "File Explorer (Win+E)",
            [C(Keys.R, win)] = "Run Dialog (Win+R)",
            [C(Keys.Tab, win)] = "Task View (Win+Tab)",
            [C(Keys.S, win | HotKeyModifiers.Shift)] = "Snipping Tool (Win+Shift+S)",
        };
        return map;
    }

    /// <summary>Returns what a combo is already used for, or null if it's free to bind.</summary>
    public static string? Label(int keyCode, uint modifiers)
    {
        return Blocked.TryGetValue(new Combo(keyCode, modifiers), out var label) ? label : null;
    }
}
