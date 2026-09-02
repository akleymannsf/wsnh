namespace WSNH.Models;

/// <summary>
/// What happens to the rewritten text once the AI call finishes.
/// </summary>
public enum OutputMode
{
    /// <summary>Replace the selected text in place (simulated Ctrl+V).</summary>
    AutoPaste,
    /// <summary>Show the result in a small popup window to copy from.</summary>
    Popup,
    /// <summary>Ask first: Paste &amp; Replace, Copy Only, or Cancel.</summary>
    Ask
}
