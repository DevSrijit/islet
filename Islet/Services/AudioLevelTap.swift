import CoreAudio
import Foundation
import Observation
import os

/// Four-band levels of whatever the Mac is playing, read from a CoreAudio process tap.
///
/// A process tap mirrors the system mix at the driver level. It cannot change what the user hears,
/// and the per-buffer work here is a handful of multiply-adds per sample. macOS asks for
/// "System Audio Recording" permission the first time the tap starts.
@MainActor
@Observable
final class AudioLevelTap {
    /// Smoothed band levels in 0...1, low to high.
    private(set) var bands: [Float] = [0, 0, 0, 0]
    private(set) var isRunning = false
    private(set) var failed = false

    @ObservationIgnored private var tapID = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var procID: AudioDeviceIOProcID?
    @ObservationIgnored private let lock = OSAllocatedUnfairLock(initialState: [Float](repeating: 0, count: 4))
    @ObservationIgnored private var uiTimer: Timer?
    @ObservationIgnored private var filters = BandFilters()

    static var isSupported: Bool {
        if #available(macOS 14.2, *) { return true } else { return false }
    }

    func start() {
        guard !isRunning, Self.isSupported else { return }
        if #available(macOS 14.2, *) {
            do {
                try createTap()
                isRunning = true
                failed = false
                uiTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.publish() }
                }
            } catch {
                NSLog("Islet: audio tap failed: \(error)")
                failed = true
                stop()
            }
        }
    }

    func stop() {
        uiTimer?.invalidate(); uiTimer = nil
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        procID = nil
        if #available(macOS 14.2, *), tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        isRunning = false
        bands = [0, 0, 0, 0]
    }

    private func publish() {
        let latest = lock.withLock { $0 }
        // Fast attack, slower release, so bars jump on beats and settle gently.
        for i in 0..<4 {
            let target = min(latest[i], 1)
            bands[i] = target > bands[i] ? target : bands[i] * 0.78 + target * 0.22
        }
    }

    @available(macOS 14.2, *)
    private func createTap() throws {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Islet Waveform"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        var tap = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(description, &tap), "create tap")
        tapID = tap

        let aggregateUID = UUID().uuidString
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Islet Waveform",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [] as [Any],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var aggregate = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregate), "create aggregate")
        aggregateID = aggregate

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        try check(AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format), "read format")
        filters.configure(sampleRate: format.mSampleRate > 0 ? format.mSampleRate : 48_000)
        let channels = Int(max(format.mChannelsPerFrame, 1))
        let lock = self.lock
        var filters = self.filters

        var proc: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&proc, aggregate, DispatchQueue(label: "com.devsrijit.islet.tap", qos: .userInteractive)) { _, input, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            guard let buffer = buffers.first, let data = buffer.mData else { return }
            let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.bindMemory(to: Float.self, capacity: count)
            let levels = filters.process(samples: samples, count: count, stride: channels)
            lock.withLock { $0 = levels }
        }
        try check(status, "create io proc")
        procID = proc
        try check(AudioDeviceStart(aggregate, proc), "start")
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        guard status == noErr else { throw NSError(domain: "Islet.AudioTap", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "\(what) failed (\(status))"]) }
    }
}

/// Cheap one-pole filters that split audio into four rough bands and report their energy.
private struct BandFilters {
    private var lowState: Float = 0
    private var midLowState: Float = 0
    private var midState: Float = 0
    private var highState: Float = 0
    private var alphas: [Float] = [0.01, 0.05, 0.2, 0.5]

    mutating func configure(sampleRate: Double) {
        let cutoffs: [Double] = [150, 600, 2_500, 8_000]
        alphas = cutoffs.map { cutoff in
            let rc = 1 / (2 * Double.pi * cutoff)
            let dt = 1 / sampleRate
            return Float(dt / (rc + dt))
        }
    }

    mutating func process(samples: UnsafePointer<Float>, count: Int, stride: Int) -> [Float] {
        guard count > 0 else { return [0, 0, 0, 0] }
        var energy: [Float] = [0, 0, 0, 0]
        var index = 0
        var frames = 0
        while index < count {
            let x = samples[index]
            // Successive low-pass stages; each band is the difference between neighbouring stages.
            lowState += alphas[0] * (x - lowState)
            midLowState += alphas[1] * (x - midLowState)
            midState += alphas[2] * (x - midState)
            highState += alphas[3] * (x - highState)
            let low = lowState
            let midLow = midLowState - lowState
            let mid = midState - midLowState
            let high = x - highState
            energy[0] += low * low
            energy[1] += midLow * midLow
            energy[2] += mid * mid
            energy[3] += high * high
            index += stride
            frames += 1
        }
        let n = Float(max(frames, 1))
        // RMS mapped through a soft curve so quiet passages still move the bars a little.
        let gains: [Float] = [3.2, 5.0, 7.0, 9.0]
        return (0..<4).map { i in
            let rms = (energy[i] / n).squareRoot()
            return min(1, powf(rms * gains[i], 0.6))
        }
    }
}
