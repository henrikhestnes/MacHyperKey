/// One `UserKeyMapping` entry: HID usage `source` produces `destination`.
public struct KeyMapping: Hashable, Sendable {
    public var source: UInt64
    public var destination: UInt64

    public init(source: UInt64, destination: UInt64) {
        self.source = source
        self.destination = destination
    }

    /// Replaces the mappings this app applied before with `desired`, keeping everyone else's,
    /// except ones for a key this app now remaps.
    public static func merge(existing: [KeyMapping], previouslyApplied: [KeyMapping], desired: [KeyMapping]) -> [KeyMapping] {
        let previous = Set(previouslyApplied)
        let sources = Set(desired.map(\.source))
        return existing.filter { !previous.contains($0) && !sources.contains($0.source) } + desired
    }
}

public enum MouseAction: String, CaseIterable, Sendable {
    case click, drag, move, scroll
}

/// Modifier flag bits as Quartz (`CGEventFlags`) and AppKit use them.
public enum ModifierFlags {
    public static let shift: UInt64 = 0x20000
    public static let control: UInt64 = 0x40000
    public static let option: UInt64 = 0x80000
    public static let command: UInt64 = 0x100000
    // Device-dependent bits for the left-hand keys, which real key events also carry.
    public static let leftControl: UInt64 = 0x1
    public static let leftShift: UInt64 = 0x2
    public static let leftCommand: UInt64 = 0x8
    public static let leftOption: UInt64 = 0x20
}

/// Everything that decides how the hyper key behaves, independent of AppKit.
public struct HyperConfiguration: Equatable, Sendable {
    public var remapEnabled = true
    public var physicalKey = Keys.capsLock
    public var capsLockRemapEnabled = false
    public var capsLockTarget = Keys.escape
    public var quickPressEnabled = false
    public var quickPressKey = Keys.capsLock
    public var includeShift = false
    public var mouseActions: Set<MouseAction> = [.click, .scroll]

    public init() {}

    public var hyperActive: Bool { remapEnabled }

    /// Caps lock can be remapped separately only when it is not already the hyper key.
    public var capsLockRemapAvailable: Bool { !(remapEnabled && physicalKey == Keys.capsLock) }

    public var quickPressAvailable: Bool { remapEnabled }

    /// The modifier keys hyper presses, in order, with the flags each adds.
    public var modifiers: [(keyCode: UInt16, flags: UInt64)] {
        var keys: [(UInt16, UInt64)] = [
            (Keys.leftControl.keyCode, ModifierFlags.control | ModifierFlags.leftControl),
            (Keys.leftOption.keyCode, ModifierFlags.option | ModifierFlags.leftOption),
            (Keys.leftCommand.keyCode, ModifierFlags.command | ModifierFlags.leftCommand)
        ]
        if includeShift { keys.append((Keys.leftShift.keyCode, ModifierFlags.shift | ModifierFlags.leftShift)) }
        return keys
    }

    /// All flags hyper adds to an event.
    public var hyperFlags: UInt64 { modifiers.reduce(0) { $0 | $1.flags } }

    /// The HID mappings to install.
    public var mappings: [KeyMapping] {
        var result: [KeyMapping] = []
        if remapEnabled {
            result.append(KeyMapping(source: physicalKey.mappingUsage, destination: Keys.trigger.mappingUsage))
        }
        if capsLockRemapAvailable && capsLockRemapEnabled && capsLockTarget != Keys.capsLock {
            result.append(KeyMapping(source: Keys.capsLock.mappingUsage, destination: capsLockTarget.mappingUsage))
        }
        return result
    }

    /// Whether caps lock can no longer be turned on or off from the keyboard.
    public var capsLockKeyRemapped: Bool {
        mappings.contains { $0.source == Keys.capsLock.mappingUsage }
    }
}
