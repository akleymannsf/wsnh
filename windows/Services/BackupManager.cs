using System.Text.Json;
using System.Text.Json.Serialization;
using WSNH.Models;

namespace WSNH.Services;

/// <summary>Everything needed to fully restore WSNH's state: the API key, the API base URL, every saved prompt action, and every saved snippet.</summary>
public class BackupPayload
{
    public int Version { get; set; } = 2;
    public string Platform { get; set; } = "windows";
    public DateTimeOffset ExportedAt { get; set; } = DateTimeOffset.UtcNow;
    public string? ApiKey { get; set; }
    public string BaseUrl { get; set; } = SettingsStore.DefaultBaseUrl;
    public List<PromptAction> Actions { get; set; } = new();
    public List<Snippet> Snippets { get; set; } = new();
}

public class BackupException : Exception
{
    public BackupException(string message) : base(message) { }
}

public static class BackupManager
{
    private static readonly JsonSerializerOptions ExportOptions = new()
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never
    };

    public static string ExportData()
    {
        var payload = new BackupPayload
        {
            ApiKey = SettingsStore.GetApiKey(),
            BaseUrl = SettingsStore.BaseUrl,
            Actions = PromptStore.Shared.Actions,
            Snippets = SnippetStore.Shared.Snippets
        };
        return JsonSerializer.Serialize(payload, ExportOptions);
    }

    /// <summary>
    /// Restores from a backup file's contents. Returns the restored
    /// payload's platform tag so the caller can warn if it doesn't match
    /// this platform -- hotkeys don't translate across Mac/Windows virtual
    /// key numbering, even though the key and prompts do.
    /// </summary>
    public static BackupPayload Restore(string json)
    {
        BackupPayload? payload;
        try
        {
            payload = JsonSerializer.Deserialize<BackupPayload>(json);
        }
        catch
        {
            throw new BackupException("That file doesn't look like a WSNH backup.");
        }

        if (payload == null)
        {
            throw new BackupException("That file doesn't look like a WSNH backup.");
        }
        if (payload.Actions.Count == 0 && payload.Snippets.Count == 0)
        {
            throw new BackupException("That backup doesn't contain any prompt actions or snippets.");
        }

        if (!string.IsNullOrWhiteSpace(payload.ApiKey))
        {
            SettingsStore.SetApiKey(payload.ApiKey.Trim());
        }
        SettingsStore.BaseUrl = payload.BaseUrl.Trim();

        // Hotkeys from a Mac backup won't mean what they say (Carbon virtual
        // key numbering doesn't match Windows' Keys enum values) -- importing
        // them as-is would silently bind wrong/garbage combos. Drop them and
        // let the prompt/snippet content still come across cleanly; the
        // caller's UI is responsible for telling the user to re-set hotkeys
        // when payload.Platform != "windows".
        var actions = payload.Actions;
        var snippets = payload.Snippets;
        if (!string.Equals(payload.Platform, "windows", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var action in actions) { action.KeyCode = 0; action.ModifierFlags = 0; }
            foreach (var snippet in snippets) { snippet.KeyCode = 0; snippet.ModifierFlags = 0; }
        }

        PromptStore.Shared.ReplaceAll(actions);
        HotKeyManager.Shared.RegisterAll(PromptStore.Shared.Actions);

        SnippetStore.Shared.ReplaceAll(snippets);
        SnippetHotKeyManager.Shared.RegisterAll(SnippetStore.Shared.Snippets);
        TypedTriggerWatcher.Shared.ReloadShortcuts(SnippetStore.Shared.Snippets);

        return payload;
    }
}
