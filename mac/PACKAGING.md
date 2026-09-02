# Packaging WSNH for colleagues

This is for you (whoever's building and distributing WSNH), not for the
people you're sending it to — they only need `WSNH.zip` and `README.md`.

## One-time setup (if you haven't already)

```
xcode-select --install
```

## Build and package

From the `WSNH` folder:

```
chmod +x package.sh
./package.sh
```

This runs `build.sh` (compiles the app, assembles `WSNH.app`, code-signs it
with a local self-signed certificate) and then zips it into `WSNH.zip` using
`ditto`, which is the right tool for zipping `.app` bundles on macOS
(preserves the bundle structure correctly — a plain `zip` can subtly corrupt
app bundles).

The first time you ever run `build.sh` on a given Mac, it creates a
certificate called "WSNH Local Dev" in your login keychain (you'll see a
one-time "Creating local signing certificate..." message). Every build after
that reuses it silently. This certificate is what makes your Accessibility
permission grant survive rebuilds — see "Why a local certificate?" below.

You'll end up with two things to hand off:

- `WSNH.zip` — the app itself
- `README.md` — the setup guide, written for non-technical users

## Distributing it

Send `WSNH.zip` and `README.md` via Slack, a shared drive, or email. A few
things worth knowing:

- **No developer account needed on your end or theirs.** WSNH is signed with
  a free local self-signed certificate, not an Apple Developer ID. That's why
  the README walks recipients through the "unidentified developer" Gatekeeper
  warning — this is expected and only happens once per person, per Mac.
- **Nothing person-specific is baked into the zip.** Your OpenAI API key
  lives in your own Mac's Keychain, not in the app bundle — it's safe to
  share this zip with anyone. Each person adds their own key in Preferences.
- **How the file gets there matters a little.** Files downloaded via Slack,
  Mail, or a browser get a "quarantine" flag from macOS, which is exactly
  what triggers the Gatekeeper warning in the README — this is normal and
  the README covers how to get past it. Some transfer methods (like a
  locally shared drive) may skip the warning entirely, which is fine too.
- **Test with one person first** if you can, before sending it to a whole
  team — that way any environment quirks (a stricter macOS version, an MDM
  policy that blocks unsigned apps, etc.) surface with one person instead of
  everyone at once.

## Making changes later

If you tweak the code (e.g. change the default seeded prompt in
`Sources/WSNH/Services/PromptStore.swift`, adjust the menu bar icon, add a
feature), just re-run `./package.sh` and redistribute the new `WSNH.zip`.
Consider bumping `CFBundleVersion` / `CFBundleShortVersionString` in
`Info.plist` first so you can tell versions apart later if needed — this is
optional and mostly useful for your own bookkeeping, since there's no
auto-update mechanism; everyone stays on whatever zip they installed until
you send a new one.

## Why a local certificate?

Earlier builds signed the app "ad-hoc" (`codesign --sign -`), which derives
the app's identity from the binary's own contents. Every rebuild produces
different contents, so macOS treated each rebuild as a brand new app and
threw away any Accessibility permission you'd already granted — meaning
you'd have to re-grant it after every single change, even on your own Mac.

Signing with a real (if self-signed) certificate instead gives the app a
stable identity tied to the certificate, not the binary. As long as
`build.sh` keeps signing with the same "WSNH Local Dev" certificate, macOS
recognizes rebuilt versions as the same app and keeps your Accessibility
grant across rebuilds. This doesn't change anything for the people you send
`WSNH.zip` to — they still see the one-time Gatekeeper warning exactly as
before, since the certificate is only sitting in your keychain for codesign
to use, not marked as system-trusted (codesign doesn't need that to sign).

If you ever build on a different Mac, that Mac creates its own copy of
"WSNH Local Dev" the first time — nothing to configure by hand.

## Known limitation: MDM / stricter security environments

If your organization uses Mobile Device Management (MDM) with a strict
Gatekeeper policy, some Macs may block unsigned apps outright even via
"Open Anyway," depending on how that policy is configured. If a colleague
reports that WSNH won't open no matter what, that's the most likely cause —
worth checking with IT rather than assuming something's wrong with the app
itself.
