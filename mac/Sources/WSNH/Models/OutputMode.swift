import Foundation

/// What WSNH should do with the AI's rewritten text once it comes back.
enum OutputMode: String, Codable, CaseIterable, Identifiable {
    case autoPaste
    case popup
    case ask

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoPaste: return "Auto-paste in place"
        case .popup: return "Show popup to review"
        case .ask: return "Ask each time"
        }
    }
}
