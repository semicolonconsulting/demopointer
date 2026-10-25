import Foundation
import ServiceManagement

/// Open at Login, through macOS's login items (allowed in the App Sandbox).
enum LoginItem {
    private static let defaultAppliedKey = "openAtLoginDefaultApplied"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Turns it on or off and returns whether it's on afterwards. If macOS wants the user's
    /// approval first, opens Login Items in System Settings.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("DemoPointer: could not \(on ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        UserDefaults.standard.set(true, forKey: defaultAppliedKey)
        return isEnabled
    }

    /// Open at Login is on by default. Applied once, and only when running from an Applications
    /// folder, so a copy opened straight from the disk image or Downloads doesn't register itself.
    static func applyDefaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: defaultAppliedKey), isInApplicationsFolder else { return }
        set(true)
    }

    private static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        let folders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        return folders.contains { $0.standardizedFileURL.path == path }
    }
}
