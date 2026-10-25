import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let magnifier = MagnifierController()
    private var statusItem: NSStatusItem!
    private var didShowPermissionAlert = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magnifyingglass.circle", accessibilityDescription: "Demo Pointer")
        rebuildMenu()

        if !CGPreflightScreenCaptureAccess() {
            // Shows the system prompt the first time; afterwards the user grants it in System Settings.
            _ = CGRequestScreenCaptureAccess()
        }

        magnifier.onCaptureFailure = { [weak self] _ in
            self?.showPermissionAlertIfNeeded()
        }
        magnifier.start()
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let enabled = NSMenuItem(title: "Magnify While Holding ⌘", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = settings.isEnabled ? .on : .off
        menu.addItem(enabled)
        menu.addItem(.separator())

        let zoomMenu = NSMenu()
        for level in Settings.zoomLevels {
            let item = NSMenuItem(title: Self.format(zoom: level), action: #selector(selectZoom(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            item.state = level == settings.zoom ? .on : .off
            zoomMenu.addItem(item)
        }
        let zoomItem = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        zoomItem.submenu = zoomMenu
        menu.addItem(zoomItem)

        let sizeMenu = NSMenu()
        for size in Settings.sizes {
            let item = NSMenuItem(title: size.name, action: #selector(selectSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.diameter
            item.state = size.diameter == settings.diameter ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Lens Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        let permission = NSMenuItem(title: "Screen Recording Settings…", action: #selector(openScreenRecordingSettings), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Demo Pointer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private static func format(zoom: Double) -> String {
        zoom == zoom.rounded() ? "\(Int(zoom))×" : "\(zoom)×"
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func selectZoom(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Double else { return }
        settings.zoom = level
        rebuildMenu()
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let diameter = sender.representedObject as? Double else { return }
        settings.diameter = diameter
        rebuildMenu()
    }

    @objc private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Permission

    private func showPermissionAlertIfNeeded() {
        guard !didShowPermissionAlert, !CGPreflightScreenCaptureAccess() else { return }
        didShowPermissionAlert = true

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Demo Pointer needs Screen Recording permission"
        alert.informativeText = "Turn on Demo Pointer in System Settings › Privacy & Security › Screen & System Audio Recording, then quit and reopen Demo Pointer."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }
}
