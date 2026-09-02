import SwiftUI
import AppKit

/// A small rich-text editor (bold/italic/underline/links) for authoring
/// Snippet content, backed by an NSTextView. Keeps both an RTF blob (the
/// source of truth for formatting) and a plain-text fallback in sync.
struct RichTextEditorView: View {
    @Binding var rtfData: Data
    @Binding var plainText: String

    @State private var textView: NSTextView?
    @State private var hasSelection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button { toggleBold() } label: { Image(systemName: "bold") }
                    .help("Bold")
                Button { toggleItalic() } label: { Image(systemName: "italic") }
                    .help("Italic")
                Button { toggleUnderline() } label: { Image(systemName: "underline") }
                    .help("Underline")
                Divider().frame(height: 16)
                Button { insertLink() } label: { Image(systemName: "link") }
                    .help("Add a link to the selected text")
                Spacer()
            }
            .buttonStyle(.bordered)
            .disabled(textView == nil || !hasSelection)

            RichTextViewRepresentable(
                initialRTFData: rtfData,
                onTextViewReady: { view in textView = view },
                onChange: { newRTF, newPlainText in
                    rtfData = newRTF
                    plainText = newPlainText
                },
                onSelectionChange: { selected in
                    hasSelection = selected
                }
            )
            .frame(minHeight: 180)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

            Text(hasSelection
                 ? "Now click a button above to format the highlighted text."
                 : "To format text (bold, links, etc.): click and drag over some text below to highlight it first — the buttons above light up once something's selected.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Formatting actions (act on the current selection in textView)

    private func toggleBold() {
        toggleTrait(.boldFontMask, symbolic: .bold)
    }

    private func toggleItalic() {
        toggleTrait(.italicFontMask, symbolic: .italic)
    }

    private func toggleTrait(_ mask: NSFontTraitMask, symbolic: NSFontDescriptor.SymbolicTraits) {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        let manager = NSFontManager.shared

        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let hasTrait = font.fontDescriptor.symbolicTraits.contains(symbolic)
            let newFont = hasTrait ? manager.convert(font, toNotHaveTrait: mask) : manager.convert(font, toHaveTrait: mask)
            storage.addAttribute(.font, value: newFont, range: subrange)
        }
        syncBindings(from: textView)
    }

    private func toggleUnderline() {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let currentStyle = (storage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int) ?? 0
        let newStyle = currentStyle == 0 ? NSUnderlineStyle.single.rawValue : 0
        storage.addAttribute(.underlineStyle, value: newStyle, range: range)
        syncBindings(from: textView)
    }

    /// Presented as a sheet attached to the snippet editor's own window
    /// (rather than a free-floating `NSAlert.runModal()`), so it always
    /// appears on the same screen as the window you're actually looking at
    /// -- important on multi-monitor setups, where a detached modal alert
    /// can pop up on a screen you're not looking at and make the whole app
    /// appear to have frozen.
    private func insertLink() {
        guard let textView, let storage = textView.textStorage, let window = textView.window else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let alert = NSAlert()
        alert.messageText = "Add Link"
        alert.informativeText = "Enter the URL for the selected text."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(string: "https://")
        input.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let urlString = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !urlString.isEmpty, let url = URL(string: urlString) else { return }

            storage.addAttribute(.link, value: url, range: range)
            self.syncBindings(from: textView)
        }
    }

    private func syncBindings(from textView: NSTextView) {
        plainText = textView.string
        if let data = try? textView.attributedString().data(
            from: NSRange(location: 0, length: textView.attributedString().length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            rtfData = data
        }
    }
}

/// Thin NSViewRepresentable wrapper around an NSTextView configured for rich
/// text editing. Deliberately one-way after initial load: typing/formatting
/// pushes changes out via `onChange`, but SwiftUI state changes never push
/// back into the NSTextView (which would clobber the cursor position and
/// undo stack on every re-render). Each Add/Edit sheet gets a fresh instance,
/// so this only ever needs to load its initial content once.
private struct RichTextViewRepresentable: NSViewRepresentable {
    var initialRTFData: Data
    var onTextViewReady: (NSTextView) -> Void
    var onChange: (Data, String) -> Void
    var onSelectionChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.delegate = context.coordinator

        if !initialRTFData.isEmpty,
           let attributed = try? NSAttributedString(
               data: initialRTFData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            textView.textStorage?.setAttributedString(attributed)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        DispatchQueue.main.async {
            onTextViewReady(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Intentionally empty -- see the "Deliberately one-way" note above.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onSelectionChange: onSelectionChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (Data, String) -> Void
        var onSelectionChange: (Bool) -> Void

        init(onChange: @escaping (Data, String) -> Void, onSelectionChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            self.onSelectionChange = onSelectionChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let plainText = textView.string
            let data = try? textView.attributedString().data(
                from: NSRange(location: 0, length: textView.attributedString().length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            onChange(data ?? Data(), plainText)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            onSelectionChange(textView.selectedRange().length > 0)
        }
    }
}
