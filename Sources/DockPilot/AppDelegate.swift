import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let settings = Settings()
    private let monitor = CursorMonitor()
    private var statusItem: NSStatusItem!

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        monitor.onSettled = { [weak self] displayID in
            guard self?.settings.mode == .auto else { return }
            DisplayManager.setMainDisplay(displayID)
            // Menu rebuilds lazily on open, so no eager refresh needed.
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        applyCurrentMode()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: Status item + menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockPilot")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "DockPilot"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Rebuild the menu each time it opens so it reflects live display state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabledTitle("DockPilot"))
        menu.addItem(.separator())

        // Mode selector.
        menu.addItem(sectionHeader("模式"))
        let autoItem = NSMenuItem(title: "自动跟随光标", action: #selector(selectAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = settings.mode == .auto ? .on : .off
        menu.addItem(autoItem)

        let manualItem = NSMenuItem(title: "固定到指定屏幕", action: #selector(selectManual), keyEquivalent: "")
        manualItem.target = self
        manualItem.state = settings.mode == .manual ? .on : .off
        menu.addItem(manualItem)

        menu.addItem(.separator())

        // Display list.
        menu.addItem(sectionHeader(settings.mode == .manual ? "固定到" : "当前主屏幕"))
        let displays = DisplayManager.activeDisplays()
        if displays.count < 2 {
            menu.addItem(disabledTitle("仅检测到一块屏幕"))
        }
        for d in displays {
            let marker: String
            if settings.mode == .manual {
                marker = (d.uuid == settings.pinnedDisplayUUID) ? "📌 " : ""
            } else {
                marker = ""
            }
            let item = NSMenuItem(title: marker + d.name, action: #selector(selectDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = d.uuid
            item.state = d.isMain ? .on : .off
            menu.addItem(item)
        }

        // Debounce (auto mode only).
        if settings.mode == .auto {
            menu.addItem(.separator())
            menu.addItem(sectionHeader("切换延迟"))
            let debounceMenu = NSMenu()
            for seconds in [0.2, 0.4, 0.8, 1.2] {
                let item = NSMenuItem(title: label(forDebounce: seconds), action: #selector(setDebounce(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = NSNumber(value: seconds)
                item.state = abs(settings.debounceSeconds - seconds) < 0.001 ? .on : .off
                debounceMenu.addItem(item)
            }
            let debounceParent = NSMenuItem(title: "切换延迟 (\(label(forDebounce: settings.debounceSeconds)))", action: nil, keyEquivalent: "")
            debounceParent.submenu = debounceMenu
            menu.addItem(debounceParent)
        }

        menu.addItem(.separator())

        let login = NSMenuItem(title: "开机启动", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = isLoginItemEnabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "退出 DockPilot", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: Actions

    @objc private func selectAuto() {
        settings.mode = .auto
        applyCurrentMode()
    }

    @objc private func selectManual() {
        settings.mode = .manual
        // If nothing pinned yet, adopt the current main display as the pin.
        if settings.pinnedDisplayUUID == nil {
            settings.pinnedDisplayUUID = DisplayManager.uuid(for: DisplayManager.mainDisplayID)
        }
        applyCurrentMode()
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String,
              let id = DisplayManager.displayID(forUUID: uuid) else { return }
        if settings.mode == .manual {
            settings.pinnedDisplayUUID = uuid
        }
        DisplayManager.setMainDisplay(id)
    }

    @objc private func setDebounce(_ sender: NSMenuItem) {
        guard let value = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        settings.debounceSeconds = value
        monitor.debounce = value
    }

    @objc private func screensChanged() {
        // Re-assert a manual pin when displays are connected/disconnected/rearranged.
        if settings.mode == .manual { applyManualPin() }
    }

    @objc private func toggleLoginItem() {
        setLoginItem(enabled: !isLoginItemEnabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Mode application

    private func applyCurrentMode() {
        switch settings.mode {
        case .auto:
            monitor.debounce = settings.debounceSeconds
            monitor.start()
        case .manual:
            monitor.stop()
            applyManualPin()
        }
    }

    private func applyManualPin() {
        guard let uuid = settings.pinnedDisplayUUID,
              let id = DisplayManager.displayID(forUUID: uuid) else { return }
        DisplayManager.setMainDisplay(id)
    }

    // MARK: Login item

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            presentError("无法更新开机启动设置：\(error.localizedDescription)\n\n（需要以已签名的 .app 形式运行。）")
        }
    }

    // MARK: Menu helpers

    private func disabledTitle(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        item.isEnabled = false
        return item
    }

    private func label(forDebounce seconds: TimeInterval) -> String {
        String(format: "%.1f 秒", seconds)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "DockPilot"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
