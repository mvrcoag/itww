# *itww*.

Native macOS menu bar app that pipes any selected text straight through on-device Siri & Apple Intelligence (`FoundationModels`) to fix grammar, sharpen prose, or apply custom instructions in place.

**[Live Webpage →](https://mvrcoag.github.io/itww/)** · **[Download Latest `.dmg` →](https://github.com/mvrcoag/itww/releases/latest/download/itww.dmg)**

## Features

- **Global hotkey anywhere (`⌃⌥I` by default).** Works across native AppKit apps as well as Electron editors and browsers (Slack, Linear, Notion, Arc) while preserving your clipboard.
- **Movable floating HUD.** Appears near your cursor, streams tokens live, computes inline word-level diffs (`⌘D`), and drags anywhere on screen.
- **5 modes + custom instructions.** Switch between **Improve**, **Fix Grammar**, **Concise**, **Clear**, and **Professional** (`⌘1`–`⌘5`), type one-off instructions right inside the HUD (e.g. `"bullet list"`, `"translate to Spanish"`), or configure permanent style rules in Settings.
- **100% private via `FoundationModels`.** Runs locally on Apple Silicon with `SystemLanguageModel` or `PrivateCloudComputeLanguageModel` — zero API keys or cloud bills.
- **Up-front onboarding.** Greets you on first launch to verify Accessibility permissions, Apple Intelligence readiness, and your preferred shortcut.

## Build & Package

Build a signed `build/itww.app` bundle:

```bash
./scripts/build-app.sh
open build/itww.app
```

Create a distributable `.dmg` installer (with drag-to-Applications symlink) and release `.zip`:

```bash
./scripts/package-dmg.sh
```

Run tests:

```bash
swift test
```

## Website

The product landing page lives in `website/` (Astro):

```bash
cd website
npm install
npm run dev
```

## License

MIT © [Marco A. García (mvrcoag)](https://www.mvrcoag.com)
