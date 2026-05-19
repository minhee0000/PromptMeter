# PromptMeter

**English** · [한국어](README.ko.md) · [日本語](README.ja.md) · [中文](README.zh.md)

[![macOS](https://img.shields.io/badge/macOS-26%2B-0a0a0c?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![Version](https://img.shields.io/badge/version-0.1.0-16d3b4?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

PromptMeter is a macOS menu bar app for people who work with AI coding assistants every day. It keeps your active quota, reset windows, and local token usage visible without opening multiple dashboards or digging through CLI output.

It currently focuses on Codex, Claude Code, and Gemini CLI.

## Screenshot

<!-- TODO: replace with docs/screenshot.png once the popover capture is ready. -->

_Screenshot of the menu bar popover — coming soon._

## Why

AI coding tools are powerful, but their limits are easy to lose track of:

- How much of my current Codex session is left?
- When does my Claude Code window reset?
- Is Gemini CLI installed and signed in?
- How many tokens did I use today?
- Which provider is closest to running out?

PromptMeter puts those answers in the menu bar and a compact popover, so you can keep working without context switching.

## Features

- **Menu bar status** for the lowest remaining provider sessions.
- **Provider cards** for Codex, Claude Code, and Gemini CLI.
- **Today usage** from local Codex and Claude Code JSONL logs.
- **Estimated token cost** using model-aware local rate estimates.
- **Quota reset display** as clock time or countdown.
- **Low quota notifications** when a provider window approaches the threshold.
- **Missing CLI detection** with install/login commands shown in settings.
- **Privacy toggle** to hide account emails in the UI.
- **Launch at login** for a quiet menu bar workflow.
- **Incremental log scanning** so repeated refreshes read only newly appended log data.

## Provider Support

| Provider | Status | What PromptMeter Reads |
| --- | --- | --- |
| Codex | Supported | Local CLI/app-server quota, plan, account, session limits, local token usage logs |
| Claude Code | Supported | OAuth usage, subscription, reset windows, local token usage logs |
| Gemini CLI | Supported | Local CLI `/stats model` quota output |

PromptMeter is not affiliated with OpenAI, Anthropic, or Google. It reads data available through your locally installed tools and local session logs.

## Privacy

PromptMeter is designed to be local-first:

- Prompt text is processed locally for token estimation.
- Local token usage is calculated from files on your machine.
- Usage scan caches store only aggregate counts, file signatures, offsets, and parser state.
- Account emails can be hidden from the settings UI.

Claude Code OAuth credentials are read through macOS Keychain and cached through PromptMeter's own Keychain item when token refresh is needed.

## macOS Permissions

PromptMeter stays quiet on macOS — no Screen Recording, no Accessibility, no Full Disk Access.

- **Keychain (prompted by macOS)** — On first refresh, PromptMeter reads the Claude OAuth credential stored by the Claude Code CLI (`Claude Code-credentials` item) and caches a refreshable copy under its own Keychain item (`com.seo.promptMeter.oauth-cache`) so background refreshes do not prompt again. To remove the initial prompt entirely:
  1. Open **Keychain Access.app** → login keychain.
  2. Find the prompted item (usually `Claude Code-credentials`) and open it.
  3. Under **Access Control**, add `PromptMeter.app` to "Always allow access by these applications".
  4. Relaunch PromptMeter.
- **Notifications (optional)** — Requested only when low-quota alerts are enabled. Declining keeps everything else working.
- **Login items (opt-in)** — Settings → General → "Start at login" uses `SMAppService`; macOS asks once before adding PromptMeter to login items.

No passwords are stored. Provider CLIs continue to manage their own authentication.

## Project Structure

```text
PromptMeter/
  App/        App entry, app delegate, popover host
  Core/       Main app model, settings, prompt metrics, notifications
  Menu/       Menu bar popover views and menu data models
  Providers/  Codex, Claude Code, Gemini CLI clients and usage mapping
  Settings/   Settings window, tabs, reusable settings components
  Usage/      Local token usage scanner, pricing, file cache, snapshots
```

The Xcode project uses a file-system synchronized root group, so the on-disk tree is the source layout.

## Build

Requirements:

- macOS
- Xcode
- SwiftUI/AppKit toolchain
- Optional provider CLIs:
  - `codex`
  - `claude`
  - `gemini`

Clone and open:

```bash
git clone git@github.com:minhee0000/PromptMeter.git
cd PromptMeter
open PromptMeter.xcodeproj
```

Then build and run the `PromptMeter` scheme from Xcode.

The current project is configured as a macOS menu bar app (`LSUIElement`) and targets the macOS SDK used by the checked-in Xcode project.

## Usage

1. Install and sign in to the provider CLIs you use.
2. Launch PromptMeter.
3. Open the menu bar popover to see quota, reset windows, and today usage.
4. Open Settings to configure refresh cadence, display mode, privacy, and launch at login.

If a CLI is missing, PromptMeter keeps it visible in Settings but does not show its widget in the main popover.

## Notes

- Usage and cost numbers are estimates based on local logs and model-aware rate tables.
- Provider APIs and CLI output can change, so PromptMeter treats unavailable or rate-limited provider responses defensively.
- For Claude HTTP 429 responses, PromptMeter keeps the previous successful snapshot and backs off before trying again.

## Roadmap

- Weekly usage summary.
- Optional chart view for daily usage trends.
- More provider integrations.
- Signed release builds.
- Import/export diagnostics for support.

## License

MIT © minhee0000. See [LICENSE](LICENSE) for details.
