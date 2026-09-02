using System.Text.Json;
using WSNH.Models;

namespace WSNH.Services;

/// <summary>Loads/saves the user's list of snippets as JSON in %AppData%\WSNH\snippets.json. Starts empty (no default snippets).</summary>
public sealed class SnippetStore
{
    public static readonly SnippetStore Shared = new();

    public List<Snippet> Snippets { get; private set; } = new();
    public event Action? Changed;

    private SnippetStore()
    {
        Load();
    }

    public void Load()
    {
        try
        {
            if (File.Exists(AppPaths.SnippetsFile))
            {
                var json = File.ReadAllText(AppPaths.SnippetsFile);
                var decoded = JsonSerializer.Deserialize<List<Snippet>>(json);
                if (decoded != null)
                {
                    Snippets = decoded;
                    return;
                }
            }
        }
        catch
        {
            // Fall through to an empty list.
        }
        Snippets = new List<Snippet>();
    }

    public void Save()
    {
        var json = JsonSerializer.Serialize(Snippets, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(AppPaths.SnippetsFile, json);
        Changed?.Invoke();
    }

    public void Add(Snippet snippet)
    {
        Snippets.Add(snippet);
        Save();
    }

    public void Update(Snippet snippet)
    {
        var idx = Snippets.FindIndex(s => s.Id == snippet.Id);
        if (idx >= 0)
        {
            Snippets[idx] = snippet;
            Save();
        }
    }

    public void Remove(Snippet snippet)
    {
        Snippets.RemoveAll(s => s.Id == snippet.Id);
        Save();
    }

    public void ReplaceAll(List<Snippet> snippets)
    {
        Snippets = snippets;
        Save();
    }
}
