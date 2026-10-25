import AppKit

/// The Mac App Store requires a privacy policy link inside the app: it's in the menu and in this window.
let privacyPolicyURL = URL(string: "https://github.com/semicolonconsulting/demopointer/blob/main/PRIVACY.md")!

/// The welcome and settings window. Shown on first launch (menu bar apps are easy to miss), from Settings…
/// in the menu, and when capture fails because Screen Recording isn't allowed yet.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private let settings = Settings.shared
    private var window: NSWindow?
    private var permissionTimer: Timer?

    private let zoomPopUp = NSPopUpButton()
    private let sizePopUp = NSPopUpButton()
    private let shadePopUp = NSPopUpButton()
    private let loginBox = NSButton(checkboxWithTitle: "Open at Login", target: nil, action: nil)
    #if !APPSTORE
    private let updatesBox = NSButton(checkboxWithTitle: "Check for Updates Automatically", target: nil, action: nil)
    #endif
    private let permissionIcon = NSImageView()
    private let permissionText = NSTextField(wrappingLabelWithString: "")
    private let permissionButtons = NSStackView()

    static var hasScreenRecordingAccess: Bool { CGPreflightScreenCaptureAccess() }

    func show(title: String = "Settings") {
        let window = preparedWindow()
        window.title = title
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startWatchingPermission()
    }

    private func preparedWindow() -> NSWindow {
        if window == nil { window = makeWindow() }
        update()
        return window!
    }

    // MARK: NSWindowDelegate

    /// It counts as seen once it's closed, so quitting before reading it shows it again next time.
    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "welcomed")
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    /// The menu bar menu can change things while the window is open.
    func windowDidBecomeKey(_ notification: Notification) { update() }

    // MARK: State

    private func update() {
        zoomPopUp.selectItem(at: Settings.zoomLevels.firstIndex(of: settings.zoom) ?? 1)
        sizePopUp.selectItem(at: Settings.sizes.firstIndex { $0.diameter == settings.diameter } ?? 1)
        shadePopUp.selectItem(at: Settings.shades.firstIndex { $0.opacity == settings.shadeOpacity } ?? 1)
        loginBox.state = LoginItem.isEnabled ? .on : .off
        #if !APPSTORE
        updatesBox.state = Updates.checksAutomatically ? .on : .off
        #endif
        updatePermission()
    }

    private func updatePermission() {
        if Self.hasScreenRecordingAccess {
            permissionIcon.image = symbol("checkmark.circle.fill")
            permissionIcon.contentTintColor = .systemGreen
            permissionText.stringValue = "Screen Recording is allowed. Demo Pointer is ready."
            permissionButtons.isHidden = true
        } else {
            permissionIcon.image = symbol("exclamationmark.triangle.fill")
            permissionIcon.contentTintColor = .systemOrange
            permissionText.stringValue = "Demo Pointer needs Screen Recording permission to draw the lens. "
                + "Turn on Demo Pointer in System Settings, then reopen it."
            permissionButtons.isHidden = false
        }
    }

    /// macOS doesn't notify apps when the permission changes, so look while the window is open.
    private func startWatchingPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePermission() }
        }
    }

    // MARK: Actions

    @objc private func selectZoom() { settings.zoom = Settings.zoomLevels[zoomPopUp.indexOfSelectedItem] }
    @objc private func selectSize() { settings.diameter = Settings.sizes[sizePopUp.indexOfSelectedItem].diameter }
    @objc private func selectShade() { settings.shadeOpacity = Settings.shades[shadePopUp.indexOfSelectedItem].opacity }

    @objc private func toggleLogin() {
        LoginItem.set(loginBox.state == .on)
        update()
    }

    #if !APPSTORE
    @objc private func toggleUpdates() { Updates.checksAutomatically = updatesBox.state == .on }
    @objc private func checkForUpdates() { Updates.check(userInitiated: true) }
    #endif

    @objc private func openScreenRecordingSettings() { Self.openScreenRecordingSettings() }
    @objc private func reopen() { Self.relaunch() }
    @objc private func done() { window?.close() }
    @objc private func openPrivacyPolicy() { NSWorkspace.shared.open(privacyPolicyURL) }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// macOS applies a newly granted Screen Recording permission only after the app restarts.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    NSLog("DemoPointer: could not relaunch: \(error.localizedDescription)")
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: Layout

    private func makeWindow() -> NSWindow {
        let width: CGFloat = 540, inset: CGFloat = 24
        let textWidth = width - inset * 2 - 36
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        // The app file's icon as macOS draws it (on macOS 26 and later, with the system's shape and glass).
        // It comes at 32 pt, and image views don't scale up, so ask for the size it's shown at.
        let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        appIcon.size = NSSize(width: 72, height: 72)
        let icon = NSImageView(image: appIcon)
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let titles = NSStackView(views: [label("Demo Pointer", font: .systemFont(ofSize: 22, weight: .semibold)),
                                         label("A magnifying lens for live demos.", color: .secondaryLabelColor)])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 4
        let header = NSStackView(views: [icon, titles])
        header.spacing = 16

        let steps = [
            (symbol("command"),
             "Hold the ⌘ Command key by itself and a magnifying lens follows your pointer. Let go and it fades away. "
                + "It shows up in screen shares and recordings too."),
            (symbol("menubar.rectangle"),
             "Click the Demo Pointer icon in the menu bar to turn it on or off: the circle is filled while it's on. "
                + "Right-click it for settings. Can't see it? A full menu bar, the notch or a menu bar manager can hide it."),
        ].map { image, text in step(image, text, width: textWidth) }

        permissionText.preferredMaxLayoutWidth = textWidth
        permissionIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let openSettings = NSButton(title: "Open System Settings", target: self, action: #selector(openScreenRecordingSettings))
        let reopenButton = NSButton(title: "Reopen Demo Pointer", target: self, action: #selector(reopen))
        permissionButtons.setViews([openSettings, reopenButton], in: .leading)
        permissionButtons.spacing = 8
        let permissionColumn = NSStackView(views: [permissionText, permissionButtons])
        permissionColumn.orientation = .vertical
        permissionColumn.alignment = .leading
        permissionColumn.spacing = 8
        let permission = NSStackView(views: [permissionIcon, permissionColumn])
        permission.alignment = .top
        permission.spacing = 12

        zoomPopUp.addItems(withTitles: Settings.zoomLevels.map(Settings.format(zoom:)))
        zoomPopUp.target = self
        zoomPopUp.action = #selector(selectZoom)
        sizePopUp.addItems(withTitles: Settings.sizes.map(\.name))
        sizePopUp.target = self
        sizePopUp.action = #selector(selectSize)
        shadePopUp.addItems(withTitles: Settings.shades.map(\.name))
        shadePopUp.target = self
        shadePopUp.action = #selector(selectShade)
        let lens = NSStackView(views: [label("Zoom:"), zoomPopUp, label("Lens size:"), sizePopUp,
                                       label("Shade:"), shadePopUp])
        lens.spacing = 8
        lens.setCustomSpacing(20, after: zoomPopUp)
        lens.setCustomSpacing(20, after: sizePopUp)

        let separator = NSBox()
        separator.boxType = .separator

        loginBox.target = self
        loginBox.action = #selector(toggleLogin)
        var checkboxes: [NSView] = [loginBox]
        #if !APPSTORE
        updatesBox.target = self
        updatesBox.action = #selector(toggleUpdates)
        checkboxes.append(updatesBox)
        #endif
        let options = NSStackView(views: checkboxes)
        options.orientation = .vertical
        options.alignment = .leading
        options.spacing = 8
        options.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        var buttons: [NSView] = [options, spacer]
        #if !APPSTORE
        buttons.append(NSButton(title: "Check Now", target: self, action: #selector(checkForUpdates)))
        #endif
        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.keyEquivalent = "\r"
        buttons.append(doneButton)
        let controls = NSStackView(views: buttons)
        controls.alignment = .bottom

        let privacy = NSButton(title: "Privacy Policy", target: self, action: #selector(openPrivacyPolicy))
        privacy.isBordered = false
        privacy.contentTintColor = .linkColor
        privacy.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let footer = NSStackView(views: [label("Version \(version)  ·", font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                                               color: .secondaryLabelColor), privacy])
        footer.spacing = 4

        let stack = NSStackView(views: [header] + steps + [permission, lens, separator, controls, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: inset, left: inset, bottom: 20, right: inset)
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        for row in [separator, controls] {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -inset * 2).isActive = true
        }

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentView = stack
        window.isReleasedWhenClosed = false
        window.delegate = self
        update()
        stack.layoutSubtreeIfNeeded()
        window.setContentSize(stack.fittingSize)
        window.center()
        return window
    }

    private func label(_ text: String, font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
                       color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        return field
    }

    private func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))!
    }

    private func step(_ image: NSImage, _ text: String, width: CGFloat) -> NSView {
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let field = NSTextField(wrappingLabelWithString: text)
        field.preferredMaxLayoutWidth = width
        let row = NSStackView(views: [imageView, field])
        row.alignment = .top
        row.spacing = 12
        return row
    }
}
