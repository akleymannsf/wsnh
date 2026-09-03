using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace WSNH.Services;

internal class SettingsData
{
    public string? ProtectedApiKeyBase64 { get; set; }
    public string? BaseUrl { get; set; }
    public bool HasShownWelcome { get; set; }
}

/// <summary>
/// Non-secret and secret app settings. The API key is encrypted at rest with
/// Windows DPAPI (tied to the signed-in Windows user account) before being
/// written to settings.json -- the closest Windows equivalent to storing it
/// in the Mac app's Keychain.
///
/// The base URL defaults to Salesforce's internal LLM Gateway Express so
/// this works out of the box for Salesforce employees, but can be pointed at
/// plain OpenAI or anything else that speaks the same /v1/chat/completions
/// API shape.
/// </summary>
public static class SettingsStore
{
    public const string DefaultBaseUrl = "https://eng-ai-model-gateway.sfproxy.devx-preprod.aws-esvc1-useast2.aws.sfdc.cl/v1";

    private static SettingsData _data = Load();

    private static SettingsData Load()
    {
        try
        {
            if (File.Exists(AppPaths.SettingsFile))
            {
                var json = File.ReadAllText(AppPaths.SettingsFile);
                var loaded = JsonSerializer.Deserialize<SettingsData>(json);
                if (loaded != null) return loaded;
            }
        }
        catch
        {
            // Fall through to defaults -- a corrupt settings file shouldn't
            // prevent the app from launching.
        }
        return new SettingsData();
    }

    private static void Save()
    {
        var json = JsonSerializer.Serialize(_data, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(AppPaths.SettingsFile, json);
    }

    public static string BaseUrl
    {
        get => string.IsNullOrWhiteSpace(_data.BaseUrl) ? DefaultBaseUrl : _data.BaseUrl!;
        set
        {
            var trimmed = value.Trim();
            _data.BaseUrl = string.IsNullOrEmpty(trimmed) ? null : trimmed;
            Save();
        }
    }

    /// <summary>BaseUrl with any trailing slash removed, so callers can safely append "/chat/completions".</summary>
    public static string NormalizedBaseUrl => BaseUrl.TrimEnd('/');

    public static bool HasShownWelcome
    {
        get => _data.HasShownWelcome;
        set { _data.HasShownWelcome = value; Save(); }
    }

    /// <summary>Returns the saved API key, or null if none is set.</summary>
    public static string? GetApiKey()
    {
        if (string.IsNullOrEmpty(_data.ProtectedApiKeyBase64)) return null;
        try
        {
            var protectedBytes = Convert.FromBase64String(_data.ProtectedApiKeyBase64);
            var plainBytes = ProtectedData.Unprotect(protectedBytes, null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plainBytes);
        }
        catch
        {
            // Most likely cause: the settings file was copied from another
            // machine/user account via a restored backup. DPAPI keys are
            // tied to the specific Windows account that encrypted them, so
            // this can't be decrypted here -- treat it as "not set" rather
            // than crashing.
            return null;
        }
    }

    public static void SetApiKey(string apiKey)
    {
        var trimmed = apiKey.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            _data.ProtectedApiKeyBase64 = null;
        }
        else
        {
            var plainBytes = Encoding.UTF8.GetBytes(trimmed);
            var protectedBytes = ProtectedData.Protect(plainBytes, null, DataProtectionScope.CurrentUser);
            _data.ProtectedApiKeyBase64 = Convert.ToBase64String(protectedBytes);
        }
        Save();
    }
}
