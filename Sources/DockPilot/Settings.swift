import Foundation

/// Operating mode chosen by the user.
enum Mode: String {
    case auto    // Dock follows the display under the cursor
    case manual  // Dock pinned to a chosen display
}

/// Persisted user settings (UserDefaults-backed).
@MainActor
final class Settings {
    private let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "mode"
        static let pinnedUUID = "pinnedDisplayUUID"
        static let debounce = "debounceSeconds"
    }

    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .auto }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    /// Stable UUID of the display pinned in manual mode (nil = none chosen yet).
    var pinnedDisplayUUID: String? {
        get { defaults.string(forKey: Key.pinnedUUID) }
        set { defaults.set(newValue, forKey: Key.pinnedUUID) }
    }

    /// How long (seconds) the cursor must rest on a new display before switching.
    var debounceSeconds: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.debounce)
            return v == 0 ? 0.4 : v
        }
        set { defaults.set(newValue, forKey: Key.debounce) }
    }
}
