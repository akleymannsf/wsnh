namespace WSNH.Services;

/// <summary>MOD_* flags as defined by user32.dll's RegisterHotKey.</summary>
public static class HotKeyModifiers
{
    public const uint Alt = 0x0001;
    public const uint Control = 0x0002;
    public const uint Shift = 0x0004;
    public const uint Win = 0x0008;
    /// <summary>Suppresses OS auto-repeat while the key is held. Applied automatically at registration time; not part of a saved combo's identity.</summary>
    public const uint NoRepeat = 0x4000;
}
