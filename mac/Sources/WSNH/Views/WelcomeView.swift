import SwiftUI

/// Shown automatically the first time WSNH launches, and reachable any time
/// afterward from the menu (in case someone wants to re-read it). Written
/// for a business user who's never touched the app before — plain language,
/// no jargon, no assumed technical background.
struct WelcomeView: View {
    var onOpenPreferences: () -> Void
    var onDismiss: () -> Void

    @ObservedObject private var promptStore = PromptStore.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 36))
                            .foregroundColor(.accentColor)
                        Text("Welcome to WSNH 🦕").font(.title2).bold()
                        Text("Words Smarter, Not Harder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    section("What is WSNH?") {
                        Text("WSNH lives quietly in your menu bar — look for the ✨ wand icon near your clock, top-right of your screen. It helps you rewrite text with AI, or drop in your own ready-made text, in any app where you can type: Slack, email, Google Docs, Salesforce, wherever.")
                    }

                    section("Two ways to use it") {
                        VStack(alignment: .leading, spacing: 12) {
                            bullet(
                                "Rewrite text you've selected",
                                "Highlight some text anywhere, press a keyboard shortcut, and AI rewrites it. A small window shows you the result first, so you can review it before anything changes."
                            )
                            bullet(
                                "Insert your own saved text",
                                "Press a hotkey, or type a short shortcut, to instantly drop in text you wrote ahead of time — a signature, a boilerplate reply, anything. No AI involved, just exactly what you wrote, instantly."
                            )
                        }
                    }

                    section("What's already set up for you") {
                        VStack(alignment: .leading, spacing: 8) {
                            if promptStore.actions.isEmpty {
                                Text("Nothing's set up yet — you can add a shortcut in Preferences whenever you're ready.")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(promptStore.actions) { action in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(action.hotKeyDisplayString)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.gray.opacity(0.15))
                                            .cornerRadius(4)
                                        Text(action.name).bold()
                                    }
                                }
                                Text("To try one: select some text anywhere, press the shortcut, then click \"Paste & Replace\" on the popup that shows up.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Your own saved text (\"Snippets\") starts empty — nothing's pre-installed there, since that's meant to be your own ready-made phrases. You'll add those in Preferences whenever you're ready.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    section("Before anything works: add your API key") {
                        Text("Open Preferences (button below, or the wand icon ✨ any time) and paste your API key in under \"AI Connection.\" Nothing rewrites until that's done — everything else in this app works fine without it.")
                    }

                    section("One more thing: a permission request") {
                        Text("The first time you use a shortcut, macOS will ask whether to allow WSNH under Accessibility. That's normal and safe — it's simply what lets WSNH read what you've selected and paste results back in. Preferences always shows you whether it's currently granted.")
                    }
                }
                .padding(24)
            }

            Divider()

            HStack {
                Button("Maybe later") { onDismiss() }
                Spacer()
                Button("Open Preferences") {
                    onOpenPreferences()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 600)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(body).font(.callout).foregroundColor(.secondary)
            }
        }
    }
}
