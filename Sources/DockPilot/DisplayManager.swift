import AppKit

/// Describes one connected display in a stable, UI-friendly way.
struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID   // current (session-scoped) display id
    let uuid: String            // stable across reconnects / reboots
    let name: String            // localized, e.g. "Built-in Retina Display"
    let frame: CGRect           // Cocoa coordinates (origin bottom-left of main)
    let isMain: Bool
}

/// Thin wrapper over CoreGraphics / AppKit display APIs.
///
/// macOS exposes no public way to move *only* the Dock. The Dock (and the menu
/// bar) live on whichever display is the "main" display, so we move the Dock by
/// making the target display the main one via `CGConfigureDisplayOrigin`.
enum DisplayManager {

    // MARK: Enumeration

    static func activeDisplays() -> [DisplayInfo] {
        let main = CGMainDisplayID()
        return NSScreen.screens.compactMap { screen -> DisplayInfo? in
            guard let id = screen.displayID else { return nil }
            return DisplayInfo(
                id: id,
                uuid: uuid(for: id) ?? "\(id)",
                name: screen.localizedName,
                frame: screen.frame,
                isMain: id == main
            )
        }
    }

    static var mainDisplayID: CGDirectDisplayID { CGMainDisplayID() }

    // MARK: Stable identity (survives reconnects)

    static func uuid(for id: CGDirectDisplayID) -> String? {
        guard let ref = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, ref) as String?
    }

    /// Resolve a stored UUID back to the current session's display id (if connected).
    static func displayID(forUUID uuidString: String) -> CGDirectDisplayID? {
        for d in activeDisplays() where d.uuid == uuidString { return d.id }
        return nil
    }

    // MARK: The actual move

    /// Make `target` the main display. The menu bar and Dock follow it.
    /// Returns true if the main display is `target` afterwards (or already was).
    @discardableResult
    static func setMainDisplay(_ target: CGDirectDisplayID) -> Bool {
        guard CGMainDisplayID() != target else { return true }
        guard isActive(target) else { return false }

        // New origin of `target` must become (0,0); shift every display by the
        // same vector so the overall arrangement/geometry is preserved.
        let shift = CGDisplayBounds(target).origin

        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }

        for d in activeDisplayIDs() {
            let b = CGDisplayBounds(d)
            let x = Int32((b.origin.x - shift.x).rounded())
            let y = Int32((b.origin.y - shift.y).rounded())
            CGConfigureDisplayOrigin(config, d, x, y)
        }

        let result = CGCompleteDisplayConfiguration(config, .permanently)
        if result != .success {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGMainDisplayID() == target
    }

    // MARK: Helpers

    private static func activeDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    private static func isActive(_ id: CGDirectDisplayID) -> Bool {
        activeDisplayIDs().contains(id)
    }
}

extension NSScreen {
    /// The CoreGraphics display id backing this screen.
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value
    }
}
