using System.Runtime.InteropServices;

namespace WSNH.Services;

/// <summary>Low-level SendInput wrapper for simulating key presses (Ctrl+C, Ctrl+V, Backspace, ...).</summary>
public static class NativeInput
{
    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    private const uint InputKeyboard = 1;
    private const uint KeyEventFKeyUp = 0x0002;
    // A sentinel value stamped on every event WSNH generates itself, so the
    // typed-shortcut watcher's low-level hook can tell "the app just pasted
    // a snippet" apart from "the user is actually typing" and ignore it.
    public static readonly IntPtr WsnhExtraInfo = (IntPtr)0x57534E48; // "WSNH" packed as hex

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    private static INPUT KeyInput(ushort vk, bool keyUp) => new()
    {
        type = InputKeyboard,
        U = new InputUnion
        {
            ki = new KEYBDINPUT
            {
                wVk = vk,
                wScan = 0,
                dwFlags = keyUp ? KeyEventFKeyUp : 0,
                time = 0,
                dwExtraInfo = WsnhExtraInfo
            }
        }
    };

    private static void SendCombo(params ushort[] vks)
    {
        var inputs = new List<INPUT>();
        foreach (var vk in vks) inputs.Add(KeyInput(vk, keyUp: false));
        for (var i = vks.Length - 1; i >= 0; i--) inputs.Add(KeyInput(vks[i], keyUp: true));
        SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
    }

    private const ushort VkControl = 0x11;
    private const ushort VkC = 0x43;
    private const ushort VkV = 0x56;
    private const ushort VkBack = 0x08;

    public static void SendCopy() => SendCombo(VkControl, VkC);
    public static void SendPaste() => SendCombo(VkControl, VkV);

    public static void SendBackspaces(int count)
    {
        var inputs = new List<INPUT>();
        for (var i = 0; i < count; i++)
        {
            inputs.Add(KeyInput(VkBack, keyUp: false));
            inputs.Add(KeyInput(VkBack, keyUp: true));
        }
        if (inputs.Count > 0)
        {
            SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
        }
    }

    public static void SendKeyTap(ushort vk)
    {
        SendCombo(vk);
    }
}
