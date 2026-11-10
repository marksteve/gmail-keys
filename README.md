# Gmail Keys

A small background macOS app that lets you use Gmail keyboard shortcuts in Apple Mail.
It lives in the menu bar (no Dock icon) and only acts while Mail is the frontmost app.
When you're typing (compose window, To/Subject fields, search), keys pass through untouched.

## Build & run

```bash
./build.sh            # builds build/Gmail Keys.app
./build.sh --install  # also copies it to /Applications
```

On first launch macOS asks for **Accessibility** access (System Settings → Privacy & Security →
Accessibility). The app needs it to read and send key presses. It starts working as soon as you allow it.

The app is ad-hoc signed, so after a rebuild macOS may treat it as a new app. If shortcuts stop
working, remove "Gmail Keys" from the Accessibility list and add it again.

## Shortcuts

| Gmail | Apple Mail | Action |
|-------|-----------|--------|
| `j` / `k` | ↓ / ↑ | Next / previous message |
| `o` | ⌘O | Open message |
| `/` | ⌥⌘F | Search |
| `g` `i` | ⌘1 | Go to Inbox |
| `c` | ⌘N | Compose |
| `r` | ⌘R | Reply |
| `a` | ⇧⌘R | Reply all |
| `f` | ⇧⌘F | Forward |
| `e` / `y` | ⌃⌘A | Archive |
| `#` | ⌘⌫ | Delete |
| `!` | ⇧⌘J | Mark as junk |
| `s` | ⇧⌘L | Flag / unflag |
| `U` / `I` | ⇧⌘U | Mark read / unread |
| `z` | ⌘Z | Undo |
| `*` `a` | ⌘A | Select all |

Edit `Sources/GmailKeys/Mappings.swift` to add or change mappings.
