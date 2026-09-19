import AppKit
import Foundation

/// Display and keyboard backlight levels, read through private frameworks.
///
/// There is no public notification for either, so this polls a few times a second.
/// Every private symbol is looked up at runtime and the service silently does nothing when missing.
final class BrightnessService {
    var onDisplayChange: ((Float) -> Void)?
    var onKeyboardChange: ((Float) -> Void)?

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getDisplayBrightness: GetBrightness?
    private var keyboardClient: AnyObject?
    private var keyboardIMP: (@convention(c) (AnyObject, Selector, UInt64) -> Float)?
    private let keyboardSelector = Selector(("brightnessForKeyboard:"))

    private var lastDisplay: Float?
    private var lastKeyboard: Float?
    private var timer: Timer?

    func start() {
        loadDisplayServices()
        loadCoreBrightness()
        guard getDisplayBrightness != nil || keyboardIMP != nil else { return }
        lastDisplay = readDisplay()
        lastKeyboard = readKeyboard()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
        timer?.tolerance = 0.05
    }

    private func poll() {
        if let value = readDisplay() {
            if let last = lastDisplay, abs(last - value) > 0.001 { onDisplayChange?(value) }
            lastDisplay = value
        }
        if let value = readKeyboard() {
            if let last = lastKeyboard, abs(last - value) > 0.001 { onKeyboardChange?(value) }
            lastKeyboard = value
        }
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
        guard getDisplayBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
        return value
    }

    private func readKeyboard() -> Float? {
        guard let keyboardIMP, let keyboardClient else { return nil }
        let value = keyboardIMP(keyboardClient, keyboardSelector, 1)
        guard value.isFinite, value >= 0 else { return nil }
        return min(value, 1)
    }
}
