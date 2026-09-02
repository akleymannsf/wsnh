using WSNH.Utilities;

namespace WSNH.Models;

/// <summary>
/// A saved, reusable block of formatted text (bold/italic/underline/links)
/// that can be inserted either via a global hotkey (paste at cursor, no
/// selection needed) or by typing a short text shortcut anywhere and
/// confirming it with a delimiter key (space/tab/enter/comma/period).
///
/// Unlike PromptAction, a Snippet never touches the AI -- it always inserts
/// exactly the content you wrote, instantly and offline.
/// </summary>
public class Snippet
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "New Snippet";

    /// <summary>RTF-encoded rich content -- the source of truth for formatting.</summary>
    public string Rtf { get; set; } = @"{\rtf1\ansi}";

    /// <summary>Plain-text fallback, kept in sync automatically as you edit.</summary>
    public string PlainText { get; set; } = "";

    /// <summary>A System.Windows.Forms.Keys value. 0 means "no hotkey set."</summary>
    public int KeyCode { get; set; }

    /// <summary>MOD_ALT / MOD_CONTROL / MOD_SHIFT / MOD_WIN bits.</summary>
    public uint ModifierFlags { get; set; }

    /// <summary>Empty means "no typed shortcut set."</summary>
    public string Shortcut { get; set; } = "";

    public bool HasHotkey => KeyCode != 0 && ModifierFlags != 0;

    public bool HasShortcut => !string.IsNullOrWhiteSpace(Shortcut);

    public string HotKeyDisplayString => HasHotkey
        ? HotKeyFormatter.ToString(KeyCode, ModifierFlags)
        : "No hotkey";

    /// <summary>Short human-readable summary shown in the Snippets list.</summary>
    public string TriggerSummary()
    {
        var parts = new List<string>();
        if (HasHotkey) parts.Add(HotKeyDisplayString);
        if (HasShortcut) parts.Add($"type \"{Shortcut.Trim()}\"");
        return parts.Count == 0
            ? "No trigger set — add a hotkey or shortcut below"
            : string.Join("  ·  ", parts);
    }

    public static Snippet Empty() => new();
}
