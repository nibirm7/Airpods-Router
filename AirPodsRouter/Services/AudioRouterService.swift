//
//  AudioRouterService.swift
//  AirPodsRouter
//
//  CoreAudio HAL version (no third-party deps). Requires macOS 15+.
//

import Foundation
import CoreAudio
import Combine

@available(macOS 15.0, *)
final class AudioRouterService: ObservableObject {

    // Lightweight device model for the UI
    struct DeviceInfo: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
    }

    static let shared = AudioRouterService()

    // MARK: - Published (UI)
    @Published var connectedBTOutputs: [DeviceInfo] = []   // Bluetooth outputs
    @Published var availableInputs: [DeviceInfo] = []      // All input-capable devices
    @Published var selectedInputID: AudioDeviceID?         // Current default input
    @Published var macBookMic: DeviceInfo?                 // Resolved built-in mic
    @Published var isMonitoring = false
    @Published var isStabilizing = false
    @Published var lastAction: String = "Ready"
    @Published var showMenuBar: Bool = true                // Controls visibility from App

    // MARK: - Private
    private let debounceInterval: TimeInterval = 0.35
    private var debounceTimer: Timer?
    private var reassertTimer: Timer?

    private struct PropertyListener {
        var address: AudioObjectPropertyAddress
        var block: AudioObjectPropertyListenerBlock
    }
    private var listeners: [PropertyListener] = []

    // User may manually pick an input; when set ≠ built-in, we stop the auto-reassert.
    private var userDesiredInputID: AudioDeviceID?

    // Heuristics
    private let headphoneNameHints = [
        "airpods", "beats", "buds", "headset", "earbuds", "headphones"
    ]

    private init() {
        setupHALListeners()
    }

    // MARK: - Public

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastAction = "Monitoring started"
        refreshCaches()
        updateMenuBarVisibility()
        print("🎧 [AudioRouter] Monitoring started")
    }

    func stopMonitoring() {
        isMonitoring = false
        isStabilizing = false
        debounceTimer?.invalidate()
        reassertTimer?.invalidate()
        lastAction = "Monitoring stopped"
        print("🎧 [AudioRouter] Monitoring stopped")
    }

    /// Called by UI; debounced to avoid flapping.
    func applyRoutingRule() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performRouting()
        }
    }

    /// Picker action: user explicitly selected an input device.
    func userSelectedInput(id: AudioDeviceID) {
        userDesiredInputID = id
        _ = setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, to: id)
        selectedInputID = id
        if macBookMic?.id != id {
            isStabilizing = false
            reassertTimer?.invalidate()
            lastAction = "Input → \(deviceName(id)) (manual)"
        } else {
            reassertInputPreference(for: 3.0, every: 0.25, micID: id)
        }
    }

    // MARK: - Core routing

    /// Route: any Bluetooth output → default/system output; Input → built-in mic (unless user overrode).
    private func performRouting() {
        refreshCaches()

        guard let bt = connectedBTOutputs.first else {
            lastAction = "Idle — no Bluetooth audio"
            updateMenuBarVisibility()
            return
        }

        // OUTPUT (apps) → Bluetooth device
        _ = setDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice, to: bt.id)
        // SYSTEM/ALERTS → Bluetooth device
        _ = setDefaultDevice(selector: kAudioHardwarePropertyDefaultSystemOutputDevice, to: bt.id)

        // INPUT → built-in mic, unless user explicitly picked something else
        if let desired = userDesiredInputID, desired != macBookMic?.id {
            _ = setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, to: desired)
            lastAction = "✓ \(bt.name) output + \(deviceName(desired)) mic (manual)"
            isStabilizing = false
            reassertTimer?.invalidate()
        } else if let mic = macBookMic {
            _ = setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, to: mic.id)
            lastAction = "✓ \(bt.name) output + \(mic.name) mic"
            reassertInputPreference(for: 4.0, every: 0.25, micID: mic.id)
        } else {
            lastAction = "✓ \(bt.name) output (no built-in mic found)"
        }

        updateMenuBarVisibility()
    }

    // MARK: - Stabilization

    private func reassertInputPreference(for duration: TimeInterval, every step: TimeInterval, micID: AudioDeviceID) {
        reassertTimer?.invalidate()
        isStabilizing = true
        let deadline = Date().addingTimeInterval(duration)

        reassertTimer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { [weak self] t in
            guard let self = self, self.isMonitoring else { t.invalidate(); self?.isStabilizing = false; return }
            if Date() > deadline { t.invalidate(); self.isStabilizing = false; return }
            if let desired = self.userDesiredInputID, desired != micID { t.invalidate(); self.isStabilizing = false; return }
            if let cur = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice),
               cur != micID {
                _ = self.setDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice, to: micID)
                print("🔁 [AudioRouter] Reasserted built-in mic")
            }
        }
    }

    // MARK: - Discovery & cache

    private func refreshCaches() {
        connectedBTOutputs = detectBluetoothOutputs()
        availableInputs   = detectInputs()
        selectedInputID   = getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        macBookMic        = resolveBuiltInMic()
    }

    private func updateMenuBarVisibility() {
        // Show only when a Bluetooth output exists
        showMenuBar = !connectedBTOutputs.isEmpty
    }

    private func detectBluetoothOutputs() -> [DeviceInfo] {
        allDevices()
            .filter { isAlive($0) && hasOutput($0) && isBluetooth($0) }
            .map { DeviceInfo(id: $0, name: deviceName($0)) }
            .sorted { $0.name < $1.name }
    }

    private func detectInputs() -> [DeviceInfo] {
        allDevices()
            .filter { isAlive($0) && hasInput($0) }
            .map { DeviceInfo(id: $0, name: deviceName($0)) }
            .sorted { $0.name < $1.name }
    }

    private func resolveBuiltInMic() -> DeviceInfo? {
        detectInputs().first { isBuiltInMicName($0.name) }
    }

    // MARK: - HAL listeners

    private func setupHALListeners() {
        // Devices added/removed
        addListener(selector: kAudioHardwarePropertyDevices) { [weak self] in
            guard let self, self.isMonitoring, UserDefaults.standard.bool(forKey: "isEnabled") else { return }
            self.refreshCaches()
            self.updateMenuBarVisibility()
            if !self.connectedBTOutputs.isEmpty {
                self.applyRoutingRule()
            } else {
                self.lastAction = "Idle — no Bluetooth audio"
            }
        }

        // Default input changed (update picker & honour manual choices)
        addListener(selector: kAudioHardwarePropertyDefaultInputDevice) { [weak self] in
            guard let self else { return }
            self.selectedInputID = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        }

        // Default output changed (keep caches fresh)
        addListener(selector: kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            self?.refreshCaches()
        }
    }

    private func addListener(selector: AudioObjectPropertySelector, handler: @escaping () -> Void) {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅ modern element constant
        )
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            DispatchQueue.main.async { handler() }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main,
            block
        )
        listeners.append(PropertyListener(address: addr, block: block))
    }

    deinit {
        for l in listeners {
            var addr = l.address
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &addr,
                DispatchQueue.main,
                l.block
            )
        }
        debounceTimer?.invalidate()
        reassertTimer?.invalidate()
    }

    // MARK: - HAL helpers

    private func allDevices() -> [AudioDeviceID] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }
        return ids
    }

    private func deviceName(_ id: AudioDeviceID) -> String {
        safeDeviceName(id) ?? "Device \(id)"
    }

    /// Warning-free CFString fetch using Unmanaged<CFString>.
    private func copyCFStringProperty(_ objectID: AudioObjectID,
                                      selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size) == noErr,
              size == UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        else { return nil }

        var unmanaged: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &unmanaged) { ptr in
            AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr, let u = unmanaged else { return nil }
        // Get semantics → unretained
        return (u.takeUnretainedValue() as String)
    }

    private func safeDeviceName(_ id: AudioDeviceID) -> String? {
        // Try modern name first
        if let s = copyCFStringProperty(id, selector: kAudioObjectPropertyName) { return s }
        // Legacy fallback
        if let s = copyCFStringProperty(id, selector: kAudioDevicePropertyDeviceNameCFString) { return s }
        return nil
    }

    private func isAlive(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var val: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        _ = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &val)
        return val != 0
    }

    private func hasInput(_ id: AudioDeviceID) -> Bool {
        countStreams(id, scope: kAudioDevicePropertyScopeInput) > 0
    }

    private func hasOutput(_ id: AudioDeviceID) -> Bool {
        countStreams(id, scope: kAudioDevicePropertyScopeOutput) > 0
    }

    private func countStreams(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &dataSize) == noErr else { return 0 }
        return Int(dataSize) / MemoryLayout<AudioStreamID>.size
    }

    private func isBluetooth(_ id: AudioDeviceID) -> Bool {
        // Strong check: kAudioDevicePropertyTransportType == Bluetooth
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport) == noErr {
            if transport == kAudioDeviceTransportTypeBluetooth { return true }
        }
        // Soft check: names with common hints
        let n = deviceName(id).lowercased()
        if headphoneNameHints.contains(where: { n.contains($0) }) { return true }
        return false
    }

    private func isBuiltInMicName(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("built-in") || n.contains("internal") || n.contains("macbook")
    }

    private func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr else {
            return nil
        }
        return id
    }

    @discardableResult
    private func setDefaultDevice(selector: AudioObjectPropertySelector, to id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain   // ✅
        )
        var dev = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &dev)
        if status == noErr {
            if let name = safeDeviceName(id) {
                let tag: String
                switch selector {
                case kAudioHardwarePropertyDefaultOutputDevice:        tag = "Output"
                case kAudioHardwarePropertyDefaultSystemOutputDevice:  tag = "System Output"
                case kAudioHardwarePropertyDefaultInputDevice:         tag = "Input"
                default:                                               tag = "Device"
                }
                print("✅ [AudioRouter] \(tag) → \(name)")
            }
            return true
        } else {
            print("❌ [AudioRouter] Failed to set default (selector \(selector)) OSStatus=\(status)")
            return false
        }
    }
}
