using WSNH.Models;

namespace WSNH.Services;

/// <summary>Registers/unregisters global hotkeys for each saved Snippet.</summary>
public sealed class SnippetHotKeyManager
{
    public static readonly SnippetHotKeyManager Shared = new();

    private readonly Dictionary<Guid, int> _registeredIds = new();
    public Action<Snippet>? OnTrigger { get; set; }

    private SnippetHotKeyManager() { }

    public void RegisterAll(IEnumerable<Snippet> snippets)
    {
        foreach (var id in _registeredIds.Values)
        {
            HotKeyRegistry.Shared.Unregister(id);
        }
        _registeredIds.Clear();

        foreach (var snippet in snippets)
        {
            Register(snippet);
        }
    }

    public void Register(Snippet snippet)
    {
        if (!snippet.HasHotkey) return;

        var registeredId = HotKeyRegistry.Shared.Register(snippet.KeyCode, snippet.ModifierFlags, () =>
        {
            OnTrigger?.Invoke(snippet);
        });

        if (registeredId is int id)
        {
            _registeredIds[snippet.Id] = id;
        }
    }

    public void Unregister(Guid snippetId)
    {
        if (_registeredIds.TryGetValue(snippetId, out var id))
        {
            HotKeyRegistry.Shared.Unregister(id);
            _registeredIds.Remove(snippetId);
        }
    }
}
