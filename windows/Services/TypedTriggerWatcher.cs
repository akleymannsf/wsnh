using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using WSNH.Models;

namespace WSNH.Services;

/// <summary>
/// Watches every keystroke system-wide (via a low-level keyboard hook) for a
/// defined typed shortcut. When a shortcut is typed and confirmed with a
/// delimiter key (space/tab/enter/comma/period), it deletes what was typed
/// and pastes the linked snippet in its place.
///
/// Windows never delivers keystrokes typed into most secure/protected
/// password fields to a low-level hook (Credential UI, some browser
/// password fields), so this can't see those by design -- nothing extra to
/// handle there.
/// </summary>
public sealed class TypedTriggerWatcher
{
    public static readonly TypedTriggerWatcher Shared = new();

    private const int WhKeyboardLl = 13;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;
    private const uint LlkhfInjected = 0x00000010;
    private const int VkControl = 0x11;
    private const int VkLwin = 0x5B;
    private const int VkRwin = 0x5C;
    private const int VkBack = 0x08;
    private const int VkSpace = 0x20;
    private const int VkTab = 0x09;
    private const int VkReturn = 0x0D;
    private const int VkOemComma = 0xBC;
    private const int VkOemPeriod = 0xBE;

    private static readonly HashSet<int> DelimiterVirtualKeys = new()
    {
        VkSpace, VkTab, VkReturn, VkOemComma, VkOemPeriod
    };

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern short GetKeyState(int nVirtKey);

    [DllImport("user32.dll")]
    private static extern bool GetKeyboardState(byte[] lpKeyState);

    [DllImport("user32.dll")]
    private static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
        [Out, MarshalAs(UnmanagedType.LPWStr, SizeParamIndex = 4)] StringBuilder pwszBuff,
        int cchBuff, uint wFlags);

    // Kept alive for the lifetime of the app so the GC never collects it out
    // from under the hook -- a common and very easy-to-hit source of
    // "the hook mysteriously stops firing" bugs with SetWindowsHookEx.
    private LowLevelKeyboardProc? _proc;
    private IntPtr _hookHandle = IntPtr.Zero;

    private string _buffer = "";
    private const int MaxBufferLength = 60;
    private Dictionary<string, Snippet> _shortcuts = new();

    private TypedTriggerWatcher() { }

    /// <summary>Refreshes the set of shortcuts to watch for. Safe to call any time the snippet list changes.</summary>
    public void ReloadShortcuts(IEnumerable<Snippet> snippets)
    {
        var map = new Dictionary<string, Snippet>();
        foreach (var snippet in snippets)
        {
            var trimmed = snippet.Shortcut.Trim();
            if (trimmed.Length == 0) continue;
            map[trimmed] = snippet;
        }
        _shortcuts = map;
    }

    /// <summary>
    /// Starts the watcher. Safe to call once at startup -- unlike the Mac
    /// build, Windows doesn't gate this behind a separate permission grant,
    /// so there's no "if permitted" check needed here.
    /// </summary>
    public void Start()
    {
        if (_hookHandle != IntPtr.Zero) return;
        _proc = HookCallback;
        var hInstance = Marshal.GetHINSTANCE(typeof(TypedTriggerWatcher).Module);
        _hookHandle = SetWindowsHookEx(WhKeyboardLl, _proc, hInstance, 0);
    }

    public void Stop()
    {
        if (_hookHandle == IntPtr.Zero) return;
        UnhookWindowsHookEx(_hookHandle);
        _hookHandle = IntPtr.Zero;
    }

    public void ClearBuffer() => _buffer = "";

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        // Always chain along immediately if this isn't a key-down we care
        // about -- a low-level hook that runs slow risks Windows treating
        // the whole hook as unresponsive and detaching it, and can stall
        // system-wide keyboard delivery while it's running (the same class
        // of problem already fixed on the Mac side).
        if (nCode < 0 || (wParam != WmKeyDown && wParam != WmSysKeyDown))
        {
            return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
        }

        try
        {
            var hookStruct = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);

            // Ignore keystrokes WSNH generated itself (the synthetic
            // backspaces, paste, and retyped delimiter it sends while
            // expanding a snippet) so it never reacts to its own simulated
            // input.
            if (hookStruct.dwExtraInfo == NativeInput.WsnhExtraInfo ||
                (hookStruct.flags & LlkhfInjected) != 0)
            {
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
            }

            if (_shortcuts.Count == 0)
            {
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
            }

            var vk = (int)hookStruct.vkCode;

            var ctrlOrWinHeld = (GetKeyState(VkControl) & 0x8000) != 0
                || (GetKeyState(VkLwin) & 0x8000) != 0
                || (GetKeyState(VkRwin) & 0x8000) != 0;
            if (ctrlOrWinHeld)
            {
                _buffer = "";
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
            }

            if (vk == VkBack)
            {
                if (_buffer.Length > 0) _buffer = _buffer[..^1];
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
            }

            if (DelimiterVirtualKeys.Contains(vk))
            {
                if (_shortcuts.TryGetValue(_buffer, out var snippet))
                {
                    var deleteCount = _buffer.Length + 1; // the shortcut plus the delimiter already typed
                    _buffer = "";
                    SnippetInserter.ExpandTypedTrigger(snippet, deleteCount, (ushort)vk);
                }
                else
                {
                    _buffer = "";
                }
                return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
            }

            var character = ResolveCharacter(hookStruct.vkCode, hookStruct.scanCode);
            if (!string.IsNullOrEmpty(character))
            {
                _buffer += character;
                if (_buffer.Length > MaxBufferLength)
                {
                    _buffer = _buffer[^MaxBufferLength..];
                }
            }
        }
        catch
        {
            // Never let an unexpected error here take down the hook chain
            // (or, worse, the whole system's keyboard input).
        }

        return CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    /// <summary>
    /// Resolves the actual character a keydown produces, respecting the
    /// current keyboard layout and modifier state (Shift, AltGr, etc.) --
    /// the Windows equivalent of CGEvent's keyboardGetUnicodeString on Mac.
    /// </summary>
    private static string ResolveCharacter(uint vkCode, uint scanCode)
    {
        var keyboardState = new byte[256];
        if (!GetKeyboardState(keyboardState)) return "";

        var buffer = new StringBuilder(8);
        var result = ToUnicode(vkCode, scanCode, keyboardState, buffer, buffer.Capacity, 0);
        return result > 0 ? buffer.ToString(0, result) : "";
    }
}
