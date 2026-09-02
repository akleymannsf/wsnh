using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace WSNH.Services;

/// <summary>
/// Thin wrapper around user32.dll's RegisterHotKey/UnregisterHotKey, backed
/// by a single hidden message-only window that receives WM_HOTKEY. Both
/// HotKeyManager (Prompt Actions) and SnippetHotKeyManager (Snippets) sit on
/// top of this shared registry rather than each creating their own window.
///
/// Unlike macOS's Carbon RegisterEventHotKey (which happily lets an app
/// "steal" ordinary shortcuts like Cmd+V with no error at all), Windows'
/// RegisterHotKey already refuses a combo outright if another process has
/// it -- so this doubles as the live conflict-availability check the hotkey
/// recorder uses before letting you save a new combo.
/// </summary>
public sealed class HotKeyRegistry
{
    public static readonly HotKeyRegistry Shared = new();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private const int WM_HOTKEY = 0x0312;

    private sealed class MessageWindow : NativeWindow
    {
        public event Action<int>? HotKeyPressed;

        public MessageWindow()
        {
            // No WS_VISIBLE style, so this never actually shows on screen --
            // it exists purely so Windows has an HWND to post WM_HOTKEY to.
            CreateHandle(new CreateParams());
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY)
            {
                HotKeyPressed?.Invoke(m.WParam.ToInt32());
            }
            base.WndProc(ref m);
        }
    }

    private readonly MessageWindow _window;
    private readonly Dictionary<int, Action> _handlers = new();
    private int _nextId = 1;

    private HotKeyRegistry()
    {
        _window = new MessageWindow();
        _window.HotKeyPressed += id =>
        {
            if (_handlers.TryGetValue(id, out var handler))
            {
                handler();
            }
        };
    }

    /// <summary>
    /// Registers keyCode+modifiers as a new global hotkey. Returns the id to
    /// pass to Unregister on success, or null if the OS refused it (already
    /// claimed by another app or another WSNH hotkey).
    /// </summary>
    public int? Register(int keyCode, uint modifiers, Action onPressed)
    {
        int id = _nextId++;
        if (!RegisterHotKey(_window.Handle, id, modifiers | HotKeyModifiers.NoRepeat, (uint)keyCode))
        {
            return null;
        }
        _handlers[id] = onPressed;
        return id;
    }

    public void Unregister(int id)
    {
        UnregisterHotKey(_window.Handle, id);
        _handlers.Remove(id);
    }

    /// <summary>
    /// Briefly registers and immediately releases a combo purely to test
    /// whether the OS would allow it right now.
    /// </summary>
    public bool IsAvailable(int keyCode, uint modifiers)
    {
        int probeId = _nextId++;
        bool ok = RegisterHotKey(_window.Handle, probeId, modifiers | HotKeyModifiers.NoRepeat, (uint)keyCode);
        if (ok)
        {
            UnregisterHotKey(_window.Handle, probeId);
        }
        return ok;
    }
}
