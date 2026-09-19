# Contributing to Islet

Thanks for helping. This page tells you how to build the app and how to send a change.

## Build

1. Install Xcode 16 or later.
2. Install XcodeGen: `brew install xcodegen`.
3. Run `xcodegen generate` in the repository root.
4. Open `Islet.xcodeproj` and press Run.

The generated project is checked in, so step 3 is only needed after you change `project.yml`.

## Layout

| Folder | What lives there |
| --- | --- |
| `Islet/App` | App entry point, app delegate, Shortcuts intents |
| `Islet/Core` | Notch geometry, the panel, the view model, preferences |
| `Islet/Services` | One file per data source: media, battery, volume, brightness, Bluetooth, focus, calendar, shelf, audio tap |
| `Islet/Views` | SwiftUI views and components |
| `Vendor/MediaRemoteAdapter` | The prebuilt adapter and its license |
| `scripts` | Build helpers |

## Settings

Settings are generated. Edit the table in `scripts/gen-preferences.py`, run it, and commit both files.

## Rules

- Keep zero Swift package dependencies. The app must build offline.
- Every private API call must fail quietly when the symbol is missing.
- Write prose in short, active sentences. Do not use contractions in docs.
- Run the app on a Mac with a notch and one without before you open a pull request.

## Pull requests

1. Fork and create a branch named after the change.
2. Keep one change per pull request.
3. Describe what you tested and on which macOS version.
