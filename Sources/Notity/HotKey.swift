import AppKit
import Carbon.HIToolbox

/// Shortcuts offered in Settings to open the quick panel.
enum Shortcut: String, CaseIterable, Identifiable {
    case controlOptionV, controlOptionN, controlShiftV, none
    var id: String { rawValue }

    var label: String {
        switch self {
        case .controlOptionV: return "⌃⌥V"
        case .controlOptionN: return "⌃⌥N"
        case .controlShiftV: return "⌃⇧V"
        case .none: return tr("Sin atajo")
        }
    }

    /// Carbon key code and modifiers.
    var carbon: (key: UInt32, modifiers: UInt32)? {
        switch self {
        case .controlOptionV: return (UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey))
        case .controlOptionN: return (UInt32(kVK_ANSI_N), UInt32(controlKey | optionKey))
        case .controlShiftV: return (UInt32(kVK_ANSI_V), UInt32(controlKey | shiftKey))
        case .none: return nil
        }
    }
}

/// One global shortcut through Carbon `RegisterEventHotKey` (no Accessibility permission needed).
@MainActor
final class HotKey {
    static let shared = HotKey()

    var handler: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    func register(_ shortcut: Shortcut) {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        guard let carbon = shortcut.carbon else { return }
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { HotKey.shared.handler?() } }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = EventHotKeyID(signature: OSType(0x4E54_4659), id: 1) // "NTFY"
        RegisterEventHotKey(carbon.key, carbon.modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }
}
