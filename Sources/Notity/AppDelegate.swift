import AppKit
import Combine
import SwiftUI

/// App identity shared by the updater, menus and storage.
enum AppInfo {
    static let name = "Notity"
    /// GitHub repository the updater and installer read releases from.
    static let repo = "drarekx/Notity"
    static let buyMeACoffee = URL(string: "https://buymeacoffee.com/drarek")!
    /// Menu bar app (no Dock icon). `build-app.sh` sets LSUIElement to match (`MENU_BAR`).
    static let menuBarApp = true
    /// SF Symbol of the menu bar icon.
    static let statusSymbol = "note.text"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var flashWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        if AppInfo.menuBarApp { setupStatusItem() }
        Localizer.shared.$choice
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.setupMainMenu() }
            .store(in: &cancellables)
        // @Published fires in willSet: apply after the change.
        Settings.shared.$theme
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyTheme() }
            .store(in: &cancellables)
        _ = NoteStore.shared
        ClipboardWatcher.shared.onSaved = { [weak self] in
            self?.flashStatusIcon()
            SavedBubble.shared.show()
        }
        ClipboardWatcher.shared.start()
        HotKey.shared.handler = { QuickPanelController.shared.toggle() }
        Settings.shared.$shortcut
            .receive(on: RunLoop.main)
            .sink { HotKey.shared.register($0) }
            .store(in: &cancellables)
        Settings.shared.$expiryDays
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in NoteStore.shared.purge() }
            .store(in: &cancellables)
        LoginItem.enableOnceFromApplications()
        Updater.shared.start()
        installDebugHook()

        // Dock apps open their window; menu bar apps only the first time.
        if !AppInfo.menuBarApp || !Settings.shared.hasLaunched { showMainWindow() }
        Settings.shared.hasLaunched = true
    }

    /// Opening the app again (Finder, Spotlight, Dock) shows its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu bar item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: AppInfo.statusSymbol, accessibilityDescription: AppInfo.name)
        item.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// Rebuilt every time it opens, so state and language are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let search = ClosureMenuItem(title: tr("Buscar nota…")) { QuickPanelController.shared.show() }
        if let carbon = Settings.shared.shortcut.carbon, carbon.key == 9 || carbon.key == 45 {
            search.keyEquivalent = carbon.key == 9 ? "v" : "n"
            search.keyEquivalentModifierMask = Settings.shared.shortcut == .controlShiftV ? [.control, .shift] : [.control, .option]
        }
        menu.addItem(search)
        menu.addItem(ClosureMenuItem(title: tr("Abrir %@", AppInfo.name)) { [weak self] in self?.showMainWindow() })
        menu.addItem(.separator())
        let recent = NoteStore.shared.active.prefix(5)
        if recent.isEmpty {
            let empty = NSMenuItem(title: tr("Copia dos veces (⌘C ⌘C) para guardar"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let header = NSMenuItem(title: tr("Últimas notas"), action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for note in recent {
                let title = note.title.count > 48 ? String(note.title.prefix(47)) + "…" : note.title
                let item = ClosureMenuItem(title: title) { NoteStore.shared.copy(note) }
                item.image = NSImage(systemSymbolName: note.pinned ? "pin" : "text.alignleft", accessibilityDescription: nil)
                item.toolTip = String(note.text.prefix(400))
                menu.addItem(item)
            }
        }
        menu.addItem(ClosureMenuItem(title: tr("Guardar portapapeles ahora")) { ClipboardWatcher.shared.saveCurrent() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: tr("Ajustes…"), keyEquivalent: ",") { [weak self] in self?.showSettings() })
        menu.addItem(.separator())
        let updating = Updater.shared.state != .idle
        let update = ClosureMenuItem(title: updating ? tr("Actualizando…") : tr("Buscar actualizaciones…")) {
            Task { await Updater.shared.check(userInitiated: true) }
        }
        update.isEnabled = !updating
        menu.addItem(update)
        let coffee = ClosureMenuItem(title: tr("Invítame a un café…")) { NSWorkspace.shared.open(AppInfo.buyMeACoffee) }
        coffee.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)
        menu.addItem(coffee)
        let version = NSMenuItem(title: "\(AppInfo.name) \(Updater.currentVersion)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        menu.addItem(ClosureMenuItem(title: tr("Salir de %@", AppInfo.name), keyEquivalent: "q") { NSApp.terminate(nil) })
    }

    /// Brief checkmark in the menu bar when a note is saved.
    private func flashStatusIcon() {
        guard let button = statusItem?.button else { return }
        flashWork?.cancel()
        button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: tr("Nota guardada"))
        button.image?.isTemplate = true
        let work = DispatchWorkItem { [weak button] in
            button?.image = NSImage(systemSymbolName: AppInfo.statusSymbol, accessibilityDescription: AppInfo.name)
            button?.image?.isTemplate = true
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    // MARK: - Windows

    @objc func showMainWindow() {
        if mainWindow == nil {
            mainWindow = makeWindow(title: AppInfo.name, size: NSSize(width: 960, height: 640),
                                    minSize: NSSize(width: 720, height: 480), autosave: "MainWindow",
                                    root: ThemedRoot { MainView() })
            // The header sits next to the traffic lights.
            mainWindow?.titleVisibility = .hidden
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: tr("Ajustes de %@", AppInfo.name), size: NSSize(width: 620, height: 720),
                                        minSize: NSSize(width: 520, height: 480), autosave: "SettingsWindow",
                                        root: ThemedRoot { SettingsPane() })
        }
        settingsWindow?.title = tr("Ajustes de %@", AppInfo.name)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow<Content: View>(title: String, size: NSSize, minSize: NSSize, autosave: String,
                                           root: Content) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        window.titlebarAppearsTransparent = true
        let hosting = NSHostingController(rootView: root)
        // NSHostingController would otherwise shrink the window to its ideal size.
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(size)
        window.center()
        // After setContentSize: restores the last frame, if any, and saves it from now on.
        window.setFrameAutosaveName(autosave)
        style(window)
        return window
    }

    private func style(_ window: NSWindow) {
        window.appearance = NSAppearance(named: Theme.palette.isLight ? .aqua : .darkAqua)
        window.backgroundColor = Theme.nsWindow
    }

    private func applyTheme() {
        for window in [mainWindow, settingsWindow].compactMap({ $0 }) { style(window) }
        QuickPanelController.shared.applyTheme()
    }

    // MARK: - Main menu

    /// Dock apps show it; menu bar apps don't, but it still gives text fields ⌘C/⌘V/⌘A and windows ⌘W.
    private func setupMainMenu() {
        let main = NSMenu()
        let name = AppInfo.name

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("Acerca de %@", name),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("Ajustes…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: tr("Buscar actualizaciones…"), action: #selector(checkForUpdates), keyEquivalent: "").target = self
        let coffee = appMenu.addItem(withTitle: tr("Invítame a un café…"), action: #selector(openBuyMeACoffee), keyEquivalent: "")
        coffee.target = self
        coffee.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("Ocultar %@", name), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: tr("Ocultar otras"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: tr("Mostrar todo"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: tr("Salir de %@", name), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: tr("Edición"))
        edit.addItem(withTitle: tr("Deshacer"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: tr("Rehacer"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: tr("Cortar"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: tr("Copiar"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: tr("Pegar"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: tr("Seleccionar todo"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: tr("Ventana"))
        window.addItem(withTitle: tr("Cerrar ventana"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: tr("Minimizar"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(.separator())
        window.addItem(withTitle: name, action: #selector(showMainWindow), keyEquivalent: "0").target = self
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
    }

    @objc private func checkForUpdates() { Task { await Updater.shared.check(userInitiated: true) } }
    @objc private func openBuyMeACoffee() { NSWorkspace.shared.open(AppInfo.buyMeACoffee) }

    // MARK: - Debug hook

    /// Debug builds only: `DistributedNotificationCenter` `com.egluu.notity.debug` with an object
    /// string drives the app for screenshots and checks: `main`, `settings`, `theme:<id>`.
    private func installDebugHook() {
        #if DEBUG
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.egluu.notity.debug"),
                                                            object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                switch note.object as? String {
                case "main": self?.showMainWindow()
                case "panel": QuickPanelController.shared.show()
                case "bubble": SavedBubble.shared.show()
                case "seed": NoteStore.shared.seed()
                case let command? where command.hasPrefix("shot:"):
                    // Renders every visible window of the app to <folder>/<title>.png (no permissions needed).
                    let folder = URL(fileURLWithPath: String(command.dropFirst(5)), isDirectory: true)
                    for (index, window) in NSApp.windows.enumerated() where window.isVisible {
                        guard let view = window.contentView?.superview ?? window.contentView,
                              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                        view.cacheDisplay(in: view.bounds, to: rep)
                        let name = window is KeyPanel ? "panel" : (window.title.isEmpty ? "window\(index)" : window.title)
                        try? rep.representation(using: .png, properties: [:])?
                            .write(to: folder.appendingPathComponent("\(name).png"))
                    }
                case "trash": self?.showMainWindow(); NotificationCenter.default.post(name: .debugShowTrash, object: nil)
                case let command? where command.hasPrefix("query:"):
                    QuickPanelController.shared.model.query = String(command.dropFirst(6))
                case let command? where command.hasPrefix("lang:"):
                    if let language = AppLanguage(rawValue: String(command.dropFirst(5))) { Localizer.shared.choice = language }
                case "settings": self?.showSettings()
                case let command? where command.hasPrefix("theme:"):
                    if let theme = AppTheme(rawValue: String(command.dropFirst(6))) { Settings.shared.theme = theme }
                default: break
                }
            }
        }
        #endif
    }
}

extension Notification.Name {
    /// Debug hook: the main window switches to the trash.
    static let debugShowTrash = Notification.Name("debugShowTrash")
}

/// NSMenuItem that runs a closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
