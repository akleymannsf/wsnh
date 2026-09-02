using System.Windows.Forms;

namespace WSNH.Services;

/// <summary>
/// Grabs whatever text is currently selected in the frontmost app by
/// simulating Ctrl+C and reading the clipboard, then restores whatever was
/// on the clipboard beforehand so we don't clobber the user's existing
/// clipboard.
/// </summary>
public static class SelectedTextGrabber
{
    public static async Task<string?> CaptureSelectedTextAsync()
    {
        IDataObject? previous = null;
        try
        {
            previous = Clipboard.GetDataObject();
        }
        catch
        {
            // Another app can transiently hold the clipboard open; just
            // proceed without a snapshot to restore in that rare case.
        }

        // A generation marker: clear a private format first so we can tell
        // whether the copy actually landed something new, the same way the
        // Mac build compares NSPasteboard.changeCount before/after.
        Clipboard.Clear();

        NativeInput.SendCopy();

        // Give the frontmost app a moment to place the copy on the clipboard.
        await Task.Delay(150);

        string? text = null;
        try
        {
            if (Clipboard.ContainsText())
            {
                text = Clipboard.GetText();
            }
        }
        catch
        {
            // Ignore transient clipboard access failures.
        }

        try
        {
            if (previous != null)
            {
                Clipboard.SetDataObject(previous, true);
            }
        }
        catch
        {
            // Not fatal if we can't restore the previous clipboard contents.
        }

        return string.IsNullOrEmpty(text) ? null : text;
    }
}
