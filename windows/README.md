# WSNH — Words Smarter, Not Harder (Windows)

WSNH lives quietly in your system tray. Select some text anywhere on your PC, press a hotkey, and it gets rewritten by AI right in place. It also supports **Snippets** — reusable blocks of text you can drop in instantly, with no AI involved.

## Part 1: Getting started

### Step 1: Install

1. Unzip `WSNH-Windows.zip` wherever you'd like WSNH to live (e.g. `C:\Program Files\WSNH` or just your Desktop).
2. Double-click `WSNH.exe`.
3. Windows will likely show a blue "Windows protected your PC" screen — this is normal for an internal tool that isn't signed with a paid certificate. Click **More info**, then **Run anyway**.
4. Look for the WSNH icon in your system tray (bottom-right, near the clock — click the little `^` arrow if you don't see it right away).

### Step 2: Add your API key

Right-click the tray icon → **Preferences…** → **Connection** tab. Paste in your API key (Salesforce's internal LLM Gateway Express key, or your own OpenAI key) and click **Save Connection Settings**. The AI rewrite hotkeys won't work until this is set — Snippets work immediately, no key needed.

The API base URL defaults to Salesforce's internal LLM Gateway Express, so most people won't need to touch it.

### Step 3: Try it out

Default hotkeys, ready to go:

- **Ctrl+Alt+A** — ALL CAPS: rewrites the selected text in all caps.
- **Ctrl+Alt+K** — KEEP MY JOB: rewrites the selected text to sound more professional and on-brand.

Select some text anywhere, press one of those, and a small popup shows the result.

## Part 2: Prompt Actions

A Prompt Action is a hotkey + a prompt template. Right-click the tray icon → Preferences → **Prompt Actions** tab to add, edit, or delete them. Each one has:

- **A hotkey** — the combo that triggers it.
- **A model** — which AI model to use (e.g. `gpt-4o-mini`).
- **A prompt template** — your instructions to the AI. Use `{selectedText}` wherever the text you selected should be inserted.
- **What happens to the result** — auto-paste (replaces your selection immediately), popup (shows the result in a window to copy from), or ask each time.

## Part 3: Snippets

A Snippet is a saved block of text (with formatting — bold, italic, links) that you can insert two ways:

1. **Hotkey** — press it, and the snippet pastes wherever your cursor is.
2. **Typed shortcut** — type a short string like `;sig`, then press Space/Tab/Enter, and it expands into the full snippet automatically.

Snippets start out empty — add your own from Preferences → **Snippets** tab whenever you're ready.

A tip on typed shortcuts: pick something you'd never type by accident (like `;sig` rather than just `sig`), so it only expands when you mean it to.

## Backup & Restore

Preferences → **Backup** tab lets you export everything (API key, base URL, prompt actions, and snippets) to a file, and restore from one later. Handy before reinstalling Windows, or to hand your setup to a teammate.

One note: if you restore a backup that was made on the Mac version of WSNH, your prompts and snippets will come across fine, but hotkeys won't — Mac and Windows use completely different numbering for keyboard shortcuts under the hood, so you'll need to re-set hotkeys after importing a Mac backup.

## FAQ

**A hotkey doesn't do anything.** Check that you've added text is selected before pressing it, and that your API key is set (Preferences → Connection) if it's a Prompt Action. If it's still silent, try Preferences → Prompt Actions to confirm the hotkey shown matches what you're pressing — WSNH won't let you bind a hotkey that's already used by Windows or another app, so if a combo seems to do nothing, it may have been rejected at setup time.

**My typed shortcut doesn't expand.** Make sure you're pressing Space, Tab, or Enter right after typing it, and that the shortcut text matches exactly (shortcuts are case-sensitive).

**Windows says this app is from an unrecognized publisher.** That's expected — WSNH isn't signed with a paid code-signing certificate, since it's an internal tool. Click "More info" → "Run anyway" the first time you open it.
