//
//  LaunchAtLoginService.swift
//  AirPodsRouter
//
//  Created by Abdullah Khan on 2025-10-17.
//

import Foundation
import ServiceManagement

/// Manages launch-at-login functionality using SMAppService
final class LaunchAtLoginService {
    
    @discardableResult
    static func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            print("✅ [LaunchAtLogin] Registered")
            return true
        } catch {
            print("❌ [LaunchAtLogin] Failed to register: \(error)")
            return false
        }
    }
    
    @discardableResult
    static func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            print("✅ [LaunchAtLogin] Unregistered")
            return true
        } catch {
            print("❌ [LaunchAtLogin] Failed to unregister: \(error)")
            return false
        }
    }
    
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
