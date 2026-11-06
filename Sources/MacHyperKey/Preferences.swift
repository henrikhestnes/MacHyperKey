import Foundation
import MacHyperKeyCore

enum Preferences {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            "remapEnabled": true,
            "physicalKey": Int(Keys.capsLock.usage),
            "capsLockRemapEnabled": false,
            "capsLockTarget": Int(Keys.escape.usage),
            "quickPressEnabled": false,
            "quickPressKey": Int(Keys.capsLock.usage),
            "includeShift": false,
            "mouseActions": [MouseAction.click.rawValue, MouseAction.scroll.rawValue],
            "hideMenuBarIcon": false
        ])
    }

    static var configuration: HyperConfiguration {
        get {
            var configuration = HyperConfiguration()
            configuration.remapEnabled = defaults.bool(forKey: "remapEnabled")
            configuration.physicalKey = key("physicalKey", in: Keys.physicalChoices) ?? Keys.capsLock
            configuration.capsLockRemapEnabled = defaults.bool(forKey: "capsLockRemapEnabled")
            configuration.capsLockTarget = key("capsLockTarget", in: Keys.capsLockTargets) ?? Keys.escape
            configuration.quickPressEnabled = defaults.bool(forKey: "quickPressEnabled")
            configuration.quickPressKey = key("quickPressKey", in: Keys.quickPressTargets) ?? Keys.capsLock
            configuration.includeShift = defaults.bool(forKey: "includeShift")
            let actions = defaults.stringArray(forKey: "mouseActions") ?? []
            configuration.mouseActions = Set(actions.compactMap(MouseAction.init(rawValue:)))
            return configuration
        }
        set {
            defaults.set(newValue.remapEnabled, forKey: "remapEnabled")
            defaults.set(Int(newValue.physicalKey.usage), forKey: "physicalKey")
            defaults.set(newValue.capsLockRemapEnabled, forKey: "capsLockRemapEnabled")
            defaults.set(Int(newValue.capsLockTarget.usage), forKey: "capsLockTarget")
            defaults.set(newValue.quickPressEnabled, forKey: "quickPressEnabled")
            defaults.set(Int(newValue.quickPressKey.usage), forKey: "quickPressKey")
            defaults.set(newValue.includeShift, forKey: "includeShift")
            defaults.set(MouseAction.allCases.filter(newValue.mouseActions.contains).map(\.rawValue), forKey: "mouseActions")
        }
    }

    static var hideMenuBarIcon: Bool {
        get { defaults.bool(forKey: "hideMenuBarIcon") }
        set { defaults.set(newValue, forKey: "hideMenuBarIcon") }
    }

    /// The mappings this app installed last, so they can be removed even after a crash.
    static var appliedMappings: [KeyMapping] {
        get {
            let pairs = defaults.array(forKey: "appliedMappings") as? [[NSNumber]] ?? []
            return pairs.compactMap { $0.count == 2 ? KeyMapping(source: $0[0].uint64Value, destination: $0[1].uint64Value) : nil }
        }
        set {
            defaults.set(newValue.map { [NSNumber(value: $0.source), NSNumber(value: $0.destination)] }, forKey: "appliedMappings")
        }
    }

    private static func key(_ name: String, in keys: [Key]) -> Key? {
        Keys.key(usage: UInt32(truncatingIfNeeded: defaults.integer(forKey: name)), in: keys)
    }
}
