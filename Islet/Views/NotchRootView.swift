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
                BlurBackdrop(fade: NotchViewModel.haloFade,
                             cornerRadius: Self.openBottomRadius,
                             edgeInset: Self.openTopRadius,
                             topInset: model.notchSize.height)
                    .frame(width: model.openSize.width + 2 * NotchViewModel.haloFade,
                           height: model.openSize.height + NotchViewModel.haloFade)
                    .allowsHitTesting(false)
                    .transition(.opacity)
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
                            .transition(.opacity.combined(with: .offset(x: -12)))
                    case .shelf:
                        ShelfView(model: model)
                            .transition(.opacity.combined(with: .offset(x: 12)))
                    }
                }
                .animation(model.spring, value: model.tab)
                .padding(.horizontal, Self.contentMargin)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .frame(width: model.openSize.width, height: NotchViewModel.openBodyHeight)
            }
            // Content fades in once the shape has room, and fades out fast so nothing
            // lingers while the shape collapses upward.
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).animation(.easeOut(duration: 0.22).delay(0.08)),
                removal: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)).animation(.easeIn(duration: 0.11))))
        } else {
            ClosedContentView(model: model, namespace: namespace)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.12)),
                    removal: .opacity.animation(.easeIn(duration: 0.08))))
        }
    }
}
