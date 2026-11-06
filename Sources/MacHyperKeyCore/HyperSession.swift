/// Tracks one press of the hyper key and decides whether its release was a quick press:
/// released within `quickPressWindow` without any other key, click or scroll in between.
public struct HyperSession: Sendable {
    public var quickPressWindow: Double

    public private(set) var isActive = false
    private var pressedAt = 0.0
    private var interrupted = false

    public init(quickPressWindow: Double = 0.5) {
        self.quickPressWindow = quickPressWindow
    }

    /// Returns true when the hyper key went down, false for key repeats.
    public mutating func press(at time: Double) -> Bool {
        guard !isActive else { return false }
        isActive = true
        pressedAt = time
        interrupted = false
        return true
    }

    /// Something else happened while hyper was held, so its release is not a quick press.
    public mutating func interrupt() {
        if isActive { interrupted = true }
    }

    /// Returns true when the release completes a quick press.
    public mutating func release(at time: Double) -> Bool {
        guard isActive else { return false }
        isActive = false
        return !interrupted && time - pressedAt <= quickPressWindow
    }

    /// Ends the press without a quick press, for example when the Mac goes to sleep.
    public mutating func reset() {
        isActive = false
        interrupted = false
    }
}
