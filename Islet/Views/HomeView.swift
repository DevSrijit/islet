import SwiftUI

/// Expanded notch, Home tab: Now Playing, or a glanceable day view when nothing plays.
struct HomeView: View {
    var model: NotchViewModel
    var namespace: Namespace.ID

    private var prefs: Preferences { model.prefs }
    private var tint: Color { prefs.waveformStyle == "monochrome" ? .white : model.tint }
    /// Artwork radius stays concentric with the island: outer radius minus the content margin.
    private var artworkRadius: CGFloat { NotchRootView.openBottomRadius - NotchRootView.contentMargin }

    var body: some View {
        if let playing = model.nowPlaying {
            nowPlaying(playing)
        } else {
            idle
        }
    }

    // MARK: Now playing

    private func nowPlaying(_ playing: NowPlaying) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                FlipArtwork(data: playing.artworkData, fallback: model.sourceIcon, cornerRadius: artworkRadius, flipEnabled: prefs.artworkFlip)
                    .frame(width: 46, height: 46)
                    .matchedGeometryEffect(id: "artwork", in: namespace)
                    .onTapGesture { model.openSourceApp() }
                    .help("Open \(sourceName(playing))")
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: playing.title, font: .system(size: 14, weight: .semibold)).id(playing.title)
                    if !playing.artist.isEmpty {
                        Text(playing.artist)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Visualizer(playing: playing.isPlaying, tint: tint, style: prefs.waveformStyle,
                           levels: prefs.liveWaveform && model.audioTap.isRunning ? model.audioTap.bands : nil, barCount: 5, height: 14)
                    .padding(.trailing, 2)
            }
            .frame(height: 46)
            timeline(for: playing)
            controls(for: playing)
        }
    }

    private func sourceName(_ playing: NowPlaying) -> String {
        model.source?.name ?? NSImage.appName(bundleID: playing.appBundleID) ?? "source app"
    }

    /// The scrubber, or one quiet line when the player reports no duration (live video, streams).
    @ViewBuilder
    private func timeline(for playing: NowPlaying) -> some View {
        if let duration = playing.duration, duration.isFinite, duration > 0 {
            TimelineView(.periodic(from: .now, by: playing.isPlaying ? 0.5 : 60)) { context in
                Scrubber(position: playing.position(at: context.date) ?? 0,
                         duration: duration,
                         tint: tint,
                         onScrubbing: { model.isScrubbing = $0 },
                         onSeek: { model.media.seek(to: $0) })
            }
        } else {
            // A stream with no timeline gets one quiet line, unless it would only repeat the title.
            let source = model.source?.name ?? NSImage.appName(bundleID: playing.appBundleID)
            Text(source.map { $0.caseInsensitiveCompare(playing.title) == .orderedSame ? "" : $0 } ?? "Live")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 14)
        }
    }

    private func controls(for playing: NowPlaying) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                if prefs.actionShuffle {
                    HoverButton(symbol: "shuffle", size: 11, diameter: 24, active: playing.shuffleOn, tint: tint, help: "Shuffle") {
                        model.media.setShuffle(on: !playing.shuffleOn)
                    }
                }
                if prefs.actionRepeat {
                    HoverButton(symbol: playing.repeatMode == 2 ? "repeat.1" : "repeat", size: 11, diameter: 24, active: playing.repeatMode > 1, tint: tint, help: "Repeat") {
                        model.media.cycleRepeat(from: playing.repeatMode)
                    }
                }
            }
            .frame(width: 56, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 18) {
                HoverButton(symbol: "backward.fill", size: 17, diameter: 32, dim: true, help: "Previous") { model.media.previous(); Haptics.play(.generic) }
                HoverButton(symbol: playing.isPlaying ? "pause.fill" : "play.fill", size: 24, diameter: 38, help: playing.isPlaying ? "Pause" : "Play") {
                    model.media.togglePlayPause(); Haptics.play(.generic)
                }
                .contentTransition(.symbolEffect(.replace))
                HoverButton(symbol: "forward.fill", size: 17, diameter: 32, dim: true, help: "Next") { model.media.next(); Haptics.play(.generic) }
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                if prefs.actionCopy {
                    HoverButton(symbol: "link", size: 11, diameter: 24, help: "Copy title and artist") {
                        model.copyTrackInfo()
                        model.show(.copied)
                    }
                }
                OutputDeviceButton()
            }
            .frame(width: 56, alignment: .trailing)
        }
    }

    // MARK: Idle

    private var idle: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(context.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if let battery = model.battery {
                            BatteryGlyph(percent: battery.percent, charging: battery.isPluggedIn, low: battery.percent <= prefs.batteryLowThreshold, width: 20)
                            Text("\(battery.percent)%")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                                .contentTransition(.numericText())
                        }
                        if let focus = model.focus {
                            Image(systemName: focus.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(red: 0.55, green: 0.5, blue: 1))
                        }
                    }
                }
                .frame(width: 124, alignment: .leading)
                Rectangle().fill(.white.opacity(0.1)).frame(width: 1).padding(.vertical, 10)
                VStack(alignment: .leading, spacing: 6) {
                    if prefs.calendarEnabled {
                        CalendarSummary(calendar: model.calendar, useColor: prefs.calendarUseColor, now: context.date)
                    } else {
                        Text("Nothing playing").font(.system(size: 13, weight: .semibold))
                        Text("Music appears here.").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }
    }
}

struct CalendarSummary: View {
    var calendar: CalendarService
    var useColor: Bool
    var now: Date

    var body: some View {
        if !calendar.authorized {
            Text(calendar.denied ? "Calendar access is off" : "Show your day here")
                .font(.system(size: 13, weight: .semibold))
            if calendar.denied {
                Text("Turn it on in System Settings › Privacy.").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            } else {
                Button("Allow calendar access") { Task { await calendar.requestAccess() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.35, green: 0.7, blue: 1))
            }
        } else if let event = calendar.currentEvent ?? calendar.nextEvent {
            let isNow = event.start <= now
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5).fill(useColor ? Color(nsColor: event.color) : .white).frame(width: 3, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isNow ? "Now" : "Up next")
                        .font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white.opacity(0.4)).textCase(.uppercase)
                    Text(event.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                    Text("\(event.start, format: .dateTime.hour().minute()) – \(event.end, format: .dateTime.hour().minute())")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit()).foregroundStyle(.white.opacity(0.55))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { calendar.openCalendarApp() }
        } else {
            Text(calendar.events.isEmpty ? "No events today" : "No more events today")
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

/// Headphones button that lists audio outputs and switches the default device.
struct OutputDeviceButton: View {
    @State private var devices: [AudioDeviceInfo.OutputDevice] = []
    @State private var current = AudioDeviceInfo.defaultOutput()
    @State private var hovering = false

    var body: some View {
        Menu {
            ForEach(devices) { device in
                Button {
                    AudioDeviceInfo.setDefaultOutput(device.id)
                    current = AudioDeviceInfo.defaultOutput()
                    Haptics.play(.alignment)
                } label: {
                    if device.name == current?.name {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            Image(systemName: current?.symbol ?? "speaker.wave.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.62))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(hovering ? 0.14 : 0)))
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(current?.name ?? "Audio output")
        .onAppear { devices = AudioDeviceInfo.outputDevices(); current = AudioDeviceInfo.defaultOutput() }
    }
}
