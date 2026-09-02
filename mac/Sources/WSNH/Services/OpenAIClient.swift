import Foundation

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key set. Add one in Preferences."
        case .requestFailed(let message):
            return message
        case .emptyResponse:
            return "OpenAI returned an empty response."
        }
    }
}

/// URLSession strips the Authorization header whenever it automatically
/// follows an HTTP redirect (a documented Apple security behavior, even for
/// same-host redirects). Some proxies/load balancers issue a redirect before
/// reaching the real endpoint, which would otherwise turn a valid API key
/// into a request with no Authorization header at all — surfacing as an
/// "authentication error" / "no api key passed in" from the server even
/// though the key is correct. This delegate re-attaches the original
/// Authorization header to any redirected request.
private final class AuthPreservingRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirected = request
        if let auth = task.originalRequest?.value(forHTTPHeaderField: "Authorization") {
            redirected.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        completionHandler(redirected)
    }
}

/// Thin wrapper around the OpenAI Chat Completions API.
enum OpenAIClient {
    static func run(model: String, promptTemplate: String, selectedText: String) async throws -> String {
        guard let rawAPIKey = KeychainHelper.loadAPIKey() else {
            throw OpenAIError.missingAPIKey
        }
        // Defensively strip whitespace/newlines: a stray trailing newline from
        // copy-pasting a key is common, and Foundation silently drops the
        // Authorization header entirely if it contains a raw newline rather
        // than sending it malformed — which the server reports as "no api key
        // passed in," even though a key was technically saved.
        let apiKey = rawAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        let filledPrompt = promptTemplate.replacingOccurrences(of: "{selectedText}", with: selectedText)

        guard let requestURL = URL(string: "\(AppSettings.normalizedBaseURL)/chat/completions") else {
            throw OpenAIError.requestFailed("The API base URL in Preferences doesn't look like a valid URL.")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": filledPrompt]
            ],
            "temperature": 0.7
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = URLSession(configuration: .default, delegate: AuthPreservingRedirectDelegate(), delegateQueue: nil)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed("No response from server.")
        }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw OpenAIError.requestFailed(message ?? "OpenAI request failed with status \(http.statusCode).")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw OpenAIError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
