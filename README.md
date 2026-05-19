# PromptMeter

PromptMeter is a macOS menu bar app for people who work with AI coding assistants every day. It keeps your active quota, reset windows, and local token usage visible without opening multiple dashboards or digging through CLI output.

It currently focuses on Codex, Claude Code, and Gemini CLI.

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
