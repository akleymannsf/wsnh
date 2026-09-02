using System.Windows.Forms;
using WSNH.Models;

namespace WSNH.Services;

/// <summary>Inserts a Snippet's content, either at the cursor (hotkey trigger) or by replacing a just-typed shortcut (typed trigger).</summary>
public static class SnippetInserter
{
    /// <summary>Hotkey trigger: paste directly, no existing text to remove.</summary>
    public static async void InsertAtCursor(Snippet snippet)
    {
        IDataObject? previous = null;
        try { previous = Clipboard.GetDataObject(); } catch { /* ignore */ }

        SetSnippetOnClipboard(snippet);
        NativeInput.SendPaste();

        await Task.Delay(400);

        try
        {
            if (previous != null) Clipboard.SetDataObject(previous, true);
        }
        catch { /* not fatal */ }
    }

    /// <summary>
    /// Typed trigger: deletes what was typed (the shortcut text plus the
    /// delimiter that confirmed it), pastes the snippet, then retypes the
    /// delimiter key so whatever punctuation/whitespace the user typed to
    /// confirm the shortcut still ends up after the inserted snippet.
    /// </summary>
    public static async void ExpandTypedTrigger(Snippet snippet, int deleteCount, ushort delimiterVk)
    {
        NativeInput.SendBackspaces(deleteCount);

        IDataObject? previous = null;
        try { previous = Clipboard.GetDataObject(); } catch { /* ignore */ }

        await Task.Delay(50);
        SetSnippetOnClipboard(snippet);
        NativeInput.SendPaste();

        await Task.Delay(400);
        try
        {
            if (previous != null) Clipboard.SetDataObject(previous, true);
        }
        catch { /* not fatal */ }

        await Task.Delay(350);
        NativeInput.SendKeyTap(delimiterVk);
    }

    private static void SetSnippetOnClipboard(Snippet snippet)
    {
        var data = new DataObject();
        if (!string.IsNullOrEmpty(snippet.Rtf))
        {
            data.SetData(DataFormats.Rtf, snippet.Rtf);
        }
        data.SetData(DataFormats.UnicodeText, snippet.PlainText);
        Clipboard.SetDataObject(data, true);
    }
}
