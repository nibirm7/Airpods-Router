//
//  MenuBarView.swift
//  AirPodsRouter
//
//  Redesigned with Liquid Glass aesthetic - macOS Tahoe 26 inspired
//

import SwiftUI

@available(macOS 15.0, *)
struct MenuBarView: View {
    @Binding var isEnabled: Bool
    @Binding var launchAtLogin: Bool
    @ObservedObject var audioService: AudioRouterService

    @State private var showingQuitConfirmation = false

    var body: some View {
        VStack(spacing: 16) {  // Increased from 12 → more breathing room
            headerView
            mainToggleView
            
            if !audioService.connectedBTOutputs.isEmpty {
                connectedBTView
            }
            
            inputPickerView
            settingsView
            quitButton
        }
        .frame(width: 320)  // Slightly wider for comfort
        .padding(20)  // More generous padding
        .background(
            // Subtle ambient background for depth
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.02))
                .shadow(color: Color.black.opacity(0.05), radius: 40, x: 0, y: 20)
        )
    }

    // MARK: - Sections

    private var headerView: some View {
        HStack(spacing: 12) {
            // Premium icon treatment with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.15),
                                Color.blue.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "airpodspro")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("AirPods Router")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(audioService.lastAction)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if audioService.isStabilizing {
                        // Premium stabilizing badge
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .controlSize(.small)
                            
                            Text("Stabilizing")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
            
            Spacer()
            
            // Status indicator with glow
            ZStack {
                if isEnabled {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .blur(radius: 4)
                }
                
                Circle()
                    .fill(isEnabled ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 9, height: 9)
            }
        }
        .padding(14)
        .glassEffect(cornerRadius: 16, opacity: 0.16, blur: 24)
    }

    private var mainToggleView: some View {
        Toggle(isOn: $isEnabled.animation(.spring(response: 0.4, dampingFraction: 0.8))) {
            HStack(spacing: 10) {
                // Adaptive icon with subtle animation
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isEnabled ? .blue : .secondary)
                        .symbolEffect(.bounce, value: isEnabled)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto-Route Audio")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("BT output → Mac mic input")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .padding(14)
        .glassEffect(cornerRadius: 16, opacity: 0.16, blur: 24)
        .onChange(of: isEnabled) { newValue in
            if newValue {
                audioService.startMonitoring()
                audioService.applyRoutingRule()
            } else {
                audioService.stopMonitoring()
            }
        }
    }

    private var connectedBTView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Premium section header
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                
                Text("Connected Devices")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Device count badge
                Text("\(audioService.connectedBTOutputs.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.8))
                    )
            }

            VStack(spacing: 6) {
                ForEach(audioService.connectedBTOutputs, id: \.id) { device in
                    HStack(spacing: 8) {
                        // Animated connection indicator
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 8, height: 8)
                            
                            Circle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: 6, height: 6)
                        }
                        
                        Text(device.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(cornerRadius: 16, opacity: 0.16, blur: 24)
    }

    private var inputPickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Device")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                // Enhanced picker with icon
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding<UInt32>(
                        get: { audioService.selectedInputID ?? 0 },
                        set: { audioService.userSelectedInput(id: $0) }
                    )) {
                        ForEach(audioService.availableInputs, id: \.id) { dev in
                            Text(dev.name)
                                .tag(UInt32(dev.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                )

                if let mic = audioService.macBookMic {
                    Button {
                        audioService.userSelectedInput(id: mic.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Reset")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassEffect(cornerRadius: 16, opacity: 0.16, blur: 24)
    }

    private var settingsView: some View {
        VStack(spacing: 12) {
            // Launch at login toggle
            Toggle(isOn: $launchAtLogin.animation(.spring(response: 0.4, dampingFraction: 0.8))) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "power.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    
                    Text("Launch at Login")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
            .toggleStyle(.switch)

            // Apply now button - premium treatment
            Button {
                audioService.applyRoutingRule()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text("Apply Routing Now")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: isEnabled ? [
                                    Color.blue,
                                    Color.blue.opacity(0.85)
                                ] : [
                                    Color.gray.opacity(0.3),
                                    Color.gray.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isEnabled ? Color.white.opacity(0.3) : Color.white.opacity(0.1),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(
                            color: isEnabled ? Color.blue.opacity(0.3) : Color.clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .padding(14)
        .glassEffect(cornerRadius: 16, opacity: 0.16, blur: 24)
        .onChange(of: launchAtLogin) { newValue in
            if newValue { _ = LaunchAtLoginService.enable() }
            else { _ = LaunchAtLoginService.disable() }
        }
    }

    private var quitButton: some View {
        Button {
            showingQuitConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                
                Text("Quit App")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.red.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .alert("Quit AirPods Router?", isPresented: $showingQuitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) { NSApp.terminate(nil) }
        } message: {
            Text("Audio routing will stop.")
        }
    }
}
