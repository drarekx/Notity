import AppKit
import ServiceManagement

/// User preferences, persisted in UserDefaults (`com.egluu.notity`).
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// Colour theme of the whole app.
    @Published var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    @Published var hasLaunched: Bool { didSet { defaults.set(hasLaunched, forKey: "hasLaunched") } }
    /// Copying the same text twice in a row saves it as a note.
    @Published var doubleCopy: Bool { didSet { defaults.set(doubleCopy, forKey: "doubleCopy") } }
    /// Maximum time between the two copies, in seconds.
    @Published var doubleCopyWindow: Double { didSet { defaults.set(doubleCopyWindow, forKey: "doubleCopyWindow") } }
    /// Days a note is kept before it goes to the trash. 0 = never.
    @Published var expiryDays: Int { didSet { defaults.set(expiryDays, forKey: "expiryDays") } }
    /// Global shortcut that opens the quick panel.
    @Published var shortcut: Shortcut { didSet { defaults.set(shortcut.rawValue, forKey: "shortcut") } }

    private init() {
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .original
        hasLaunched = defaults.bool(forKey: "hasLaunched")
        doubleCopy = defaults.object(forKey: "doubleCopy") as? Bool ?? true
        doubleCopyWindow = defaults.object(forKey: "doubleCopyWindow") as? Double ?? 0.5
        expiryDays = defaults.object(forKey: "expiryDays") as? Int ?? 7
        shortcut = Shortcut(rawValue: defaults.string(forKey: "shortcut") ?? "") ?? .controlOptionV
    }
}

/// "Open at login" through SMAppService.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message, or nil.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Turned on once, the first time an installed copy (Applications) opens, so the app is there
    /// after a restart. Never from a build folder: it would register the development copy.
    /// Turning it off in Settings is respected. `-unregisterLoginItem YES` removes it (development).
    static func enableOnceFromApplications() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "unregisterLoginItem") {
            try? SMAppService.mainApp.unregister()
            return
        }
        let key = "launchAtLoginDefaultApplied"
        let path = Bundle.main.bundleURL.path
        let installed = path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard Bundle.main.bundleIdentifier != nil, installed, !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        if !isEnabled { setEnabled(true) }
    }
}
