import SwiftUI

/// What the notch shows while collapsed: nothing, the music activity, or a transient peek.
struct ClosedContentView: View {
    var model: NotchViewModel
    var namespace: Namespace.ID

    private var prefs: Preferences { model.prefs }

    /// Longest any single piece of text may get before it truncates or scrolls.
    static let maxTextWidth: CGFloat = 170

    var body: some View {
        let height = model.notchSize.height
        let side = model.closedSide
        HStack(spacing: 0) {
            leading
                .fixedSize()
                .frame(height: height)
                .measureWidth { model.reportClosedWidths(leading: $0, trailing: nil) }
                .frame(width: side, height: height, alignment: .leading)
            Color.clear.frame(width: model.notchSize.width, height: height)
            trailing
                .fixedSize()
                .frame(height: height)
                .measureWidth { model.reportClosedWidths(leading: nil, trailing: $0) }
                .frame(width: side, height: height, alignment: .trailing)
        }
        .frame(height: height)
    }

    // MARK: Leading

    @ViewBuilder
    private var leading: some View {
        if let transient = model.transient {
            leadingSymbol(for: transient)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .id(transient.family)
        } else if model.showsMusicActivity {
            FlipArtwork(data: model.nowPlaying?.artworkData, fallback: model.sourceIcon, cornerRadius: 5, flipEnabled: prefs.artworkFlip)
                .frame(width: model.notchSize.height - 12, height: model.notchSize.height - 12)
                .matchedGeometryEffect(id: "artwork", in: namespace)
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func leadingSymbol(for activity: TransientActivity) -> some View {
        let (symbol, color): (String, Color) = {
            switch activity {
            case .charging: return ("bolt.fill", Color(red: 0.2, green: 0.85, blue: 0.4))
            case .unplugged: return ("bolt.slash.fill", .white)
            case .lowBattery: return ("battery.25percent", Color(red: 1, green: 0.32, blue: 0.3))
            case .lowPowerMode(let on): return ("battery.100percent.bolt", on ? .yellow : .white)
            case .volume(let level, let muted, let device):
                if let device { return (device, .white) }
                if muted || level == 0 { return ("speaker.slash.fill", .white) }
                if level < 0.34 { return ("speaker.wave.1.fill", .white) }
                if level < 0.67 { return ("speaker.wave.2.fill", .white) }
                return ("speaker.wave.3.fill", .white)
            case .brightness(let level): return (level < 0.5 ? "sun.min.fill" : "sun.max.fill", .white)
            case .keyboardBacklight: return ("keyboard", .white)
            case .bluetooth(let event), .bluetoothLow(let event): return (event.symbol, .white)
            case .focus(_, let symbol, let on): return (symbol, on ? Color(red: 0.55, green: 0.5, blue: 1) : .white)
            case .event(_, _, let color): return ("calendar", Color(nsColor: color))
            case .download: return ("arrow.down.circle.fill", Color(red: 0.35, green: 0.7, blue: 1))
            case .capsLock(let on): return (on ? "capslock.fill" : "capslock", .white)
            case .track: return ("music.note", .white)
            case .copied: return ("doc.on.doc.fill", .white)
            case .dropHint: return ("tray.and.arrow.down.fill", .white)
            }
        }()
        HStack(spacing: 7) {
            if case .track = activity, model.nowPlaying?.artworkData != nil {
                FlipArtwork(data: model.nowPlaying?.artworkData, cornerRadius: 5, flipEnabled: false)
                    .frame(width: model.notchSize.height - 12, height: model.notchSize.height - 12)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: activity)
                    .frame(width: 22, height: 22)
            }
            if let label = hudLabel(for: activity) {
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
    }

    /// HUD peeks carry their label on the leading side so both sides stay balanced.
    private func hudLabel(for activity: TransientActivity) -> String? {
        switch activity {
        case .volume: return prefs.soundHUDHideLabel ? nil : "Volume"
        case .brightness: return prefs.displayHUDHideLabel ? nil : "Brightness"
        case .keyboardBacklight: return prefs.displayHUDHideLabel ? nil : "Keyboard"
        default: return nil
        }
    }

    // MARK: Trailing

    @ViewBuilder
    private var trailing: some View {
        if let transient = model.transient {
            trailingContent(for: transient)
                .frame(maxWidth: Self.maxTextWidth + 40)
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .id(transient.family)
        } else if model.showsMusicActivity {
            Visualizer(playing: model.nowPlaying?.isPlaying ?? false, tint: model.tint, style: prefs.waveformStyle,
                       levels: prefs.liveWaveform && model.audioTap.isRunning ? model.audioTap.bands : nil)
                .opacity(prefs.compactWaveform ? 1 : 0)
                .padding(.leading, 4)
                .padding(.trailing, 12)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func trailingContent(for activity: TransientActivity) -> some View {
        switch activity {
        case .charging(let percent):
            peekLabel(prefs.batteryHideLabel ? nil : "Charging", value: prefs.batteryHidePercentage ? nil : "\(percent)%", color: Color(red: 0.2, green: 0.85, blue: 0.4))
        case .unplugged(let percent):
            peekLabel(prefs.batteryHideLabel ? nil : "On battery", value: prefs.batteryHidePercentage ? nil : "\(percent)%", color: .white)
        case .lowBattery(let percent):
            peekLabel(prefs.batteryHideLabel ? nil : "Low battery", value: prefs.batteryHidePercentage ? nil : "\(percent)%", color: Color(red: 1, green: 0.32, blue: 0.3))
        case .lowPowerMode(let on):
            peekLabel("Low Power Mode", value: on ? "On" : "Off", color: on ? .yellow : .white)
        case .volume(let level, let muted, _):
            HUDBar(level: Double(level), style: prefs.soundHUDStyle, showPercentage: prefs.soundHUDPercentage, muted: muted)
                .frame(width: prefs.soundHUDPercentage ? 96 : 62)
        case .brightness(let level):
            HUDBar(level: Double(level), style: prefs.displayHUDStyle, showPercentage: prefs.displayHUDPercentage)
                .frame(width: prefs.displayHUDPercentage ? 96 : 62)
        case .keyboardBacklight(let level):
            HUDBar(level: Double(level), style: prefs.displayHUDStyle, showPercentage: prefs.displayHUDPercentage)
                .frame(width: prefs.displayHUDPercentage ? 96 : 62)
        case .bluetooth(let event):
            VStack(alignment: .trailing, spacing: 1) {
                Text(event.name).font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.tail).frame(maxWidth: 130, alignment: .trailing)
                HStack(spacing: 6) {
                    Text(event.connected ? "Connected" : "Disconnected").foregroundStyle(.white.opacity(0.6))
                    if let left = event.left, let right = event.right {
                        Text("L \(left)%  R \(right)%").foregroundStyle(batteryColor(min(left, right)))
                    } else if let battery = event.battery {
                        Text("\(battery)%").foregroundStyle(batteryColor(battery))
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        case .bluetoothLow(let event):
            peekLabel(event.name, value: "\(event.battery ?? 0)%", color: Color(red: 1, green: 0.32, blue: 0.3))
        case .focus(let name, _, let on):
            peekLabel(prefs.focusHideLabel ? nil : (on ? name : "\(name) off"), value: nil, color: .white)
        case .event(let title, let minutes, _):
            VStack(alignment: .trailing, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(minutes <= 0 ? "Starting now" : "In \(minutes) min").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            }
        case .download(let name):
            VStack(alignment: .trailing, spacing: 1) {
                Text("Download finished").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                Text(name).font(.system(size: 12, weight: .semibold)).lineLimit(1).truncationMode(.middle)
            }
        case .capsLock(let on):
            peekLabel("Caps Lock", value: on ? "On" : "Off", color: .white)
        case .track(let title):
            MarqueeText(text: title, font: .system(size: 12, weight: .semibold), speed: 32).id(title)
                .frame(width: min(Self.maxTextWidth, CGFloat(title.count) * 7.2 + 8))
        case .copied:
            peekLabel("Copied", value: nil, color: .white)
        case .dropHint:
            peekLabel("Drop to shelf", value: nil, color: .white)
        }
    }

    private func peekLabel(_ label: String?, value: String?, color: Color) -> some View {
        HStack(spacing: 6) {
            if let label { Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.75)).lineLimit(1).truncationMode(.tail) }
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        level <= prefs.connectivityLowThreshold ? Color(red: 1, green: 0.32, blue: 0.3) : Color(red: 0.2, green: 0.85, blue: 0.4)
    }
}


private struct WidthReader: ViewModifier {
    let onChange: (CGFloat) -> Void
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onChange(geo.size.width) }
                    .onChange(of: geo.size.width) { _, new in onChange(new) }
                    .onDisappear { onChange(0) }
            }
        )
    }
}

extension View {
    /// Reports this view's laid-out width, and zero when it leaves the hierarchy.
    func measureWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(WidthReader(onChange: onChange))
    }
}
