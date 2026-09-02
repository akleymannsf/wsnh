import Foundation

/// Non-secret app settings (things that don't belong in the Keychain).
/// Currently just the API base URL, which defaults to Salesforce's internal
/// LLM Gateway Express so this works out of the box for Salesforce
/// employees, but can be pointed at plain OpenAI or anything else that
/// speaks the same /v1/chat/completions API shape.
enum AppSettings {
    static let defaultBaseURL = "https://eng-ai-model-gateway.sfproxy.devx-preprod.aws-esvc1-useast2.aws.sfdc.cl/v1"

    private static let baseURLKey = "apiBaseURL"

    static var baseURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: baseURLKey)
            return (stored?.isEmpty == false) ? stored! : defaultBaseURL
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? defaultBaseURL : trimmed, forKey: baseURLKey)
        }
    }

    /// baseURL with any trailing slash removed, so callers can safely append "/chat/completions".
    static var normalizedBaseURL: String {
        var url = baseURL
        while url.hasSuffix("/") {
            url.removeLast()
        }
        return url
    }
}
