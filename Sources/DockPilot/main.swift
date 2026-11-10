import AppKit

// Entry point. Runs as an accessory (menu-bar-only) app: no Dock icon, no main window.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // Retain the delegate for the lifetime of the process.
    objc_setAssociatedObject(app, "DockPilotDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
