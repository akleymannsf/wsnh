import Foundation

/// Everything needed to fully restore WSNH's state: the API key, the API
/// base URL, every saved prompt action, and every saved snippet.
struct BackupPayload: Codable {
    var version: Int = 2
    var platform: String = "mac"
    var exportedAt: Date = Date()
    var apiKey: String?
    var baseURL: String
    var actions: [PromptAction]
    var snippets: [Snippet] = []

    init(
        version: Int = 2,
        platform: String = "mac",
        exportedAt: Date = Date(),
        apiKey: String? = nil,
        baseURL: String,
        actions: [PromptAction],
        snippets: [Snippet] = []
    ) {
        self.version = version
        self.platform = platform
        self.exportedAt = exportedAt
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.actions = actions
        self.snippets = snippets
    }

    enum CodingKeys: String, CodingKey {
        case version, platform, exportedAt, apiKey, baseURL, actions, snippets
    }

    // Custom decoding so backups made before Snippets existed (version 1,
    // no "snippets" key at all) still import cleanly instead of failing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "mac"
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        actions = try container.decode([PromptAction].self, forKey: .actions)
        snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
    }
}

enum BackupError: LocalizedError {
    case invalidFile
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "That file doesn't look like a WSNH backup."
        case .emptyBackup:
            return "That backup doesn't contain any prompt actions or snippets."
        }
    }
}

enum BackupManager {
    static func exportData() -> Data {
        let payload = BackupPayload(
            apiKey: KeychainHelper.loadAPIKey(),
            baseURL: AppSettings.baseURL,
            actions: PromptStore.shared.actions,
            snippets: SnippetStore.shared.snippets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }

    /// Returns the restored payload's platform tag, so the caller can warn
    /// if it doesn't match this platform (hotkeys don't translate across
    /// Mac/Windows virtual-key numbering, even though the key and prompts do).
    @discardableResult
    static func restore(from data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupError.invalidFile
        }
        guard !payload.actions.isEmpty || !payload.snippets.isEmpty else {
            throw BackupError.emptyBackup
        }

        if let key = payload.apiKey {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                KeychainHelper.saveAPIKey(trimmedKey)
            }
        }
        AppSettings.baseURL = payload.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        PromptStore.shared.actions = payload.actions
        PromptStore.shared.save()
        HotKeyManager.shared.registerAll(PromptStore.shared.actions)

        SnippetStore.shared.replaceAll(payload.snippets)
        SnippetHotKeyManager.shared.registerAll(SnippetStore.shared.snippets)
        TypedTriggerWatcher.shared.reloadShortcuts(SnippetStore.shared.snippets)

        return payload
    }
}
