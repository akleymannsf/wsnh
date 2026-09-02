namespace WSNH.Services;

/// <summary>Central place for where WSNH stores its data on disk.</summary>
public static class AppPaths
{
    public static string AppDataFolder
    {
        get
        {
            var folder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "WSNH");
            Directory.CreateDirectory(folder);
            return folder;
        }
    }

    public static string SettingsFile => Path.Combine(AppDataFolder, "settings.json");
    public static string PromptsFile => Path.Combine(AppDataFolder, "prompts.json");
    public static string SnippetsFile => Path.Combine(AppDataFolder, "snippets.json");
}
