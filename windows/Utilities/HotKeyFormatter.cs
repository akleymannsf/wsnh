using System.Windows.Forms;
using WSNH.Services;

namespace WSNH.Utilities;

/// <summary>Renders a keyCode + modifierFlags pair as a human-readable string like "Ctrl+Alt+R".</summary>
public static class HotKeyFormatter
{
    public static string ToString(int keyCode, uint modifierFlags)
    {
        var parts = new List<string>();
        if ((modifierFlags & HotKeyModifiers.Control) != 0) parts.Add("Ctrl");
        if ((modifierFlags & HotKeyModifiers.Alt) != 0) parts.Add("Alt");
        if ((modifierFlags & HotKeyModifiers.Shift) != 0) parts.Add("Shift");
        if ((modifierFlags & HotKeyModifiers.Win) != 0) parts.Add("Win");
        parts.Add(KeyName(keyCode));
        return string.Join("+", parts);
    }

    public static string KeyName(int keyCode)
    {
        var key = (Keys)keyCode;
        // Keys.ToString() already gives clean names for letters/digits/F-keys
        // ("A", "D1", "F5", "Space", "Return", "Oemcomma", ...). A couple are
        // worth relabeling so they read naturally in the UI.
        return key switch
        {
            Keys.D0 => "0",
            Keys.D1 => "1",
            Keys.D2 => "2",
            Keys.D3 => "3",
            Keys.D4 => "4",
            Keys.D5 => "5",
            Keys.D6 => "6",
            Keys.D7 => "7",
            Keys.D8 => "8",
            Keys.D9 => "9",
            Keys.Return => "Enter",
            Keys.Oemcomma => ",",
            Keys.OemPeriod => ".",
            Keys.None => "None",
            _ => key.ToString()
        };
    }
}
