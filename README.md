# FanyiBar

FanyiBar is a lightweight macOS menu bar translator for three daily workflows:

- Screenshot OCR translation for English games.
- Selected-text translation in other apps.
- Chat draft translation from Chinese to English.

The first version is intentionally small. It uses native macOS APIs, Apple Vision for local OCR, and an OpenAI-compatible `/chat/completions` API as the translation engine.

## Run

```sh
swift run FanyiBar
```

The app appears as a menu bar item named `译`.

For daily use, build a `.app` bundle:

```sh
chmod +x Scripts/build_app_bundle.sh
Scripts/build_app_bundle.sh
open dist/FanyiBar.app
```

For a release bundle, run `CONFIGURATION=release Scripts/build_app_bundle.sh`.

Using the `.app` bundle is preferable for macOS privacy permissions because Screen Recording and Accessibility approvals are tied to the app identity.

After granting Screen Recording or Accessibility permissions, fully quit and reopen FanyiBar. If you rebuild `dist/FanyiBar.app`, macOS may treat it as a changed app; remove the old FanyiBar entry from System Settings and grant the permission again.

## Configure

Open the menu bar item and choose `Settings`.

Configure:

- API Base URL, for example `https://api.openai.com/v1` or another OpenAI-compatible endpoint.
- Model, for example `gpt-4o-mini`, `deepseek-chat`, or a compatible model name.
- API Key, stored in Keychain.
- Default target language.
- Hotkeys as Carbon key code + modifier mask pairs.
- Prompt templates for screenshot OCR, selected text, and chat drafts.

Use `Test API` in Settings after filling the API fields. It sends a small translation request and reports either the translated result or the API/configuration error.

Default hotkeys:

- Screenshot OCR: `Control + Option + 2`
- Selected text: `Control + Option + 3`
- Chat draft window: `Control + Option + 4`

## Permissions

macOS permissions are required for the full workflow:

- Screen Recording: required for screenshot OCR.
- Accessibility: required for selected-text translation and copy fallback.

Both can be requested from the Settings screen.

## Prompt Templates

Prompt templates are stored in app settings and can be edited per scene:

- Screenshot OCR: best for games, UI labels, dialogue, item descriptions, and fragmented OCR text.
- Selected text: best for general text selected in other apps.
- Chat draft: best for turning Chinese drafts into natural English messages.

Supported placeholders:

- `{targetLanguage}`
- `{sourceText}`
- `{context}`
- `{scene}`

If a custom template is left blank, FanyiBar falls back to the built-in default for that scene.

## Verify

Run the focused check executable:

```sh
swift run FanyiCoreChecks
```

Build the app:

```sh
swift build --product FanyiBar
```

Mock API acceptance flow:

```sh
python3 Scripts/mock_openai_server.py --port 8787
```

Then open `dist/FanyiBar.app` and configure:

- API Base URL: `http://127.0.0.1:8787/v1`
- Model: `mock-model`
- API Key: any non-empty value, for example `test`

Run `Test API`. A successful mock response starts with `[MOCK TRANSLATION]`.

Manual acceptance checklist:

1. Build and open `dist/FanyiBar.app`.
2. Open Settings, configure API Base URL, Model, API Key, and run `Test API`.
3. Grant Screen Recording and Accessibility permissions when prompted.
4. Press `Control + Option + 2`, select an English text region, and confirm OCR translation appears.
5. Select text in another app, press `Control + Option + 3`, and confirm translation appears.
6. Press `Control + Option + 4`, enter a Chinese chat draft, translate to English, and copy the result.
7. Confirm permission-missing, invalid API key, and OCR-empty cases show clear messages.

Use the mock API flow first to validate app behavior without spending model credits. Repeat the same checklist with a real OpenAI-compatible API before considering the app fully accepted.

## Current Boundaries

- Only OpenAI-compatible chat completion APIs are supported.
- OCR is local through Apple Vision; cloud OCR is not implemented.
- Translation history is not stored.
- Hotkey editing is functional but still low-level; a polished hotkey recorder should be added later.
