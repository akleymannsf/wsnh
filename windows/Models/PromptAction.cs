using WSNH.Utilities;

namespace WSNH.Models;

/// <summary>
/// A saved AI rewrite action: a global hotkey, a prompt template, which
/// model to use, and what to do with the result.
/// </summary>
public class PromptAction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";

    /// <summary>A System.Windows.Forms.Keys value. 0 (Keys.None) means "no hotkey set."</summary>
    public int KeyCode { get; set; }

    /// <summary>MOD_ALT / MOD_CONTROL / MOD_SHIFT / MOD_WIN bits (user32.dll RegisterHotKey).</summary>
    public uint ModifierFlags { get; set; }

    public string Model { get; set; } = "gpt-4o-mini";
    public string PromptTemplate { get; set; } = "";
    public OutputMode OutputMode { get; set; } = OutputMode.Popup;

    public bool HasHotkey => KeyCode != 0 && ModifierFlags != 0;

    public string HotKeyDisplayString => HasHotkey
        ? HotKeyFormatter.ToString(KeyCode, ModifierFlags)
        : "No hotkey";
}
