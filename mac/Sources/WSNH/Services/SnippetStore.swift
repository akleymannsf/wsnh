import AppKit

/// Loads/saves the user's list of snippets as JSON in
/// ~/Library/Application Support/WSNH/snippets.json. Mirrors PromptStore's
/// persistence pattern. No snippets are seeded by default -- unlike Prompt
/// Actions, these are entirely personal templates.
final class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    @Published var snippets: [Snippet] = []

    private let fileURL: URL

    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WSNH", isDirectory: true)
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        fileURL = appSupport.appendingPathComponent("snippets.json")
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = decoded
        } else {
            snippets = []
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        save()
    }

    func update(_ snippet: Snippet) {
        if let idx = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[idx] = snippet
            save()
        }
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }

    /// Wholesale replacement, used when restoring a backup.
    func replaceAll(_ snippets: [Snippet]) {
        self.snippets = snippets
        save()
    }
}
