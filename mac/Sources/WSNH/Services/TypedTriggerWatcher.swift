import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Watches every keystroke system-wide (via a listen-only event tap) for a
/// defined typed shortcut. When a shortcut is typed and confirmed with a
/// delimiter key (space/tab/return/comma/period), it deletes what was typed
/// and pastes the linked snippet in its place.
///
/// Listen-only event taps need macOS's "Input Monitoring" permission -- a
/// separate grant from the Accessibility permission WSNH already asks for
/// (Accessibility covers *simulating* keystrokes to paste; Input Monitoring
/// covers *watching* keystrokes to detect a shortcut in the first place).
///
/// macOS never delivers keystrokes typed into secure fields (password boxes,
/// Terminal sudo prompts, etc.) to any event tap, so this can't see those by
/// design -- nothing extra to handle there.
final class TypedTriggerWatcher {
    static let shared = TypedTriggerWatcher()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?

    private let bufferLock = NSLock()
    private var buffer = ""
    private let maxBufferLength = 60

    private let shortcutsLock = NSLock()
    private var shortcuts: [String: Snippet] = [:]

    private let ownPID = Int64(ProcessInfo.processInfo.processIdentifier)

    private static let delimiterKeyCodes: Set<Int> = [
        kVK_Space, kVK_Tab, kVK_Return, kVK_ANSI_Comma, kVK_ANSI_Period
    ]

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Don't let a shortcut typed in one app trigger an expansion
            // after switching to another app mid-keystroke.
            self?.clearBuffer()
        }
    }

    /// Refreshes the set of shortcuts to watch for. Safe to call any time
    /// the snippet list changes (add/edit/delete/import).
    func reloadShortcuts(_ snippets: [Snippet]) {
        var map: [String: Snippet] = [:]
        for snippet in snippets {
            let trimmed = snippet.shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            map[trimmed] = snippet
        }
        shortcutsLock.lock()
        shortcuts = map
        shortcutsLock.unlock()
    }

    /// Starts the watcher if Input Monitoring is already granted. Safe to
    /// call repeatedly (a no-op once already running, and a no-op if
    /// permission isn't granted yet -- call again after the user grants it).
    func startIfPermitted() {
        guard eventTap == nil, tapThread == nil else { return }
        guard PermissionsHelper.isInputMonitoringGranted else { return }

        // The tap runs on its own dedicated thread rather than the main
        // one. Every keystroke on the whole Mac is routed through this
        // callback before macOS delivers it anywhere else -- if the thread
        // servicing it were ever blocked by app UI (a modal dialog, a slow
        // render, anything happening on the main thread), typing
        // everywhere, other apps included, would stall right along with
        // it. Running it separately means a busy or stuck WSNH window can
        // never take the rest of the system's keyboard input down with it.
        let thread = Thread { [weak self] in
            self?.runTapLoop()
        }
        thread.name = "WSNH-TypedTriggerWatcher"
        thread.start()
        tapThread = thread
    }

    private func runTapLoop() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            // .tailAppendEventTap, not .headInsertEventTap: a listen-only
            // tap has no business sitting in front of everything else on
            // the system. Head-insert put us *before* Carbon's global
            // hotkey dispatch and every other app's own key handling, so
            // if this callback ever ran slow, it delayed those too --
            // which lines up exactly with reports of Cmd+C/Cmd+V and
            // Prompt Action hotkeys silently doing nothing while this was
            // running. Tail-append means everyone else sees the keystroke
            // first; we only ever look at it after the fact.
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                if let refcon {
                    let watcher = Unmanaged<TypedTriggerWatcher>.fromOpaque(refcon).takeUnretainedValue()
                    watcher.handle(event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun() // parks this dedicated thread here for as long as the app runs
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func clearBuffer() {
        bufferLock.lock()
        buffer = ""
        bufferLock.unlock()
    }

    private func handle(_ event: CGEvent) {
        // Skip events WSNH generated itself -- the synthetic backspaces,
        // paste, and retyped delimiter it sends while expanding a snippet
        // -- so it never reacts to its own simulated keystrokes.
        if event.getIntegerValueField(.eventSourceUnixProcessID) == ownPID {
            return
        }

        shortcutsLock.lock()
        let currentShortcuts = shortcuts
        shortcutsLock.unlock()
        guard !currentShortcuts.isEmpty else { return }

        // Read everything straight off the CGEvent instead of wrapping it in
        // an NSEvent. NSEvent(cgEvent:) reaches into AppKit's keyboard-layout
        // machinery, which expects to be touched from the main thread --
        // calling it from this dedicated background thread could contend
        // with the main thread and stall, and because this tap callback sits
        // in the system's synchronous event-delivery path, any stall here
        // stalls keystrokes everywhere, in every app. The CGEvent APIs below
        // give the same information without touching AppKit at all.
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            clearBuffer()
            return
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        bufferLock.lock()
        defer { bufferLock.unlock() }

        if keyCode == kVK_Delete {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        if Self.delimiterKeyCodes.contains(keyCode) {
            if let snippet = currentShortcuts[buffer] {
                let deleteCount = buffer.count + 1 // the shortcut plus the delimiter already typed
                buffer = ""
                SnippetInserter.expandTypedTrigger(snippet, deleteCount: deleteCount, thenRetype: CGKeyCode(keyCode))
            } else {
                buffer = ""
            }
            return
        }

        let characters = Self.typedCharacters(from: event)
        guard !characters.isEmpty else { return }
        buffer.append(characters)
        if buffer.count > maxBufferLength {
            buffer.removeFirst(buffer.count - maxBufferLength)
        }
    }

    /// Resolves the actual character(s) a keydown produces (respecting the
    /// current keyboard layout and modifiers) using CGEvent's own API,
    /// rather than NSEvent.characters -- see the note in `handle` above.
    private static func typedCharacters(from event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: length)
    }
}
