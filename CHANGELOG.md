# Changelog

## 0.2.0

- Settings now open in a real window with pages for every feature, permission status, and a reset button.
- The island is one opaque shape again, with a boundary-free progressive blur halo around it.
- HUD peeks stay visible for two seconds, restart on every change, and are never cut short by another peek.
- The system volume and brightness bezels are hidden by default while Islet runs. Turn this off under Sound.
- Brightness and keyboard backlight HUDs only react to key presses, so automatic dimming no longer shows a peek.
- Full screen detection uses the menu bar state, so large windows no longer hide the island.
- Shuffle and repeat use the MediaRemote toggle commands and react immediately.
- The shelf has a Home button, the island returns to Home on close, and a two-finger swipe switches tabs.
- Streams without a timeline, such as Netflix, no longer show a broken scrubber.
- Content fades out quickly on close so nothing lingers while the shape collapses.

## 0.1.0

First public release.

- Now Playing from any app through MediaRemote, with artwork, scrubber, shuffle, repeat, copy, and an output device switcher.
- Site icons for browser media (YouTube, Netflix, and any other site).
- Optional live waveform driven by a CoreAudio process tap.
- Peeks for battery, Low Power Mode, Bluetooth accessories with battery levels, Focus changes, calendar events, finished downloads, and Caps Lock.
- Volume, brightness, and keyboard backlight HUDs, with an optional replacement of the system bezels.
- File shelf with drag in, drag out, AirDrop, and Quick Look.
- Trackpad gestures, haptics, a global shortcut, and Shortcuts actions.
- Alcove-style settings window with per-feature pages.
