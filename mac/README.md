# WSNH — Words Smarter, Not Harder

WSNH is a small menu bar app for Mac. Select text in any app, press a
keyboard shortcut, and WSNH rewrites it using an AI model (via Salesforce's
internal LLM Gateway Express, or your own OpenAI account) according to
instructions you control. The result can replace your selection
automatically, or show up in a little window so you can review it first.

Think of it as a set of custom "rewrite this" buttons that work everywhere on
your Mac — Slack, email, Google Docs, Notes, Salesforce, wherever you can
select text.

This guide has two parts:

- **Part 1: Install and use WSNH** — for anyone who just wants to run it.
- **Part 2: Customize your prompts** — for once you're comfortable and want
  to add your own rewrite shortcuts.

No coding or technical background needed for either part.

---

## Before you start

You'll need:

1. **A Mac.** WSNH requires macOS 13 (Ventura) or newer. To check your
   version: click the Apple menu (top-left corner) → **About This Mac**.
2. **An API key** — see below.

### Getting an API key

**Option A — Salesforce employees: use LLM Gateway Express (recommended).**
Salesforce runs an internal proxy called LLM Gateway Express that gives you
an `sk-...` key working just like an OpenAI key, but routed through
Salesforce's own infrastructure (backed by AWS Bedrock) instead of OpenAI
directly.

1. Go to https://eng-ai-model-gateway.sfproxy.devx-preprod.aws-esvc1-useast2.aws.sfdc.cl
   and log in with SSO. (If you don't have access yet, you may need to join
   the gateway's access channel first — ask in `#llm-gateway-express-support`
   if you're not sure where that is.)
2. Click **Generate Key** to get your `sk-...` key.
3. That's it for setup — WSNH is already configured to point at this
   gateway by default, so you'll just paste the key into Preferences (Step 4
   below) and go.

A few things worth knowing about the gateway: your data stays inside
Salesforce's network rather than going to OpenAI directly; it supports GPT,
Claude, and Gemini models through the same key; generating a new key
invalidates the old one; and it's meant for internal developer tooling, not
customer-facing use. Questions go to `#llm-gateway-express-support`.

**Option B — your own OpenAI account.** Not at Salesforce, or don't have
gateway access? Get a key at https://platform.openai.com/api-keys instead
(this is separate from a ChatGPT Plus subscription — it's pay-as-you-go API
billing). You'll also need to change the API Base URL in Preferences to
`https://api.openai.com/v1` (Step 4 covers this).

A note on cost either way: every time you use WSNH, it makes a small API
call. With your own OpenAI key, that's billed to your OpenAI account —
typical rewrites cost a fraction of a cent each with the default model.

---

## Part 1: Install and use WSNH

### Step 1 — Unzip and move to Applications

1. You should have received a file called **WSNH.zip**. Double-click it to
   unzip — this creates **WSNH.app**.
2. Drag **WSNH.app** into your **Applications** folder. (This step is
   optional but recommended — it makes WSNH easier to find later and lets it
   launch automatically at login if you want that.)

### Step 2 — Open it for the first time

Because WSNH isn't distributed through the Mac App Store, macOS will warn you
about it the first time you open it. This is expected — click through it
once and you won't see it again.

1. In **Applications**, **right-click** (or hold Control and click) on
   **WSNH.app**, then choose **Open** from the menu.
2. A dialog will appear saying macOS cannot verify the app. Click **Open**.

If that dialog doesn't show an "Open" button, or nothing happens when you
right-click and choose Open:

1. Try double-clicking WSNH.app once anyway — you'll see a message that it's
   blocked.
2. Open **System Settings** → **Privacy & Security**.
3. Scroll to the bottom. You'll see a note that WSNH was blocked, with an
   **Open Anyway** button. Click it.
4. Confirm with your Mac password or Touch ID.

After this first launch, WSNH opens normally like any other app — no more
warnings.

You won't see a new window or dock icon. WSNH lives in your **menu bar**, at
the top-right of your screen — look for a small wand icon (✨).

The first time it opens, a **Welcome Guide** window walks through what WSNH
does and what's already set up — worth a quick read. You can reopen it any
time from the wand icon ✨ → **Welcome Guide…**.

### Step 3 — Grant Accessibility permission

WSNH needs one special permission to work: **Accessibility**. This is what
lets it "see" that you've selected text and paste results back in for you.
Without it, WSNH can't do anything.

macOS should prompt you for this automatically the first time you press a
WSNH shortcut. If it doesn't, or if you accidentally click "Don't Allow":

1. Click the wand icon (✨) in the menu bar → **Preferences…**
2. Under **Accessibility Permission**, click **Open System Settings**.
3. Find **WSNH** in the list and turn the toggle **on**.
4. You may need to quit and reopen WSNH once after granting this.

If you plan to use typed-shortcut Snippets (see Part 3), there's one more
permission for that specific feature — **Input Monitoring**. Everything else
in WSNH only needs Accessibility.

1. Click the wand icon (✨) in the menu bar → **Preferences…**
2. Under **Input Monitoring Permission**, click **Open System Settings**.
3. Find **WSNH** in the list and turn the toggle **on**.

This is what lets WSNH watch for a typed shortcut (like `;sig1`) anywhere on
your Mac. It's a separate, more sensitive permission than Accessibility
because it involves watching keystrokes rather than just pasting — macOS
never shows WSNH (or anything else with this permission) what you type into
password fields or Terminal's `sudo` prompts, that's blocked at the OS level
regardless.

You can skip this entirely if you only plan to use hotkey-triggered Snippets
and Prompt Actions — those only need Accessibility.

### Step 4 — Add your API key

1. Click the wand icon (✨) → **Preferences…**
2. Under **AI Connection**, paste your key (it starts with `sk-`) into
   **API Key**.
3. Check the **API Base URL** field. It's already set to Salesforce's LLM
   Gateway Express by default — leave it as-is if you got your key from
   there (Option A above). If you're using your own OpenAI account (Option
   B) instead, change it to `https://api.openai.com/v1`.
4. Click **Save**.

Your key is stored securely in the Mac Keychain — the same secure storage
macOS uses for your other passwords. It is never written to a plain text
file, and WSNH only sends it to whichever API base URL is configured above.

### Step 5 — Try it out

WSNH comes with two shortcuts already set up:

| Shortcut | Name | What it does |
| --- | --- | --- |
| ⌘⌥A | **ALL CAPS** | Rewrites text in all caps (keeps emojis in place) |
| ⌘⌥K | **KEEP MY JOB** | Rewrites text in simple, direct, professional language |

1. Select some text anywhere — an email, a Slack message, a document.
2. Press one of the shortcuts above, e.g. **⌘⌥K**.
3. A small window will pop up a few seconds later with the rewritten text.
   Click **Paste & Replace** to drop it into place, **Copy** to grab it for
   later, or **Close** to discard it.

That's the whole loop: select, press a shortcut, review, paste.

---

## Part 2: Customize your prompts

Preferences (wand icon ✨ → **Preferences…**) is where you manage all of
WSNH's shortcuts, called **Prompt Actions**. Each one bundles together:

- **A hotkey** — the keyboard shortcut that triggers it
- **A model** — which OpenAI model does the rewriting
- **A prompt** — your instructions for how to rewrite the text
- **What happens after** — auto-paste, show a popup, or ask you each time

You can have as many Prompt Actions as you want, each with its own shortcut
— for example, one for "make this more concise," one for "fix grammar only,
don't change my voice," one for "translate to Spanish."

### Adding a new Prompt Action

1. In Preferences, click **Add Prompt Action**.
2. **Name** it something you'll recognize later — this is just a label for
   you.
3. Click the hotkey box and press the key combo you want (it must include at
   least one of ⌘ ⌥ ⌃ ⇧, so it doesn't clash with normal typing).
4. Pick a **Model**. `gpt-4o-mini` is fast and cheap and is a good default;
   `gpt-4o` is slower and pricier but higher quality for nuanced writing.
5. Write your **Prompt**. This is the instruction WSNH sends to OpenAI along
   with your selected text. Put `{selectedText}` somewhere in it — WSNH
   replaces that placeholder with whatever you had selected. For example:

   ```
   Rewrite the following text to sound more confident and concise,
   without changing its meaning:

   {selectedText}
   ```

6. Choose what happens **After running**:
   - **Show a popup to review** (recommended while you're getting a feel for
     a new prompt) — lets you see the result and decide before anything
     changes.
   - **Auto-paste in place** — replaces your selection immediately, no
     review step. Good for prompts you trust.
   - **Ask each time** — shows a quick yes/no dialog before pasting.
7. Click **Save**.

### Editing or removing a Prompt Action

In Preferences, each saved action has **Edit** and a trash icon next to it.
Editing lets you change any part of it, including the hotkey.

### A tip on writing good prompts

The more specific you are, the more consistent the results. Tell it what
tone to use, what to avoid, and how to format the output. If you're not sure
where to start, try asking ChatGPT itself to help you draft a prompt for what
you want WSNH to do — then paste that into the Prompt field.

### Backing up and restoring your settings

Preferences → **Backup & Restore** lets you save everything — your API key,
API base URL, and every prompt action — to a single file, and load it back
later.

- **Export Backup…** saves a `.json` file wherever you choose.
- **Import Backup…** loads one back in, replacing whatever's currently
  configured (it'll ask you to confirm first).

This is useful for moving to a new Mac, reinstalling after wiping your
settings, or just having a safety copy of prompts you've spent time tuning.

Two things worth knowing:

- **The backup file contains your API key in plain text.** Treat it like a
  password — store it somewhere secure, and don't post it in Slack or email
  it around. If you want to share your prompt set with a colleague without
  handing them your key, open the exported `.json` file in a text editor,
  clear out the `"apiKey"` value, and send them that instead.
- **Backups don't move hotkeys between Mac and Windows.** The prompts,
  model choices, and output modes carry over fine either way, but the
  underlying key codes for hotkeys are numbered differently on each
  platform, so if you import a backup made on the Windows version, you may
  need to re-set a few hotkeys afterward. WSNH will tell you if this
  happened.

---

## Part 3: Snippets

Snippets are different from Prompt Actions: there's no AI involved at all.
A Snippet is a fixed block of formatted text (bold, underline, links, etc.)
that gets inserted exactly as you wrote it — instantly, with no API call.
Think signatures, boilerplate replies, disclaimers, addresses — anything you
paste over and over without needing it rewritten.

Each Snippet can be triggered two ways, and you can set up either or both:

- **A hotkey** — press it, and the snippet is pasted at your cursor (or
  replaces whatever's selected, same as a normal paste).
- **A typed shortcut** — type a short string like `;sig1` anywhere, then
  press Space, Tab, or Return, and WSNH swaps it for the full snippet.

### Creating a Snippet

1. Preferences (wand icon ✨ → **Preferences…**) → **Snippets** → **Add
   Snippet**.
2. **Name** it something you'll recognize later.
3. Set a **hotkey**, a **typed shortcut**, or both — at least one is
   required.
4. Write the content in the box below, using the **B** / *I* / U / 🔗
   buttons above it to format selected text — bold, italic, underline, and
   links all carry through when pasted into apps that support rich text
   (Mail, Word, Google Docs, Slack, etc.). Apps that only accept plain text
   get the plain wording instead, automatically.
5. Click **Save**.

### A note on typed shortcuts

Typed-shortcut Snippets need the **Input Monitoring** permission covered in
Step 3 above — without it, WSNH can't watch for what you're typing, and
typed shortcuts simply won't expand (hotkey-triggered Snippets work fine
either way). Preferences will show you whether it's granted.

A couple of practical tips: pick shortcuts that wouldn't otherwise appear in
normal typing (`;sig1` rather than `sig1`, so it can't accidentally match
inside a real word), and remember the shortcut only expands once you press
Space, Tab, or Return right after typing it — that's what confirms you
meant it as a shortcut and not a coincidence.

---

## Frequently asked questions

**My hotkey doesn't do anything.**
Check that another app isn't already using the same key combo (this is a
common conflict with menu bar utilities and window managers). Also confirm
Accessibility permission is still granted — Preferences will show you its
status.

**I selected text, but the popup is empty or shows the wrong thing.**
Make sure text was actually selected (highlighted) in the other app right
before you pressed the hotkey — clicking somewhere else first will clear
your selection.

**My typed shortcut doesn't expand.**
Almost always a missing **Input Monitoring** permission — check Preferences,
it'll show you whether it's granted. If it is granted and it's still not
expanding, double check you're pressing Space/Tab/Return right after typing
the shortcut (that's what confirms the expansion), and that nothing else on
your Mac uses the same shortcut text.

**I got an error mentioning "API key," "401," or the URL doesn't look right.**
Your key is missing, incorrect, or has run out of credit — or the **API
Base URL** in Preferences doesn't match where your key is from. Gateway keys
only work with the gateway URL, and OpenAI keys only work with
`https://api.openai.com/v1`. If you're on the gateway, double check access
in `#llm-gateway-express-support`; if you're on your own OpenAI account,
confirm the key is active at platform.openai.com.

**I got an error mentioning a model name.**
The model you picked for that Prompt Action might not be available through
whichever API you're using, or the name was typed slightly wrong. Try
`gpt-4o-mini` in Preferences → edit the action → Model.

**Can two people share the same WSNH install / API key?**
Each person should generate and use their own key (gateway or OpenAI), added
on their own Mac. Usage and cost are tied to whoever's key is entered in
Preferences.

**How do I stop WSNH from launching at login?**
Preferences → **Startup** → turn off **Launch WSNH at login**.

**How do I uninstall it?**
Quit WSNH (wand icon ✨ → Quit), then drag **WSNH.app** from Applications to
the Trash. If you'd also like to remove your saved prompts and API key:
delete the folder `~/Library/Application Support/WSNH` and remove the
"WSNH" entry from Keychain Access (search "wsnh" in the Keychain Access app).

---

## A note on privacy

When you trigger a Prompt Action, WSNH copies your current selection and
sends it — along with the prompt you wrote — directly to whichever API base
URL is configured in Preferences, using your key. If that's Salesforce's LLM
Gateway Express, your data stays inside Salesforce's network; if it's your
own OpenAI account, it goes straight to OpenAI and is governed by their data
usage policies. Either way, WSNH briefly uses your Mac clipboard to do this
(to capture the selection and to paste the result back), and restores
whatever was on your clipboard beforehand immediately after. WSNH itself
doesn't log, store, or transmit your text anywhere else.

---

Questions or issues? Reach out to Amelia Kleymann (akleymann@salesforce.com).
