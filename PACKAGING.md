# Packaging WSNH for Windows

This is the guide for whoever's building and sharing the app — not for the end user (they just get a zip and `README.md`).

## Option A: build in the cloud with GitHub Actions (no Windows machine needed)

`.github/workflows/build.yml` is already set up to build this project on a free GitHub-hosted Windows runner. You don't need Windows, .NET, or anything installed locally for this path — just a place to push the code.

1. Push this `WSNH-Windows` folder to a GitHub (or GitHub Enterprise) repo.
2. Go to the repo's **Actions** tab. The workflow runs automatically on every push to `main`/`master`; you can also trigger it manually anytime with the **Run workflow** button (top right of the "Build WSNH for Windows" workflow page) — handy for rebuilding without a new commit.
3. Once the run finishes (green check), open it and scroll to **Artifacts** at the bottom. Download **WSNH-Windows** — it's a zip containing `WSNH.exe`.
4. Share that zip alongside `README.md`. Recipients unzip and run `WSNH.exe` directly.

That's the whole loop — no local build step, no SDK install, no Windows PC required on your end.

## Option B: build locally

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) installed on the machine doing the build (Windows, since this is a WinForms app).

### Build

```powershell
cd WSNH-Windows
.\build.ps1
```

This runs `dotnet publish` with:

- `-r win-x64 --self-contained true` — bundles the .NET runtime into the output, so people running WSNH don't need .NET installed themselves.
- `-p:PublishSingleFile=true` — produces one `WSNH.exe` instead of a folder full of DLLs, which is much easier to hand to someone.

Output lands in `bin\Release\net8.0-windows\win-x64\publish\WSNH.exe`.

## Package for distribution

```powershell
.\package.ps1
```

Zips `WSNH.exe` into `WSNH-Windows.zip`. Share that alongside `README.md` — recipients just unzip and run it.

## Why no code signing?

Unlike the Mac build (which needs a stable local certificate identity so macOS's Accessibility permission grant survives rebuilds), Windows doesn't gate WSNH's core functionality — global hotkeys and the low-level keyboard hook for Snippets — behind an equivalent per-app permission system tied to a code signature. So there's no signing step here.

The tradeoff: the first time someone runs `WSNH.exe`, Windows SmartScreen will show an "unrecognized publisher" warning, since it isn't signed with a paid code-signing certificate. That's expected for an internal tool shared this way — the README tells recipients to click "More info" → "Run anyway."

If this ever needs to look more polished for a wider audience, a proper Authenticode code-signing certificate (from a CA, or an internal one distributed via IT/MDM) would remove that warning — but that's a real cost/process, not something to set up casually.

## Updating the app icon

The icon lives at `Resources\AppIcon.ico` and is referenced by `WSNH.csproj`'s `<ApplicationIcon>`. To regenerate it from new artwork, produce a multi-resolution `.ico` (16/24/32/48/64/128/256 px) and replace that file — no other changes needed, `dotnet publish` picks it up automatically.
