//
//  AirPodsRouterApp.swift
//  AirPodsRouter
//

import SwiftUI
import ServiceManagement

@available(macOS 15.0, *)
@main
struct AirPodsRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioService = AudioRouterService.shared
    @AppStorage("isEnabled") private var isEnabled = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some Scene {
        // Read-only binding; view re-renders when the Published value changes.
        MenuBarExtra(isInserted: .constant(audioService.showMenuBar)) {
            MenuBarView(
                isEnabled: $isEnabled,
                launchAtLogin: $launchAtLogin,
                audioService: audioService
            )
        } label: {
            Image(systemName: isEnabled ? "airpodspro" : "airpodspro.slash")
                .font(.system(size: 16, weight: .medium))
        }
        .menuBarExtraStyle(.window)
    }
}
