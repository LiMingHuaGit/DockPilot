import AppKit

/// Polls the global cursor position and reports when it has *settled* on a
/// display other than the current main one.
///
/// Polling `NSEvent.mouseLocation` needs no Accessibility permission, unlike a
/// global event monitor. A debounce avoids thrashing the display config while
/// the cursor is merely passing across a screen edge.
@MainActor
final class CursorMonitor {

    var debounce: TimeInterval = 0.4
    /// Called (on the main actor) when the cursor has rested on a non-main display.
    var onSettled: ((CGDirectDisplayID) -> Void)?

    private var timer: Timer?
    private var candidate: CGDirectDisplayID?
    private var candidateSince: Date?
    private var tickCount = 0

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.05
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        candidate = nil
        candidateSince = nil
    }

    private func tick() {
        tickCount += 1
        if tickCount == 1 || tickCount % 50 == 0 { Log.write("tick #\(tickCount)") }
        let loc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(loc, $0.frame, false) }),
              let id = screen.displayID
        else { return }

        // Already on the main display — nothing to do, reset any pending candidate.
        guard id != CGMainDisplayID() else {
            candidate = nil
            candidateSince = nil
            return
        }

        if candidate == id, let since = candidateSince {
            if Date().timeIntervalSince(since) >= debounce {
                candidate = nil
                candidateSince = nil
                onSettled?(id)
            }
        } else {
            candidate = id
            candidateSince = Date()
        }
    }
}
