import AppKit
import ApplicationServices
import MacHyperKeyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var statusLine: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private let tap = HyperKeyTap()
    private lazy var settings = SettingsWindowController()
    private var permissionTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Preferences.registerDefaults()
        LoginItem.enableOnFirstRun()
        settings.onChange = { [weak self] in self?.applySettings() }
        settings.onMenuBarIconChange = { [weak self] in self?.updateStatusItem() }
        settings.accessibilityGranted = { [weak self] in self?.tap.isRunning ?? false }
        updateStatusItem()
        removeMappingsOnTermination()

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.tap.reset() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.applySettings()
        }

        // Shows the system prompt once; the settings window explains how to grant access if it is still missing.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), tap.start() {
            applySettings()
        } else {
            KeyRemapper.removeAll()
            waitForPermission()
        }
        // Opening the app by hand shows its settings, which is the only way in when the icon is hidden.
        if !launchedAtLogin || !tap.isRunning { settings.show() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap.reset()
        KeyRemapper.removeAll()
    }

    /// Applies the key mappings and hyper settings. The mappings are installed only while the tap
    /// runs, because without it the remapped key would do nothing at all.
    private func applySettings() {
        let configuration = Preferences.configuration
        tap.configuration = configuration
        if tap.isRunning {
            let capsLockWasRemapped = Preferences.appliedMappings.contains { $0.source == Keys.capsLock.mappingUsage }
            KeyRemapper.apply(configuration.mappings)
            // Caps lock can no longer be switched off from the keyboard, so don't leave it on.
            if configuration.capsLockKeyRemapped, !capsLockWasRemapped, !quickPressTogglesCapsLock(configuration) {
                CapsLock.isOn = false
            }
        }
        refreshMenu()
    }

    private func quickPressTogglesCapsLock(_ configuration: HyperConfiguration) -> Bool {
        configuration.quickPressAvailable && configuration.quickPressEnabled && configuration.quickPressKey == Keys.capsLock
    }

    /// Accessibility access is granted in System Settings while the app runs, so poll until the tap can be created.
    private func waitForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), tap.start() else { return }
            timer.invalidate()
            permissionTimer = nil
            applySettings()
            settings.refresh()
        }
    }

    /// The mappings outlive the app until the Mac restarts, so remove them on Ctrl-C and `kill` too.
    private func removeMappingsOnTermination() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    private var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    // MARK: Menu bar

    private func updateStatusItem() {
        if Preferences.hideMenuBarIcon {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "MacHyperKey")
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        permissionItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Quit MacHyperKey", action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshMenu()
    }

    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }

    private func refreshMenu() {
        guard let statusItem else { return }
        let configuration = Preferences.configuration
        let status: String
        if !tap.isRunning {
            status = "Needs Accessibility access"
        } else if !configuration.remapEnabled {
            status = "Hyper key off"
        } else {
            status = "Hyper key: \(configuration.physicalKey.name)"
        }
        statusLine.title = status
        permissionItem.isHidden = tap.isRunning
        statusItem.button?.appearsDisabled = !tap.isRunning || !configuration.remapEnabled
        statusItem.button?.toolTip = "MacHyperKey · \(status)"
    }

    @objc private func showSettings() { settings.show() }

    @objc private func openAccessibilitySettings() { settings.openAccessibilitySettings() }

    @objc private func quit() { NSApp.terminate(nil) }
}
