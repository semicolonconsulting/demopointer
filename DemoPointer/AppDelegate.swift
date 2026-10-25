import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let magnifier = MagnifierController()
    private let settingsWindow = SettingsWindow()
    private var statusItem: NSStatusItem!
    private var didShowPermissionHelp = false
    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Left-click turns the magnifier on or off; right-click (or Control-click) opens the menu.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshStatusItem()

        LoginItem.applyDefaultIfNeeded()

        if !CGPreflightScreenCaptureAccess() {
            // Shows the system prompt the first time and adds Demo Pointer to the list in System Settings.
            _ = CGRequestScreenCaptureAccess()
        }
        if !UserDefaults.standard.bool(forKey: "welcomed") {
            settingsWindow.show(title: "Welcome to Demo Pointer")
            didShowPermissionHelp = true
        }

        magnifier.onCaptureFailure = { [weak self] _ in
            self?.showPermissionHelpIfNeeded()
        }
        magnifier.start()

        #if !APPSTORE
        Updates.startAutomaticChecks()
        #endif
    }

    // MARK: Status item

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // Attached only while it's open, so a left-click doesn't open it.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleEnabled()
        }
    }

    /// The ring is filled while the magnifier is on.
    private func refreshStatusItem() {
        statusItem.button?.image = StatusIcon.make(filled: settings.isEnabled)
        statusItem.button?.toolTip = settings.isEnabled
            ? "Demo Pointer is on: hold ⌘ to magnify. Click to turn off, right-click for settings."
            : "Demo Pointer is off. Click to turn on, right-click for settings."
    }

    // MARK: Menu

    /// Rebuilt each time it opens, so it reflects changes made in the Settings window or System Settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())

        menu.addItem(item("Magnify While Holding ⌘", #selector(toggleEnabled), on: settings.isEnabled))
        menu.addItem(.separator())

        let zoomMenu = NSMenu()
        for level in Settings.zoomLevels {
            let zoomItem = item(Settings.format(zoom: level), #selector(selectZoom(_:)), on: level == settings.zoom)
            zoomItem.representedObject = level
            zoomMenu.addItem(zoomItem)
        }
        let zoomItem = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        zoomItem.submenu = zoomMenu
        menu.addItem(zoomItem)

        let sizeMenu = NSMenu()
        for size in Settings.sizes {
            let sizeItem = item(size.name, #selector(selectSize(_:)), on: size.diameter == settings.diameter)
            sizeItem.representedObject = size.diameter
            sizeMenu.addItem(sizeItem)
        }
        let sizeItem = NSMenuItem(title: "Lens Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let shadeMenu = NSMenu()
        for shade in Settings.shades {
            let shadeItem = item(shade.name, #selector(selectShade(_:)), on: shade.opacity == settings.shadeOpacity)
            shadeItem.representedObject = shade.opacity
            shadeMenu.addItem(shadeItem)
        }
        let shadeItem = NSMenuItem(title: "Shade Screen", action: nil, keyEquivalent: "")
        shadeItem.submenu = shadeMenu
        menu.addItem(shadeItem)

        menu.addItem(.separator())
        menu.addItem(item("Open at Login", #selector(toggleOpenAtLogin), on: LoginItem.isEnabled))
        #if !APPSTORE
        menu.addItem(item("Check for Updates Automatically", #selector(toggleAutomaticUpdates), on: Updates.checksAutomatically))
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        #endif

        menu.addItem(.separator())
        menu.addItem(item("Screen Recording Settings…", #selector(openScreenRecordingSettings)))
        menu.addItem(item("Privacy Policy", #selector(openPrivacyPolicy)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Demo Pointer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "", on: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc private func showSettings() { settingsWindow.show() }
    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        refreshStatusItem()
    }
    @objc private func toggleOpenAtLogin() { LoginItem.set(!LoginItem.isEnabled) }
    @objc private func openScreenRecordingSettings() { SettingsWindow.openScreenRecordingSettings() }
    @objc private func openPrivacyPolicy() { NSWorkspace.shared.open(privacyPolicyURL) }

    #if !APPSTORE
    @objc private func checkForUpdates() { Updates.check(userInitiated: true) }
    @objc private func toggleAutomaticUpdates() { Updates.checksAutomatically.toggle() }
    #endif

    @objc private func selectZoom(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Double else { return }
        settings.zoom = level
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let diameter = sender.representedObject as? Double else { return }
        settings.diameter = diameter
    }

    @objc private func selectShade(_ sender: NSMenuItem) {
        guard let opacity = sender.representedObject as? Double else { return }
        settings.shadeOpacity = opacity
    }

    // MARK: Permission

    /// Capture failed, typically because Screen Recording isn't allowed yet: the Settings window explains
    /// how to allow it. Shown once per launch.
    private func showPermissionHelpIfNeeded() {
        guard !didShowPermissionHelp, !CGPreflightScreenCaptureAccess() else { return }
        didShowPermissionHelp = true
        settingsWindow.show()
    }
}
