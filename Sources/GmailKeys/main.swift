import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let remapper = KeyRemapper()
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var permissionTimer: Timer?

    private static let enabledKey = "enabled"

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
        remapper.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)

        buildStatusItem()
        startRemapper(prompt: true)
    }

    // MARK: - Accessibility permission

    private func startRemapper(prompt: Bool) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), remapper.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
        } else if permissionTimer == nil {
            // Poll until the user grants access in System Settings.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.startRemapper(prompt: false)
            }
        }
        refreshMenu()
    }

    // MARK: - Menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "envelope.badge", accessibilityDescription: "Gmail Keys"
        )

        let menu = NSMenu()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: "Gmail Keys for Apple Mail", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        permissionItem = NSMenuItem(
            title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)

        let shortcutsItem = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
        shortcutsItem.submenu = shortcutsMenu()
        menu.addItem(shortcutsItem)

        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func shortcutsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        for mapping in Mappings.all {
            let keys = mapping.gmail.map(String.init).joined(separator: " then ")
            let text = "\(keys.padding(toLength: 10, withPad: " ", startingAt: 0)) \(mapping.mail.label.padding(toLength: 5, withPad: " ", startingAt: 0))  \(mapping.action)"
            let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
            item.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
            item.isEnabled = false
            menu.addItem(item)
        }
        return menu
    }

    private func refreshMenu() {
        let trusted = remapper.isRunning
        permissionItem.isHidden = trusted
        enabledItem.isEnabled = trusted
        enabledItem.state = remapper.isEnabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let symbol = trusted && remapper.isEnabled ? "envelope.badge" : "envelope"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Gmail Keys")
        statusItem.button?.appearsDisabled = !(trusted && remapper.isEnabled)
    }

    @objc private func toggleEnabled() {
        remapper.isEnabled.toggle()
        UserDefaults.standard.set(remapper.isEnabled, forKey: Self.enabledKey)
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Launch at Login"
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // background app: no Dock icon, menu bar only
app.run()
