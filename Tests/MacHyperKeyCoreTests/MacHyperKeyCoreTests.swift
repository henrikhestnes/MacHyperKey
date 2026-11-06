import XCTest
import MacHyperKeyCore

final class HyperSessionTests: XCTestCase {
    func testQuickPressFires() {
        var session = HyperSession(quickPressWindow: 0.5)
        XCTAssertTrue(session.press(at: 10))
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.release(at: 10.2))
        XCTAssertFalse(session.isActive)
    }

    func testRepeatsAreIgnored() {
        var session = HyperSession()
        XCTAssertTrue(session.press(at: 0))
        XCTAssertFalse(session.press(at: 0.1))
        XCTAssertTrue(session.release(at: 0.2))
    }

    func testOtherInputCancelsQuickPress() {
        var session = HyperSession()
        _ = session.press(at: 0)
        session.interrupt()
        XCTAssertFalse(session.release(at: 0.1))
        _ = session.press(at: 1)
        XCTAssertTrue(session.release(at: 1.1), "An interruption only affects its own press")
    }

    func testLongPressDoesNotFire() {
        var session = HyperSession(quickPressWindow: 0.5)
        _ = session.press(at: 0)
        XCTAssertFalse(session.release(at: 0.8))
    }

    func testReleaseWithoutPress() {
        var session = HyperSession()
        XCTAssertFalse(session.release(at: 1))
        session.interrupt()
        _ = session.press(at: 2)
        XCTAssertTrue(session.release(at: 2.1))
    }

    func testReset() {
        var session = HyperSession()
        _ = session.press(at: 0)
        session.reset()
        XCTAssertFalse(session.isActive)
        XCTAssertFalse(session.release(at: 0.1))
    }
}

final class HyperConfigurationTests: XCTestCase {
    func testDefaultMapsCapsLockToTrigger() {
        let configuration = HyperConfiguration()
        XCTAssertEqual(configuration.mappings, [KeyMapping(source: 0x7_0000_0039, destination: 0x7_0000_006F)])
        XCTAssertTrue(configuration.capsLockKeyRemapped)
        XCTAssertFalse(configuration.capsLockRemapAvailable)
    }

    func testHyperFlagsMatchHyperkey() {
        var configuration = HyperConfiguration()
        // Hyperkey stores ⌃⌥⌘ as 1835008 (0x1C0000); the device bits mark them as the left-hand keys.
        XCTAssertEqual(configuration.hyperFlags & 0xFF_0000, 1_835_008)
        XCTAssertEqual(configuration.modifiers.map(\.keyCode), [0x3B, 0x3A, 0x37])
        configuration.includeShift = true
        XCTAssertEqual(configuration.hyperFlags & 0xFF_0000, 0x1E_0000)
        XCTAssertEqual(configuration.modifiers.last?.keyCode, 0x38)
    }

    func testCapsLockRemapIgnoredWhileCapsLockIsHyper() {
        var configuration = HyperConfiguration()
        configuration.capsLockRemapEnabled = true
        XCTAssertEqual(configuration.mappings.count, 1)
    }

    func testCapsLockRemapWithOtherHyperKey() {
        var configuration = HyperConfiguration()
        configuration.physicalKey = Keys.rightCommand
        configuration.capsLockRemapEnabled = true
        configuration.capsLockTarget = Keys.escape
        XCTAssertEqual(configuration.mappings, [
            KeyMapping(source: 0x7_0000_00E7, destination: 0x7_0000_006F),
            KeyMapping(source: 0x7_0000_0039, destination: 0x7_0000_0029)
        ])
    }

    func testCapsLockRemapWithHyperOff() {
        var configuration = HyperConfiguration()
        configuration.remapEnabled = false
        XCTAssertTrue(configuration.capsLockRemapAvailable)
        XCTAssertFalse(configuration.quickPressAvailable)
        XCTAssertEqual(configuration.mappings, [])
        configuration.capsLockRemapEnabled = true
        XCTAssertEqual(configuration.mappings, [KeyMapping(source: 0x7_0000_0039, destination: 0x7_0000_0029)])
    }

    func testChoicesDoNotIncludeTrigger() {
        for keys in [Keys.physicalChoices, Keys.capsLockTargets, Keys.quickPressTargets] {
            XCTAssertFalse(keys.contains(Keys.trigger))
            XCTAssertEqual(Set(keys.map(\.usage)).count, keys.count, "Usages are used as popup tags and must be unique")
        }
    }
}

final class KeyMappingTests: XCTestCase {
    private let a = KeyMapping(source: 1, destination: 2)
    private let b = KeyMapping(source: 3, destination: 4)
    private let ours = KeyMapping(source: 5, destination: 6)

    func testKeepsOtherMappings() {
        XCTAssertEqual(KeyMapping.merge(existing: [a, b], previouslyApplied: [], desired: [ours]), [a, b, ours])
    }

    func testReplacesPreviousMappings() {
        let new = KeyMapping(source: 5, destination: 7)
        XCTAssertEqual(KeyMapping.merge(existing: [a, ours], previouslyApplied: [ours], desired: [new]), [a, new])
    }

    func testRemovesAll() {
        XCTAssertEqual(KeyMapping.merge(existing: [a, ours], previouslyApplied: [ours], desired: []), [a])
    }

    func testOverridesConflictingSource() {
        let conflicting = KeyMapping(source: 5, destination: 9)
        XCTAssertEqual(KeyMapping.merge(existing: [conflicting, b], previouslyApplied: [], desired: [ours]), [b, ours])
    }
}
