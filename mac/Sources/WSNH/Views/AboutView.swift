import SwiftUI

/// The "About WSNH" panel: version, last-updated date, and a credit line.
struct AboutView: View {
    private static let creditLinkURL = URL(string: "https://salesforce.enterprise.slack.com/team/U01G89VU4N7")!

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            VStack(spacing: 2) {
                Text("WSNH").font(.title2).bold()
                Text("Words Smarter, Not Harder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                Text("Version \(Self.versionString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Last updated \(Self.lastUpdatedString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 4) {
                Text("Created with ❤️ and SE Smarts by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("Amelia Ochodnicky", destination: Self.creditLinkURL)
                    .font(.caption)
            }
        }
        .padding(28)
        .frame(width: 300)
    }

    /// Reads CFBundleShortVersionString (and the build number, if it differs)
    /// straight from the app's own Info.plist -- no separate value to keep in sync.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let buildNumber = info?["CFBundleVersion"] as? String
        if let buildNumber, buildNumber != shortVersion {
            return "\(shortVersion) (\(buildNumber))"
        }
        return shortVersion
    }

    /// The compiled binary's own last-modified date -- automatically reflects
    /// whenever this build was produced, with nothing to remember to update by hand.
    private static var lastUpdatedString: String {
        guard
            let executablePath = Bundle.main.executablePath,
            let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath),
            let modificationDate = attributes[.modificationDate] as? Date
        else {
            return "unknown"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }
}
