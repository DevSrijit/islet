import AppKit
import Foundation

/// Display and keyboard backlight levels, read through private frameworks.
///
/// There is no public notification for either, so this polls a few times a second.
/// Every private symbol is looked up at runtime and the service silently does nothing when missing.
///
/// The system also changes both levels on its own (ambient light, idle dimming). Those changes
/// must not show a HUD, so the service only reports a display change that is a key step or
/// arrived right after a brightness key, and a keyboard change only after a backlight key.
final class BrightnessService {
    var onDisplayChange: ((Float) -> Void)?
    var onKeyboardChange: ((Float) -> Void)?

    /// A key press moves the display by 1/16. Ambient light moves it in far smaller steps.
    static let keyStep: Float = 0.03
    /// How long after a key press a change is still counted as caused by that key.
    static let keyWindow: TimeInterval = 1.0
    /// How long to wait for the level to move after a key press before showing the HUD anyway.
    static let keyFallbackDelay: TimeInterval = 0.3

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getDisplayBrightness: GetBrightness?
    private var keyboardClient: AnyObject?
    private var keyboardIMP: (@convention(c) (AnyObject, Selector, UInt64) -> Float)?
    private let keyboardSelector = Selector(("brightnessForKeyboard:"))

    private let keys: MediaKeyMonitor
    private var lastDisplay: Float?
    private var lastKeyboard: Float?
    private var lastDisplayEmit: Date?
    private var lastKeyboardEmit: Date?
    private var timer: Timer?
    private var started = false

    init(keys: MediaKeyMonitor = .shared) {
        self.keys = keys
    }

    /// Current display brightness in 0...1, when the private API is available.
    var currentDisplay: Float? { lastDisplay }
    /// Current keyboard backlight in 0...1, when the private API is available.
    var currentKeyboard: Float? { lastKeyboard }

    func start() {
        guard !started else { return }
        started = true
        loadDisplayServices()
        loadCoreBrightness()
        guard getDisplayBrightness != nil || keyboardIMP != nil else { return }
        lastDisplay = readDisplay()
        lastKeyboard = readKeyboard()
        keys.start()
        keys.addHandler { [weak self] key in self?.keyPressed(key) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
        timer?.tolerance = 0.05
    }

    func stop() {
        timer?.invalidate(); timer = nil
        started = false
    }

    private func poll() {
        if let value = readDisplay() {
            if let last = lastDisplay, abs(last - value) > 0.001 {
                let byKey = keys.pressed(.brightness, within: Self.keyWindow)
                if byKey || abs(last - value) >= Self.keyStep { emitDisplay(value) }
            }
            lastDisplay = value
        }
        if let value = readKeyboard() {
            if let last = lastKeyboard, abs(last - value) > 0.001, keys.pressed(.illumination, within: Self.keyWindow) {
                emitKeyboard(value)
            }
            lastKeyboard = value
        }
    }

    /// Shows the HUD after a key press even when the level cannot move, as the system bezel does.
    private func keyPressed(_ key: MediaKey) {
        let pressedAt = Date()
        switch key.family {
        case .brightness:
            guard getDisplayBrightness != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyFallbackDelay) { [weak self] in
                guard let self, self.lastDisplayEmit.map({ $0 < pressedAt }) ?? true else { return }
                if let value = self.readDisplay() { self.lastDisplay = value; self.emitDisplay(value) }
            }
        case .illumination:
            guard keyboardIMP != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.keyFallbackDelay) { [weak self] in
                guard let self, self.lastKeyboardEmit.map({ $0 < pressedAt }) ?? true else { return }
                if let value = self.readKeyboard() { self.lastKeyboard = value; self.emitKeyboard(value) }
            }
        case .sound:
            break
        }
    }

    private func emitDisplay(_ value: Float) {
        lastDisplayEmit = Date()
        onDisplayChange?(value)
    }

    private func emitKeyboard(_ value: Float) {
        lastKeyboardEmit = Date()
        onKeyboardChange?(value)
    }

    private func loadDisplayServices() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return }
        getDisplayBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
    }

    private func loadCoreBrightness() {
        guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY) != nil,
              let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return }
        let client = cls.init()
        guard client.responds(to: keyboardSelector),
              let method = class_getMethodImplementation(cls, keyboardSelector) else { return }
        keyboardClient = client
        keyboardIMP = unsafeBitCast(method, to: (@convention(c) (AnyObject, Selector, UInt64) -> Float).self)
    }

    private func readDisplay() -> Float? {
        guard let getDisplayBrightness else { return nil }
        var value: Float = 0
        guard getDisplayBrightness(CGMainDisplayID(), &value) == 0, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    private func readKeyboard() -> Float? {
        guard let keyboardIMP, let keyboardClient else { return nil }
        let value = keyboardIMP(keyboardClient, keyboardSelector, 1)
        guard value.isFinite, value >= 0 else { return nil }
        return min(value, 1)
    }
}
