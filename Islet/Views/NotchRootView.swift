import SwiftUI

/// The whole notch: halo, island shape, and the closed or open content.
struct NotchRootView: View {
    var model: NotchViewModel
    @Namespace private var namespace

    private var prefs: Preferences { model.prefs }
    private var open: Bool { model.state == .open }

    /// Corner radii of the island. The open radius sets the concentric radii inside it.
    static let openBottomRadius: CGFloat = 22
    static let closedBottomRadius: CGFloat = 11
    static let openTopRadius: CGFloat = 8
    static let closedTopRadius: CGFloat = 6
    /// Side margin of the open content. Inner radii are `openBottomRadius - contentMargin`.
    static let contentMargin: CGFloat = 14

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if open, prefs.progressiveBlur {
                blurStrip
                    .padding(.top, model.openSize.height - 1)
                    .transition(.opacity.animation(.easeOut(duration: 0.3)))
            }
            island
        }
        .frame(width: model.panelSize.width, height: model.panelSize.height, alignment: .top)
        .opacity(model.isHidden ? 0 : 1)
        .animation(model.spring, value: model.currentSize)
        .animation(model.spring, value: open)
        .animation(.spring(duration: 0.3, bounce: 0.3), value: model.hoverBump)
        .preferredColorScheme(.dark)
    }

    /// Blurred, darkened strip below the island that fades out downward, like Alcove's.
    private var blurStrip: some View {
        let width = model.openSize.width - 2 * Self.openTopRadius
        let height = NotchViewModel.blurStripHeight
        return ZStack(alignment: .top) {
            BlurBackdrop()
                .frame(width: width, height: height)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.62), location: 0),
                .init(color: .black.opacity(0.28), location: 0.4),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: width, height: height)
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92), .init(color: .clear, location: 1),
            ], startPoint: .leading, endPoint: .trailing))
        }
        .allowsHitTesting(false)
    }

    /// Small controls in the black band beside the notch: shelf on the left, settings on the right.
    private var bandControls: some View {
        HStack {
            if prefs.shelfEnabled {
                BandButton(symbol: model.tab == .shelf ? "house.fill" : "tray.fill", active: model.tab == .shelf, help: model.tab == .shelf ? "Home" : "Shelf") {
                    model.switchTab(to: model.tab == .shelf ? .home : .shelf)
                    Haptics.play(.alignment)
                }
            }
            Spacer(minLength: 0)
            BandButton(symbol: "gearshape.fill", help: "Islet Settings") { AppDelegate.shared?.openSettings() }
        }
        .padding(.horizontal, Self.contentMargin)
        .frame(width: model.openSize.width, height: model.notchSize.height)
    }

    private var island: some View {
        let size = model.currentSize
        let shape = NotchShape(topRadius: open ? Self.openTopRadius : Self.closedTopRadius,
                               bottomRadius: open ? Self.openBottomRadius : Self.closedBottomRadius)
        return ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .overlay {
                    if prefs.contrastOutline {
                        shape.stroke(.white.opacity(0.14), lineWidth: 1).padding(0.5)
                    }
                }
                .shadow(color: .black.opacity(open ? 0.28 : 0), radius: 18, y: 8)
            content
                .clipShape(shape)
            if open {
                bandControls
                    .transition(.opacity.animation(.easeOut(duration: 0.2).delay(0.1)))
            }
        }
        .frame(width: size.width, height: size.height)
        .offset(x: open ? 0 : model.closedOffset)
        .scaleEffect(model.hoverBump && !open ? 1.035 : 1, anchor: .top)
        .contentShape(shape)
        .onTapGesture { if !open { model.open() } }
        .contextMenu {
            Button("Home") { model.open(tab: .home) }
            if prefs.shelfEnabled { Button("Shelf") { model.open(tab: .shelf) } }
            Divider()
            Button("Settings…") { AppDelegate.shared?.openSettings() }
            Divider()
            Button("Quit Islet") { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if open {
            VStack(spacing: 0) {
                // The menu bar band stays empty: only the black ears live there.
                Color.clear.frame(height: model.notchSize.height)
                ZStack {
                    switch model.tab {
                    case .home:
                        HomeView(model: model, namespace: namespace)
                            .transition(.opacity)
                    case .shelf:
                        ShelfView(model: model)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: model.tab)
                .padding(.horizontal, Self.contentMargin)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .frame(width: model.openSize.width, height: NotchViewModel.openBodyHeight)
            }
            // Content fades in once the shape has room, and fades out fast so nothing
            // lingers while the shape collapses upward.
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: -6)).animation(.easeOut(duration: 0.22).delay(0.08)),
                removal: .opacity.combined(with: .offset(y: -6)).animation(.easeIn(duration: 0.11))))
        } else {
            ClosedContentView(model: model, namespace: namespace)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.12)),
                    removal: .opacity.animation(.easeIn(duration: 0.08))))
        }
    }
}


/// A quiet symbol button for the black band.
private struct BandButton: View {
    let symbol: String
    var active = false
    var help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(hovering || active ? 0.95 : 0.42))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(help)
    }
}
