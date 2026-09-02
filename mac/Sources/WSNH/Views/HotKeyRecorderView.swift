import SwiftUI
import AppKit

/// A small control you click, then press a key combo (with at least one
/// modifier) to record a new global hotkey.
struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifierFlags: UInt

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.currentKeyCode = keyCode
        view.currentModifierFlags = modifierFlags
        view.onCapture = { newKeyCode, newModifiers in
            keyCode = newKeyCode
            modifierFlags = newModifiers
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.currentKeyCode = keyCode
        nsView.currentModifierFlags = modifierFlags
        nsView.refreshLabel()
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((UInt32, UInt) -> Void)?
    var currentKeyCode: UInt32 = 0
    var currentModifierFlags: UInt = 0

    private var isRecording = false
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        label.alignment = .center
        addSubview(label)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        let click = NSClickGestureRecognizer(target: self, action: #selector(startRecording))
        addGestureRecognizer(click)
        refreshLabel()
    }

    func refreshLabel() {
        guard !isRecording else { return }
        // 0/0 (no modifiers, keyCode 0 == the 'A' key) only ever happens
        // when nothing has been set yet -- a real hotkey always has at
        // least one modifier, since keyDown below requires it. Showing
        // "None" here avoids it looking like "A" is already bound.
        if currentKeyCode == 0 && currentModifierFlags == 0 {
            label.stringValue = "None — click to set"
        } else {
            label.stringValue = HotKeyFormatter.string(keyCode: currentKeyCode, modifierFlags: currentModifierFlags)
        }
    }

    @objc private func startRecording() {
        isRecording = true
        label.stringValue = "Press a key combo…"
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        // Require at least one modifier so the hotkey doesn't collide with normal typing.
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return }

        let newKeyCode = UInt32(event.keyCode)
        isRecording = false

        // Re-confirming the combo that's already set here shouldn't have to
        // pass the availability probe below -- WSNH itself is the one
        // holding it already, so a fresh registration attempt would
        // (correctly, but unhelpfully) report it as taken.
        let isUnchanged = newKeyCode == currentKeyCode && modifiers.rawValue == currentModifierFlags

        // Refuse anything that's already a standard macOS/app editing
        // shortcut (Cmd+C, Ctrl+A, etc.) -- WSNH registering one of these as
        // a *global* hotkey would silently steal it everywhere, in every
        // app, for as long as WSNH is running.
        if !isUnchanged, let reserved = ReservedHotKeys.label(forKeyCode: newKeyCode, modifiers: modifiers.rawValue) {
            rejectCapture("That's \(reserved) — pick a different combo")
            return
        }

        // Second check: is anything *else* already holding this exact combo
        // as its own global hotkey? Could be another app (Raycast, Alfred,
        // BetterTouchTool, a corporate IT tool, etc.), or one of WSNH's own
        // other Prompt Actions/Snippets -- there's no static list for
        // either case, so the only way to know is to briefly try
        // registering it ourselves.
        if !isUnchanged, !HotKeyAvailability.isAvailable(keyCode: newKeyCode, modifiers: modifiers.rawValue) {
            rejectCapture("That combo's already in use elsewhere — pick a different one")
            return
        }

        currentKeyCode = newKeyCode
        currentModifierFlags = modifiers.rawValue
        onCapture?(newKeyCode, modifiers.rawValue)
        refreshLabel()
    }

    /// Shows a rejection reason briefly, then falls back to whatever hotkey
    /// (if any) was already set -- so the message is readable but doesn't
    /// get stuck looking like it's the new, saved value.
    private func rejectCapture(_ message: String) {
        label.stringValue = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.refreshLabel()
        }
    }

    override func layout() {
        super.layout()
        label.frame = bounds
    }
}
