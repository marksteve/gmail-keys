import AppKit
import ApplicationServices
import CoreGraphics

/// Intercepts key presses while Apple Mail is frontmost and translates
/// Gmail-style single-key shortcuts into Apple Mail shortcuts.
final class KeyRemapper {
    static let mailBundleID = "com.apple.mail"

    /// Tags events we synthesize so the tap lets them through untouched.
    private static let syntheticMarker: Int64 = 0x474D_4B59 // "GMKY"

    /// How long to wait for the second key of a sequence like "g i".
    private static let sequenceTimeout: TimeInterval = 1.5

    var isEnabled = true

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mailPID: pid_t?
    private var pendingPrefix: (key: String, time: Date)?
    /// Key codes whose key-down we swallowed, so we swallow the matching key-up too.
    private var swallowedKeyCodes = Set<Int64>()

    init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(frontAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        updateFrontApp(NSWorkspace.shared.frontmostApplication)
    }

    var isRunning: Bool { eventTap != nil }

    /// Installs the event tap. Returns false if Accessibility access is missing.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let remapper = Unmanaged<KeyRemapper>.fromOpaque(refcon).takeUnretainedValue()
            return remapper.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    // MARK: - Front app tracking

    @objc private func frontAppChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateFrontApp(app)
    }

    private func updateFrontApp(_ app: NSRunningApplication?) {
        mailPID = app?.bundleIdentifier == Self.mailBundleID ? app?.processIdentifier : nil
        pendingPrefix = nil
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        // The system disables taps that are slow or interrupted; turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return pass
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return pass
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyUp {
            return swallowedKeyCodes.remove(keyCode) != nil ? nil : pass
        }

        guard type == .keyDown, isEnabled, let pid = mailPID else { return pass }

        // Leave real shortcuts (⌘, ⌃, ⌥) alone; Shift is allowed (#, !, U, ...).
        if !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            pendingPrefix = nil
            return pass
        }

        guard let chars = characters(of: event), !chars.isEmpty else { return pass }

        // Resolve a pending sequence prefix ("g" then "i").
        var lookup = chars
        if let prefix = pendingPrefix {
            pendingPrefix = nil
            if Date().timeIntervalSince(prefix.time) < Self.sequenceTimeout {
                lookup = prefix.key + chars
                if Mappings.byKeys[lookup] == nil { lookup = chars }
            }
        }

        let mapping = Mappings.byKeys[lookup]
        let isPrefix = mapping == nil && Mappings.prefixes.contains(lookup)
        guard mapping != nil || isPrefix else { return pass }

        // Only check focus (an IPC round-trip) for keys we might remap.
        if isTypingText(in: pid) { return pass }

        swallowedKeyCodes.insert(keyCode)
        if let mapping {
            post(mapping.mail)
        } else {
            pendingPrefix = (lookup, Date())
        }
        return nil
    }

    private func characters(of event: CGEvent) -> String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer
        )
        return length > 0 ? String(utf16CodeUnits: buffer, count: length) : nil
    }

    private func post(_ shortcut: Shortcut) {
        // A private source keeps physically held keys (e.g. Shift for "#") out of the result.
        let source = CGEventSource(stateID: .privateState)
        for isDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: isDown
            ) else { continue }
            event.flags = shortcut.flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Text field detection

    private static let textRoles: Set<String> = [
        kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField",
    ]

    /// True when the focused element in Mail accepts text (compose body,
    /// To/Subject fields, search field), so keys must be typed normally.
    private func isTypingText(in pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            app, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return false
        }
        let element = focused as! AXUIElement

        if let role = stringAttribute(element, kAXRoleAttribute), Self.textRoles.contains(role) {
            return true
        }
        if let subrole = stringAttribute(element, kAXSubroleAttribute), subrole == kAXSearchFieldSubrole {
            return true
        }

        // WebKit-based editors (the compose body) expose an editable ancestor.
        var editable: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXEditableAncestor" as CFString, &editable) == .success,
           editable != nil {
            return true
        }
        return false
    }

    private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
