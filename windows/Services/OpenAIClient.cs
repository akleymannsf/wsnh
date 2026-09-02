using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace WSNH.Services;

public class OpenAIException : Exception
{
    public OpenAIException(string message) : base(message) { }
}

/// <summary>
/// Thin wrapper around the OpenAI-shaped Chat Completions API (works with
/// plain OpenAI or Salesforce's internal LLM Gateway Express, which speaks
/// the same request/response shape).
///
/// .NET's HttpClient does not reliably re-attach the Authorization header
/// when automatically following an HTTP redirect (behavior here has shifted
/// across .NET versions, and some proxies/load balancers issue a redirect
/// before reaching the real endpoint). Rather than depend on that, redirects
/// are followed manually below so the original Authorization header is
/// always preserved -- otherwise a valid API key can silently turn into a
/// request with no Authorization header at all, which the server reports as
/// an authentication error / "no api key passed in" even though the key is
/// correct. This mirrors the same fix already applied on the Mac side.
/// </summary>
public static class OpenAIClient
{
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false });

    public static async Task<string> RunAsync(string model, string promptTemplate, string selectedText)
    {
        var rawApiKey = SettingsStore.GetApiKey();
        if (string.IsNullOrEmpty(rawApiKey))
        {
            throw new OpenAIException("No API key set. Add one in Preferences.");
        }

        // Defensively strip whitespace/newlines -- a stray trailing newline
        // from copy-pasting a key is common, and a raw newline in a header
        // value gets rejected/stripped, which the server reports as "no api
        // key passed in" even though a key was technically saved.
        var apiKey = rawApiKey.Trim();
        if (apiKey.Length == 0)
        {
            throw new OpenAIException("No API key set. Add one in Preferences.");
        }

        var filledPrompt = promptTemplate.Replace("{selectedText}", selectedText);

        var body = new
        {
            model,
            messages = new[] { new { role = "user", content = filledPrompt } },
            temperature = 0.7
        };
        var bodyJson = JsonSerializer.Serialize(body);

        var url = $"{SettingsStore.NormalizedBaseUrl}/chat/completions";
        var (status, responseBody) = await SendWithRedirectsAsync(url, apiKey, bodyJson);

        if (status < 200 || status >= 300)
        {
            string? message = null;
            try
            {
                using var doc = JsonDocument.Parse(responseBody);
                if (doc.RootElement.TryGetProperty("error", out var error) &&
                    error.TryGetProperty("message", out var msg))
                {
                    message = msg.GetString();
                }
            }
            catch { /* fall back to the generic message below */ }

            throw new OpenAIException(message ?? $"Request failed with status {status}.");
        }

        try
        {
            using var doc = JsonDocument.Parse(responseBody);
            var content = doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString();

            if (string.IsNullOrEmpty(content))
            {
                throw new OpenAIException("The API returned an empty response.");
            }
            return content.Trim();
        }
        catch (Exception ex) when (ex is not OpenAIException)
        {
            throw new OpenAIException("The API returned an empty or unexpected response.");
        }
    }

    private static async Task<(int status, string body)> SendWithRedirectsAsync(string url, string apiKey, string bodyJson)
    {
        const int maxRedirects = 5;
        var currentUrl = url;

        for (var i = 0; i < maxRedirects; i++)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, currentUrl);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            request.Content = new StringContent(bodyJson, Encoding.UTF8, "application/json");

            using var response = await Http.SendAsync(request);
            var responseText = await response.Content.ReadAsStringAsync();

            if (IsRedirect(response.StatusCode) && response.Headers.Location != null)
            {
                currentUrl = response.Headers.Location.IsAbsoluteUri
                    ? response.Headers.Location.ToString()
                    : new Uri(new Uri(currentUrl), response.Headers.Location).ToString();
                continue;
            }

            return ((int)response.StatusCode, responseText);
        }

        throw new OpenAIException("Too many redirects while contacting the API base URL.");
    }

    private static bool IsRedirect(HttpStatusCode code) =>
        code is HttpStatusCode.MovedPermanently or HttpStatusCode.Found or HttpStatusCode.SeeOther
            or HttpStatusCode.TemporaryRedirect or HttpStatusCode.PermanentRedirect;
}
