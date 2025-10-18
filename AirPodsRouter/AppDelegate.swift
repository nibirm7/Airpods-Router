import Cocoa

@available(macOS 15.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if UserDefaults.standard.object(forKey: "isEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isEnabled")
        }
        AudioRouterService.shared.startMonitoring()
        if UserDefaults.standard.bool(forKey: "isEnabled") {
            AudioRouterService.shared.applyRoutingRule()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AudioRouterService.shared.stopMonitoring()
    }
}
