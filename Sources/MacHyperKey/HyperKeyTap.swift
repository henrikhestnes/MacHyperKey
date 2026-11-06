import CoreGraphics
import Foundation
import MacHyperKeyCore

/// Turns the trigger key (the remapped physical key) into ⌃⌥⌘ (and optionally ⇧).
///
/// While hyper is held, the tap adds the hyper flags to every key event and to the mouse events
/// chosen in settings. It also posts modifier key events when hyper goes down and up, so apps that
/// watch modifier changes see hyper pressed and released. Needs Accessibility access.
final class HyperKeyTap {
    var configuration = HyperConfiguration() {
        didSet { if !configuration.hyperActive { release(quickPress: false) } }
    }

    private var tap: CFMachPort?
    private var session = HyperSession()
    /// A private state table, so the posted modifier events never stick to the real keyboard state.
    private let source = CGEventSource(stateID: .privateState)
    /// Marks events this app posts so the tap lets them through untouched.
    private static let marker: Int64 = 0x4859_5045_524B // "HYPERK"
    private var watchdog: Timer?
    private var sawTriggerDown = false

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .mouseMoved, .scrollWheel
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            Unmanaged<HyperKeyTap>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
        }
        // The HID tap sees events before any app or session-level tap, so shortcuts registered
        // anywhere see the hyper flags.
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Releases hyper without a quick press, for example before sleep or when the screen locks.
    func reset() {
        release(quickPress: false)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return Unmanaged.passUnretained(event) }

        switch type {
        case .keyDown, .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == Int64(Keys.trigger.keyCode), configuration.hyperActive {
                if type == .keyDown {
                    if session.press(at: now) { press() }
                } else {
                    release(quickPress: true)
                }
                return nil
            }
            if type == .keyDown { session.interrupt() }
            addHyper(to: event)
        case .flagsChanged:
            session.interrupt()
            addHyper(to: event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            session.interrupt()
            addHyper(to: event, for: .click)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            addHyper(to: event, for: .click)
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            addHyper(to: event, for: .drag)
        case .mouseMoved:
            addHyper(to: event, for: .move)
        case .scrollWheel:
            session.interrupt()
            addHyper(to: event, for: .scroll)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func addHyper(to event: CGEvent, for action: MouseAction? = nil) {
        guard session.isActive else { return }
        if let action, !configuration.mouseActions.contains(action) { return }
        event.flags = CGEventFlags(rawValue: event.flags.rawValue | configuration.hyperFlags)
    }

    // MARK: Hyper down and up

    private func press() {
        var flags = physicalFlags
        for modifier in configuration.modifiers {
            flags |= modifier.flags
            postModifier(modifier.keyCode, flags: flags)
        }
        startWatchdog()
    }

    private func release(quickPress: Bool) {
        guard session.isActive else { return }
        let fire = session.release(at: now) && quickPress && configuration.quickPressEnabled
        stopWatchdog()
        let physical = physicalFlags
        var flags = physical | configuration.hyperFlags
        for modifier in configuration.modifiers.reversed() {
            flags &= ~modifier.flags
            postModifier(modifier.keyCode, flags: flags | physical)
        }
        if fire { performQuickPress() }
    }

    private func performQuickPress() {
        let key = configuration.quickPressKey
        if key == Keys.capsLock {
            CapsLock.isOn.toggle()
            return
        }
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: down) else { continue }
            event.flags = CGEventFlags(rawValue: physicalFlags)
            post(event)
        }
    }

    private func postModifier(_ keyCode: UInt16, flags: UInt64) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: flags)
        post(event)
    }

    private func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cgSessionEventTap)
    }

    /// The modifier keys physically held, which the hyper flags are combined with.
    private var physicalFlags: UInt64 {
        // Caps lock state, ⇧⌃⌥⌘, and their left/right device bits.
        let modifiers: UInt64 = 0x1F_0000 | 0x207F
        return CGEventSource.flagsState(.hidSystemState).rawValue & modifiers
    }

    // MARK: Watchdog

    /// Secure input (password fields) hides key events from event taps, so the release of the hyper
    /// key can be missed. While hyper is held, poll the key state, and release hyper once the key is
    /// up. The poll only acts after it has seen the key down once, so it can never cut a press short
    /// if the key state is not reported for the remapped key.
    private func startWatchdog() {
        sawTriggerDown = false
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if CGEventSource.keyState(.hidSystemState, key: Keys.trigger.keyCode) {
                sawTriggerDown = true
            } else if sawTriggerDown {
                release(quickPress: false)
            }
        }
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }
}

private var now: Double { ProcessInfo.processInfo.systemUptime }
