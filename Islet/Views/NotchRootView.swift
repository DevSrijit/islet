import SwiftUI

/// The whole notch: halo, island shape, and the closed or open content.
struct NotchRootView: View {
    var model: NotchViewModel
    @Namespace private var namespace

    private var prefs: Preferences { model.prefs }
    private var open: Bool { model.state == .open }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if open, prefs.progressiveBlur {
                BlurBackdrop(fade: NotchViewModel.haloFade, cornerRadius: 22)
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
        let shape = NotchShape(topRadius: open ? 8 : 6, bottomRadius: open ? 22 : 11)
        return ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .overlay {
                    if prefs.contrastOutline {
                        shape.stroke(.white.opacity(0.14), lineWidth: 1).padding(0.5)
                    }
                }
                .shadow(color: .black.opacity(open ? 0.35 : 0), radius: 14, y: 6)
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
            SettingsLink { Text("Settings…") }
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
                Group {
                    switch model.tab {
                    case .home: HomeView(model: model, namespace: namespace)
                    case .shelf: ShelfView(model: model)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 14)
                .frame(width: model.openSize.width, height: NotchViewModel.openBodyHeight)
            }
            .transition(.opacity.combined(with: .offset(y: -8)))
        } else {
            ClosedContentView(model: model, namespace: namespace)
                .transition(.opacity)
        }
    }
}
