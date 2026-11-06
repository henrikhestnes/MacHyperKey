/// A key on the keyboard, known both by its HID usage (keyboard page 0x07), which is what key
/// remapping works with, and by its macOS virtual key code, which is what Quartz events carry.
public struct Key: Hashable, Sendable {
    public let name: String
    public let usage: UInt32
    public let keyCode: UInt16

    public init(_ name: String, usage: UInt32, keyCode: UInt16) {
        self.name = name
        self.usage = usage
        self.keyCode = keyCode
    }

    /// The 64-bit usage that `UserKeyMapping` expects: the usage page in the upper 32 bits.
    public var mappingUsage: UInt64 { 0x7_0000_0000 | UInt64(usage) }
}

public enum Keys {
    public static let capsLock = Key("caps lock", usage: 0x39, keyCode: 0x39)
    public static let escape = Key("esc", usage: 0x29, keyCode: 0x35)
    public static let tab = Key("tab", usage: 0x2B, keyCode: 0x30)
    public static let returnKey = Key("return", usage: 0x28, keyCode: 0x24)
    public static let delete = Key("delete", usage: 0x2A, keyCode: 0x33)
    public static let forwardDelete = Key("forward delete", usage: 0x4C, keyCode: 0x75)
    public static let space = Key("space", usage: 0x2C, keyCode: 0x31)
    public static let grave = Key("`", usage: 0x35, keyCode: 0x32)
    public static let section = Key("§", usage: 0x64, keyCode: 0x0A)
    public static let leftControl = Key("left control", usage: 0xE0, keyCode: 0x3B)
    public static let leftShift = Key("left shift", usage: 0xE1, keyCode: 0x38)
    public static let leftOption = Key("left option", usage: 0xE2, keyCode: 0x3A)
    public static let leftCommand = Key("left command", usage: 0xE3, keyCode: 0x37)
    public static let rightControl = Key("right control", usage: 0xE4, keyCode: 0x3E)
    public static let rightShift = Key("right shift", usage: 0xE5, keyCode: 0x3C)
    public static let rightOption = Key("right option", usage: 0xE6, keyCode: 0x3D)
    public static let rightCommand = Key("right command", usage: 0xE7, keyCode: 0x36)
    public static let functionKeys: [Key] = [
        Key("F13", usage: 0x68, keyCode: 0x69), Key("F14", usage: 0x69, keyCode: 0x6B),
        Key("F15", usage: 0x6A, keyCode: 0x71), Key("F16", usage: 0x6B, keyCode: 0x6A),
        Key("F17", usage: 0x6C, keyCode: 0x40), Key("F18", usage: 0x6D, keyCode: 0x4F),
        Key("F19", usage: 0x6E, keyCode: 0x50)
    ]

    /// The physical hyper key is remapped to F20, which almost no keyboard has, and the event tap
    /// turns F20 into the hyper modifiers. Remapping at the HID level is what stops caps lock from
    /// toggling (and removes its activation delay).
    public static let trigger = Key("F20", usage: 0x6F, keyCode: 0x5A)

    /// Keys that can become the hyper key.
    public static let physicalChoices: [Key] = [
        capsLock, leftControl, leftOption, leftCommand, leftShift,
        rightControl, rightOption, rightCommand, rightShift,
        tab, grave, section, escape
    ] + functionKeys

    /// What caps lock can become when it is not the hyper key.
    public static let capsLockTargets: [Key] = [
        escape, delete, forwardDelete, tab, returnKey,
        leftControl, leftOption, leftCommand, leftShift
    ] + functionKeys

    /// What a quick press of the hyper key can type. Caps lock toggles caps lock.
    public static let quickPressTargets: [Key] = [
        capsLock, escape, tab, returnKey, delete, forwardDelete, space
    ] + functionKeys

    public static func key(usage: UInt32, in keys: [Key]) -> Key? {
        keys.first { $0.usage == usage }
    }
}
