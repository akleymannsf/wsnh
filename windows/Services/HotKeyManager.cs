using WSNH.Models;

namespace WSNH.Services;

/// <summary>Registers/unregisters global hotkeys for each saved PromptAction.</summary>
public sealed class HotKeyManager
{
    public static readonly HotKeyManager Shared = new();

    private readonly Dictionary<Guid, int> _registeredIds = new();
    public Action<PromptAction>? OnTrigger { get; set; }

    private HotKeyManager() { }

    public void RegisterAll(IEnumerable<PromptAction> actions)
    {
        foreach (var id in _registeredIds.Values)
        {
            HotKeyRegistry.Shared.Unregister(id);
        }
        _registeredIds.Clear();

        foreach (var action in actions)
        {
            Register(action);
        }
    }

    public void Register(PromptAction action)
    {
        if (!action.HasHotkey) return;

        var registeredId = HotKeyRegistry.Shared.Register(action.KeyCode, action.ModifierFlags, () =>
        {
            OnTrigger?.Invoke(action);
        });

        if (registeredId is int id)
        {
            _registeredIds[action.Id] = id;
        }
    }

    public void Unregister(Guid actionId)
    {
        if (_registeredIds.TryGetValue(actionId, out var id))
        {
            HotKeyRegistry.Shared.Unregister(id);
            _registeredIds.Remove(actionId);
        }
    }
}
