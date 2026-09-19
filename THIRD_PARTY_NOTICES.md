# Third-party notices

## MediaRemoteAdapter

Islet bundles `MediaRemoteAdapter.framework` and `mediaremote-adapter.pl` from
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
Copyright (c) Jonas van den Berg. Licensed under the BSD 3-Clause License.
The full license text is in `Vendor/MediaRemoteAdapter/LICENSE`.

The adapter is not linked into Islet. Islet runs it inside the system Perl
interpreter, which is the only way an unsigned third-party app can read the
"Now Playing" state on macOS 15.4 and later.

## Sounds

Islet plays sounds that ship with macOS (`/System/Library/Sounds` and the
PowerChime charging sound). It does not redistribute them.

## Site icons

When browser media plays, Islet downloads the site's favicon at runtime and
caches it locally. Islet does not ship any third-party logos.
