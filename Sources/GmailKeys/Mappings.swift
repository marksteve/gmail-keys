import Carbon.HIToolbox
import CoreGraphics

/// An Apple Mail keyboard shortcut to synthesize.
struct Shortcut {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let label: String

    static func cmd(_ key: Int, _ label: String) -> Shortcut {
        Shortcut(keyCode: CGKeyCode(key), flags: .maskCommand, label: label)
    }

    static func shiftCmd(_ key: Int, _ label: String) -> Shortcut {
        Shortcut(keyCode: CGKeyCode(key), flags: [.maskShift, .maskCommand], label: label)
    }

    static func ctrlCmd(_ key: Int, _ label: String) -> Shortcut {
        Shortcut(keyCode: CGKeyCode(key), flags: [.maskControl, .maskCommand], label: label)
    }

    static func optCmd(_ key: Int, _ label: String) -> Shortcut {
        Shortcut(keyCode: CGKeyCode(key), flags: [.maskAlternate, .maskCommand], label: label)
    }

    static func plain(_ key: Int, _ label: String) -> Shortcut {
        Shortcut(keyCode: CGKeyCode(key), flags: [], label: label)
    }
}

/// A Gmail shortcut (typed characters) mapped to an Apple Mail shortcut.
struct Mapping {
    /// Characters as typed, e.g. "j", "#", "U", or a two-key sequence like "gi".
    let gmail: String
    let action: String
    let mail: Shortcut
}

enum Mappings {
    static let all: [Mapping] = [
        // Navigation
        Mapping(gmail: "j", action: "Next message", mail: .plain(kVK_DownArrow, "↓")),
        Mapping(gmail: "k", action: "Previous message", mail: .plain(kVK_UpArrow, "↑")),
        Mapping(gmail: "o", action: "Open message", mail: .cmd(kVK_ANSI_O, "⌘O")),
        Mapping(gmail: "/", action: "Search", mail: .optCmd(kVK_ANSI_F, "⌥⌘F")),
        Mapping(gmail: "gi", action: "Go to Inbox", mail: .cmd(kVK_ANSI_1, "⌘1")),

        // Composing
        Mapping(gmail: "c", action: "Compose", mail: .cmd(kVK_ANSI_N, "⌘N")),
        Mapping(gmail: "r", action: "Reply", mail: .cmd(kVK_ANSI_R, "⌘R")),
        Mapping(gmail: "a", action: "Reply all", mail: .shiftCmd(kVK_ANSI_R, "⇧⌘R")),
        Mapping(gmail: "f", action: "Forward", mail: .shiftCmd(kVK_ANSI_F, "⇧⌘F")),

        // Actions
        Mapping(gmail: "e", action: "Archive", mail: .ctrlCmd(kVK_ANSI_A, "⌃⌘A")),
        Mapping(gmail: "y", action: "Archive", mail: .ctrlCmd(kVK_ANSI_A, "⌃⌘A")),
        Mapping(gmail: "#", action: "Delete", mail: .cmd(kVK_Delete, "⌘⌫")),
        Mapping(gmail: "!", action: "Mark as junk", mail: .shiftCmd(kVK_ANSI_J, "⇧⌘J")),
        Mapping(gmail: "s", action: "Flag / unflag", mail: .shiftCmd(kVK_ANSI_L, "⇧⌘L")),
        Mapping(gmail: "U", action: "Mark read / unread", mail: .shiftCmd(kVK_ANSI_U, "⇧⌘U")),
        Mapping(gmail: "I", action: "Mark read / unread", mail: .shiftCmd(kVK_ANSI_U, "⇧⌘U")),
        Mapping(gmail: "z", action: "Undo", mail: .cmd(kVK_ANSI_Z, "⌘Z")),
        Mapping(gmail: "*a", action: "Select all", mail: .cmd(kVK_ANSI_A, "⌘A")),
    ]

    static let byKeys: [String: Mapping] = Dictionary(
        all.map { ($0.gmail, $0) }, uniquingKeysWith: { first, _ in first }
    )

    /// First characters of multi-key sequences ("g", "*").
    static let prefixes: Set<String> = Set(
        all.filter { $0.gmail.count > 1 }.map { String($0.gmail.prefix(1)) }
    )
}
