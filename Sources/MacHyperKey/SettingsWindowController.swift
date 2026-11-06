import AppKit
import MacHyperKeyCore
import ServiceManagement

/// The settings window, laid out like Hyperkey's: key remapping, modifiers, and app options.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    /// Called after any hyper key setting changes.
    var onChange: () -> Void = {}
    /// Called when "Hide menu bar icon" changes.
    var onMenuBarIconChange: () -> Void = {}
    var accessibilityGranted: () -> Bool = { true }

    private let keycap = KeycapView()
    private let modifierLabel = NSTextField(labelWithString: "")
    private let remapCheckbox = NSButton(checkboxWithTitle: "Remap physical key to hyper key:", target: nil, action: nil)
    private let physicalPopup = NSPopUpButton()
    private let capsLockCheckbox = NSButton(checkboxWithTitle: "Remap caps lock to:", target: nil, action: nil)
    private let capsLockPopup = NSPopUpButton()
    private let quickPressCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let quickPressPopup = NSPopUpButton()
    private let shiftCheckbox = NSButton(checkboxWithTitle: "Include shift in hyper key", target: nil, action: nil)
    private var mouseCheckboxes: [MouseAction: NSButton] = [:]
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open on login", target: nil, action: nil)
    private let hideIconCheckbox = NSButton(checkboxWithTitle: "Hide menu bar icon", target: nil, action: nil)
    private let permissionBox = NSStackView()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "MacHyperKey"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        refresh()
        if window?.isVisible != true { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) { refresh() }

    // MARK: Layout

    private func buildContent() {
        fill(physicalPopup, with: Keys.physicalChoices)
        fill(capsLockPopup, with: Keys.capsLockTargets)
        fill(quickPressPopup, with: Keys.quickPressTargets)
        for control in [remapCheckbox, capsLockCheckbox, quickPressCheckbox, shiftCheckbox] as [NSButton] {
            control.target = self
            control.action = #selector(controlChanged)
            control.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        for popup in [physicalPopup, capsLockPopup, quickPressPopup] {
            popup.target = self
            popup.action = #selector(controlChanged)
            popup.widthAnchor.constraint(equalToConstant: 150).isActive = true
        }
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin)
        hideIconCheckbox.target = self
        hideIconCheckbox.action = #selector(toggleHideIcon)

        let remapGrid = NSGridView(views: [
            [remapCheckbox, physicalPopup],
            [capsLockCheckbox, capsLockPopup],
            [quickPressCheckbox, quickPressPopup]
        ])
        remapGrid.rowSpacing = 8
        remapGrid.columnSpacing = 12
        remapGrid.column(at: 1).xPlacement = .trailing
        for row in 0..<remapGrid.numberOfRows { remapGrid.row(at: row).yPlacement = .center }

        modifierLabel.font = .systemFont(ofSize: 22, weight: .regular)
        modifierLabel.textColor = .secondaryLabelColor
        let mouseRow = NSStackView(views: MouseAction.allCases.map { action in
            let box = NSButton(checkboxWithTitle: action.rawValue.capitalized, target: self, action: #selector(controlChanged))
            mouseCheckboxes[action] = box
            return box
        })
        mouseRow.spacing = 12
        let modifiersColumn = column([
            shiftCheckbox,
            spacer(4),
            NSTextField(labelWithString: "Apply hyper key modifiers to keypress events and:"),
            mouseRow
        ], spacing: 6)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let versionLabel = NSTextField(labelWithString: "v\(version) (\(build))")
        versionLabel.textColor = .secondaryLabelColor
        let loginRow = NSStackView(views: [loginCheckbox, NSView(), versionLabel])
        loginRow.distribution = .fill
        let hint = NSTextField(labelWithString: "When hidden, relaunch from Finder to open.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        let appColumn = column([loginRow, hideIconCheckbox, hint], spacing: 6)

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown

        let permissionText = NSTextField(wrappingLabelWithString:
            "MacHyperKey needs Accessibility access to turn the key into a hyper key.")
        permissionText.preferredMaxLayoutWidth = 300
        let permissionButton = NSButton(title: "Open Settings…", target: self, action: #selector(openAccessibilitySettings))
        permissionBox.setViews([NSImageView(image: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)!),
                                permissionText, permissionButton], in: .leading)
        permissionBox.spacing = 10

        let sections = NSStackView(views: [
            permissionBox,
            section(keycap, remapGrid),
            separator(),
            section(modifierLabel, modifiersColumn),
            separator(),
            section(icon, appColumn)
        ])
        sections.orientation = .vertical
        sections.alignment = .leading
        sections.spacing = 16
        sections.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(sections)
        NSLayoutConstraint.activate([
            sections.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            sections.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            sections.topAnchor.constraint(equalTo: content.topAnchor, constant: 36),
            sections.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            sections.widthAnchor.constraint(greaterThanOrEqualToConstant: 540),
            keycap.widthAnchor.constraint(equalToConstant: 80),
            keycap.heightAnchor.constraint(equalToConstant: 64),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64)
        ])
        for view in sections.arrangedSubviews { view.widthAnchor.constraint(equalTo: sections.widthAnchor).isActive = true }
        window?.contentView = content
    }

    private func section(_ illustration: NSView, _ controls: NSView) -> NSView {
        let holder = NSView()
        illustration.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(illustration)
        NSLayoutConstraint.activate([
            holder.widthAnchor.constraint(equalToConstant: 88),
            illustration.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
            illustration.centerYAnchor.constraint(equalTo: holder.centerYAnchor)
        ])
        controls.setContentHuggingPriority(.init(1), for: .horizontal)
        let row = NSStackView(views: [holder, controls])
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 16
        holder.heightAnchor.constraint(equalTo: row.heightAnchor).isActive = true
        return row
    }

    private func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        for view in views where view is NSStackView && (view as! NSStackView).distribution == .fill {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let view = NSView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func fill(_ popup: NSPopUpButton, with keys: [Key]) {
        for key in keys {
            popup.addItem(withTitle: key.name)
            popup.lastItem?.tag = Int(key.usage)
        }
    }

    // MARK: State

    func refresh() {
        let configuration = Preferences.configuration
        keycap.label = configuration.physicalKey.name
        keycap.showsLight = configuration.physicalKey == Keys.capsLock
        keycap.isEnabled = configuration.remapEnabled
        modifierLabel.stringValue = configuration.includeShift ? "^⌥⇧⌘" : "^⌥⌘"

        remapCheckbox.state = configuration.remapEnabled ? .on : .off
        physicalPopup.selectItem(withTag: Int(configuration.physicalKey.usage))
        physicalPopup.isEnabled = configuration.remapEnabled

        let capsLockAvailable = configuration.capsLockRemapAvailable
        capsLockCheckbox.isEnabled = capsLockAvailable
        capsLockCheckbox.state = capsLockAvailable && configuration.capsLockRemapEnabled ? .on : .off
        capsLockPopup.selectItem(withTag: Int(configuration.capsLockTarget.usage))
        capsLockPopup.isEnabled = capsLockAvailable && configuration.capsLockRemapEnabled

        quickPressCheckbox.title = "Quick press \(configuration.physicalKey.name) to execute:"
        quickPressCheckbox.isEnabled = configuration.quickPressAvailable
        quickPressCheckbox.state = configuration.quickPressEnabled ? .on : .off
        quickPressPopup.selectItem(withTag: Int(configuration.quickPressKey.usage))
        quickPressPopup.isEnabled = configuration.quickPressAvailable && configuration.quickPressEnabled

        shiftCheckbox.state = configuration.includeShift ? .on : .off
        for (action, box) in mouseCheckboxes { box.state = configuration.mouseActions.contains(action) ? .on : .off }

        let login = SMAppService.mainApp.status
        loginCheckbox.state = login == .enabled ? .on : login == .requiresApproval ? .mixed : .off
        hideIconCheckbox.state = Preferences.hideMenuBarIcon ? .on : .off
        permissionBox.isHidden = accessibilityGranted()
    }

    @objc private func controlChanged() {
        var configuration = Preferences.configuration
        configuration.remapEnabled = remapCheckbox.state == .on
        configuration.physicalKey = selectedKey(physicalPopup, in: Keys.physicalChoices) ?? configuration.physicalKey
        if capsLockCheckbox.isEnabled { configuration.capsLockRemapEnabled = capsLockCheckbox.state == .on }
        configuration.capsLockTarget = selectedKey(capsLockPopup, in: Keys.capsLockTargets) ?? configuration.capsLockTarget
        configuration.quickPressEnabled = quickPressCheckbox.state == .on
        configuration.quickPressKey = selectedKey(quickPressPopup, in: Keys.quickPressTargets) ?? configuration.quickPressKey
        configuration.includeShift = shiftCheckbox.state == .on
        configuration.mouseActions = Set(mouseCheckboxes.filter { $0.value.state == .on }.map(\.key))
        Preferences.configuration = configuration
        refresh()
        onChange()
    }

    private func selectedKey(_ popup: NSPopUpButton, in keys: [Key]) -> Key? {
        popup.selectedItem.flatMap { Keys.key(usage: UInt32($0.tag), in: keys) }
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()
        refresh()
    }

    @objc private func toggleHideIcon() {
        Preferences.hideMenuBarIcon = hideIconCheckbox.state == .on
        onMenuBarIconChange()
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

/// A keycap showing the physical hyper key, with caps lock's light when it is caps lock.
final class KeycapView: NSView {
    var label = "" { didSet { needsDisplay = true } }
    var showsLight = false { didSet { needsDisplay = true } }
    var isEnabled = true { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1.5, dy: 1.5)
        let cap = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        cap.fill()
        NSColor.tertiaryLabelColor.setStroke()
        cap.lineWidth = 1
        cap.stroke()
        let color: NSColor = isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        if showsLight {
            (isEnabled ? NSColor.labelColor : NSColor.tertiaryLabelColor).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX + 8, y: rect.maxY - 13, width: 4, height: 4)).fill()
        }
        let text = NSAttributedString(string: label, attributes: [
            .font: NSFont.systemFont(ofSize: 10), .foregroundColor: color
        ])
        let size = text.size()
        text.draw(in: NSRect(x: rect.minX + 6, y: rect.minY + 5, width: rect.width - 12, height: size.height))
    }
}

enum LoginItem {
    static func toggle() {
        do {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Open on login could not be changed"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// Open on login defaults to on, but only once, so turning it off sticks.
    static func enableOnFirstRun() {
        let key = "launchAtLoginConfigured"
        // Skip `swift run` binaries and translocated copies, whose paths would not survive a restart.
        let path = Bundle.main.bundlePath
        guard !UserDefaults.standard.bool(forKey: key), path.hasSuffix(".app"), !path.contains("/AppTranslocation/") else { return }
        if SMAppService.mainApp.status == .notRegistered, (try? SMAppService.mainApp.register()) == nil { return }
        UserDefaults.standard.set(true, forKey: key)
    }
}
