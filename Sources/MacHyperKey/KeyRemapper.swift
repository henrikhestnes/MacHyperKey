import Foundation
import IOKit
import IOKit.hidsystem
import MacHyperKeyCore

/// Installs HID key mappings, the same `UserKeyMapping` property `hidutil` sets. Mappings last until
/// the Mac restarts, so they are removed when the app quits.
enum KeyRemapper {
    private static let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
    private static let property = "UserKeyMapping" as CFString
    private static let sourceKey = "HIDKeyboardModifierMappingSrc"
    private static let destinationKey = "HIDKeyboardModifierMappingDst"

    /// Replaces this app's mappings with `desired`, leaving mappings made by others in place.
    @discardableResult
    static func apply(_ desired: [KeyMapping]) -> Bool {
        let merged = KeyMapping.merge(existing: current(), previouslyApplied: Preferences.appliedMappings, desired: desired)
        let value = merged.map { [sourceKey: NSNumber(value: $0.source), destinationKey: NSNumber(value: $0.destination)] }
        // hidutil does the same through Apple's own entitlements, in case the direct call is refused.
        guard IOHIDEventSystemClientSetProperty(client, property, value as CFArray) || hidutilSet(value) else {
            NSLog("MacHyperKey could not set UserKeyMapping")
            return false
        }
        Preferences.appliedMappings = desired
        return true
    }

    static func removeAll() {
        apply([])
    }

    private static func current() -> [KeyMapping] {
        if let entries = IOHIDEventSystemClientCopyProperty(client, property) as? [[String: Any]] {
            return entries.compactMap { entry in
                guard let source = entry[sourceKey] as? NSNumber, let destination = entry[destinationKey] as? NSNumber else { return nil }
                return KeyMapping(source: source.uint64Value, destination: destination.uint64Value)
            }
        }
        return hidutilGet()
    }

    // MARK: hidutil fallback

    private static func hidutil(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property"] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: output, as: UTF8.self)
    }

    private static func hidutilSet(_ value: [[String: NSNumber]]) -> Bool {
        guard let json = try? JSONSerialization.data(withJSONObject: [property as String: value]) else { return false }
        return hidutil(["--set", String(decoding: json, as: UTF8.self)]) != nil
    }

    /// Parses `hidutil property --get UserKeyMapping`, which prints an old-style plist.
    private static func hidutilGet() -> [KeyMapping] {
        guard let output = hidutil(["--get", property as String]),
              let entries = try? PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [[String: Any]]
        else { return [] }
        return entries.compactMap { entry in
            func number(_ key: String) -> UInt64? {
                (entry[key] as? NSNumber)?.uint64Value ?? (entry[key] as? String).flatMap { UInt64($0) }
            }
            guard let source = number(sourceKey), let destination = number(destinationKey) else { return nil }
            return KeyMapping(source: source, destination: destination)
        }
    }
}

/// Reads and sets the caps lock state, which keeps working when the caps lock key is remapped.
enum CapsLock {
    private static func withConnection<T>(_ body: (io_connect_t) -> T) -> T? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS else { return nil }
        defer { IOServiceClose(connection) }
        return body(connection)
    }

    static var isOn: Bool {
        get {
            withConnection { connection in
                var state = false
                return IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &state) == KERN_SUCCESS && state
            } ?? false
        }
        set {
            _ = withConnection { IOHIDSetModifierLockState($0, Int32(kIOHIDCapsLockState), newValue) }
        }
    }
}
