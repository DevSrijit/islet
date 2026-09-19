# Changelog

## 0.3.0

- System HUDs are hidden on macOS 26 and later too. Those slider popovers come from `MenuBarAgent`, not `OSDUIHelper`, and Islet now freezes both while it runs.
- The progressive blur is a strip below the island that fades downward, like Alcove's, instead of a halo.
- Shelf and Settings icons live in the black band beside the notch while the island is open.
- Tab changes and open/close transitions move vertically only.
- Media that blinks to "nothing playing" for a moment no longer flickers the compact activity; the last state is held for the idle duration.
- A watchdog closes the island when the pointer has clearly left it, even if a mouse event was missed.
- Full screen detection has hysteresis, and "Hide in full screen apps" is off by default so the island stays up over full screen video.
- The menu bar item uses a notch glyph and shows that Islet is running.
- HUD peeks stay quiet during the first seconds after launch.

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
