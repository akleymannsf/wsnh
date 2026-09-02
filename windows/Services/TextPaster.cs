using System.Windows.Forms;

namespace WSNH.Services;

/// <summary>Pastes AI results back into whatever app/field was previously focused.</summary>
public static class TextPaster
{
    public static async Task PasteReplacingSelectionAsync(string text)
    {
        IDataObject? previous = null;
        try { previous = Clipboard.GetDataObject(); } catch { /* ignore */ }

        Clipboard.SetText(text);
        NativeInput.SendPaste();

        // Give the paste time to land before restoring the user's previous
        // clipboard contents underneath it.
        await Task.Delay(400);

        try
        {
            if (previous != null)
            {
                Clipboard.SetDataObject(previous, true);
            }
        }
        catch { /* not fatal */ }
    }

    public static void CopyToClipboard(string text)
    {
        Clipboard.SetText(text);
    }
}
