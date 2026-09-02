using System.Drawing;
using System.Windows.Forms;
using WSNH.Services;
using WSNH.Utilities;

namespace WSNH.Forms;

/// <summary>
/// A small control you click, then press a key combo (with at least one
/// modifier) to record a new global hotkey.
///
/// Built on UserControl rather than Label -- Label deliberately can't take
/// keyboard focus in WinForms (ControlStyles.Selectable is off by default),
/// so it would never receive the KeyDown this control depends on.
/// </summary>
public class HotKeyRecorderControl : UserControl
{
    public int KeyCode { get; private set; }
    public uint ModifierFlags { get; private set; }

    /// <summary>Fired whenever a new combo is successfully captured (not on rejected attempts).</summary>
    public event Action? ValueChanged;

    private readonly Label _label = new();
    private bool _isRecording;

    public HotKeyRecorderControl()
    {
        Width = 220;
        Height = 28;
        SetStyle(ControlStyles.Selectable, true);
        TabStop = true;
        BorderStyle = BorderStyle.FixedSingle;
        Cursor = Cursors.Hand;

        _label.Dock = DockStyle.Fill;
        _label.TextAlign = ContentAlignment.MiddleCenter;
        Controls.Add(_label);

        Click += (_, _) => StartRecording();
        _label.Click += (_, _) => StartRecording();

        RefreshLabel();
    }

    public void SetValue(int keyCode, uint modifierFlags)
    {
        KeyCode = keyCode;
        ModifierFlags = modifierFlags;
        RefreshLabel();
    }

    private void StartRecording()
    {
        _isRecording = true;
        _label.Text = "Press a key combo…";
        Focus();
    }

    protected override bool IsInputKey(Keys keyData) => true;

    protected override void OnPreviewKeyDown(PreviewKeyDownEventArgs e)
    {
        base.OnPreviewKeyDown(e);
        e.IsInputKey = true;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (!_isRecording)
        {
            base.OnKeyDown(e);
            return;
        }

        e.Handled = true;
        e.SuppressKeyPress = true;

        var modifiers = ToHotKeyModifiers(e.Modifiers);
        // Require at least one modifier so the hotkey doesn't collide with normal typing.
        if (modifiers == 0) return;

        var keyCode = (int)e.KeyCode;
        _isRecording = false;

        // Re-confirming the combo that's already set here shouldn't have to
        // pass the availability probe below -- WSNH itself is the one
        // holding it already, so a fresh registration attempt would
        // (correctly, but unhelpfully) report it as taken.
        var isUnchanged = keyCode == KeyCode && modifiers == ModifierFlags;

        // Refuse anything that's already a standard Windows/app editing
        // shortcut (Ctrl+C, Alt+Tab, etc.) -- WSNH registering one of these
        // as a global hotkey would silently steal it everywhere, in every
        // app, for as long as WSNH is running.
        if (!isUnchanged && ReservedHotKeys.Label(keyCode, modifiers) is string reserved)
        {
            RejectCapture($"That's {reserved} — pick a different combo");
            return;
        }

        // Second check: is anything else already holding this exact combo
        // as its own global hotkey (another app, or one of WSNH's other
        // Prompt Actions/Snippets)? RegisterHotKey itself is the only
        // reliable way to know -- there's no static list for this one.
        if (!isUnchanged && !HotKeyRegistry.Shared.IsAvailable(keyCode, modifiers))
        {
            RejectCapture("That combo's already in use elsewhere — pick a different one");
            return;
        }

        KeyCode = keyCode;
        ModifierFlags = modifiers;
        RefreshLabel();
        if (!isUnchanged) ValueChanged?.Invoke();
    }

    private static uint ToHotKeyModifiers(Keys modifiers)
    {
        uint result = 0;
        if ((modifiers & Keys.Control) != 0) result |= HotKeyModifiers.Control;
        if ((modifiers & Keys.Alt) != 0) result |= HotKeyModifiers.Alt;
        if ((modifiers & Keys.Shift) != 0) result |= HotKeyModifiers.Shift;
        return result;
    }

    /// <summary>Shows a rejection reason briefly, then falls back to whatever hotkey (if any) was already set.</summary>
    private void RejectCapture(string message)
    {
        _label.Text = message;
        var timer = new System.Windows.Forms.Timer { Interval = 1800 };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            timer.Dispose();
            RefreshLabel();
        };
        timer.Start();
    }

    private void RefreshLabel()
    {
        if (_isRecording) return;
        _label.Text = KeyCode == 0 && ModifierFlags == 0
            ? "None — click to set"
            : HotKeyFormatter.ToString(KeyCode, ModifierFlags);
    }
}
