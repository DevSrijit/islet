import AppKit

/// Where the notch is, and how big it is, on one screen.
struct NotchGeometry: Equatable {
    let screenFrame: CGRect
    let hasPhysicalNotch: Bool
    /// Size of the black area at the top centre of the screen.
    let notchSize: CGSize
    let screenID: CGDirectDisplayID?

    static let fallbackWidth: CGFloat = 184

    /// Picks the screen to use.
    /// - `auto`: the screen with a real notch, else the main screen when a simulated notch is allowed.
    /// - `main`, `builtin`, or a display UUID: that screen, simulating a notch when it has none.
    static func detect(target: String, allowSimulated: Bool) -> NotchGeometry? {
        let screens = NSScreen.screens
        switch target {
        case "main":
            return (NSScreen.main ?? screens.first).map(NotchGeometry.init(screen:))
        case "builtin":
            return screens.first(where: { $0.displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false }).map(NotchGeometry.init(screen:))
        case "auto":
            if let notched = screens.first(where: { $0.safeAreaInsets.top > 0 }) { return NotchGeometry(screen: notched) }
            guard allowSimulated, let main = NSScreen.main ?? screens.first else { return nil }
            return NotchGeometry(screen: main)
        default:
            if let match = screens.first(where: { $0.displayUUID == target }) { return NotchGeometry(screen: match) }
            return detect(target: "auto", allowSimulated: allowSimulated)
        }
    }

    init(screen: NSScreen) {
        screenFrame = screen.frame
        screenID = screen.displayID
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasPhysicalNotch = true
            let width = screen.frame.width - left.width - right.width
            notchSize = CGSize(width: max(width, 100), height: top)
        } else {
            hasPhysicalNotch = false
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            let height = (22...40).contains(menuBar) ? menuBar : 24
            notchSize = CGSize(width: Self.fallbackWidth, height: height)
        }
    }

    /// Screen-space rectangle for a notch view of `size`, anchored at the top centre.
    func rect(for size: CGSize) -> CGRect {
        CGRect(x: screenFrame.midX - size.width / 2,
               y: screenFrame.maxY - size.height,
               width: size.width,
               height: size.height)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Stable identifier that survives reconnecting the display.
    var displayUUID: String? {
        guard let id = displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
