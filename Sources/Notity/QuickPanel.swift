import AppKit
import Combine
import SwiftUI

/// State of the quick panel: search text and selected note.
@MainActor
final class PickerModel: ObservableObject {
    @Published var query = ""
    @Published var selectedID: Note.ID?
    /// Bumped every time the panel opens, to focus the search field again.
    @Published var focusToken = 0

    var results: [Note] { NoteStore.shared.active.filter { $0.matches(query) } }

    var selected: Note? {
        let results = results
        return results.first { $0.id == selectedID } ?? results.first
    }

    func reset() {
        query = ""
        selectedID = nil
        focusToken += 1
    }

    func move(_ step: Int) {
        let results = results
        guard !results.isEmpty else { return }
        let current = results.firstIndex { $0.id == selected?.id } ?? 0
        selectedID = results[max(0, min(results.count - 1, current + step))].id
    }
}

/// Panel that can take keyboard focus without a title bar.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Spotlight-like panel opened with the global shortcut: search, ↑↓, Enter copies.
@MainActor
final class QuickPanelController: NSObject, NSWindowDelegate {
    static let shared = QuickPanelController()

    let model = PickerModel()
    private var panel: KeyPanel?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private let size = NSSize(width: 680, height: 420)

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() { isVisible ? close() : show() }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        let panel = panel ?? makePanel()
        self.panel = panel
        style(panel)
        model.reset()
        position(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // Local monitors run on the main thread; only plain values cross into the main actor.
                let key = Int(event.keyCode)
                let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
                let window = event.windowNumber
                let handled = MainActor.assumeIsolated {
                    self?.handle(key: key, command: command, window: window) ?? false
                }
                return handled ? nil : event
            }
        }
    }

    /// Closes the panel and gives focus back to the app that was in front.
    func close(returnFocus: Bool = true) {
        guard let panel, panel.isVisible else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
        if returnFocus { previousApp?.activate() }
    }

    func choose(_ note: Note?) {
        guard let note else { return }
        NoteStore.shared.copy(note)
        close()
    }

    func applyTheme() { if let panel { style(panel) } }

    func windowDidResignKey(_ notification: Notification) {
        close(returnFocus: false)
    }

    // MARK: - Private

    private func makePanel() -> KeyPanel {
        let panel = KeyPanel(contentRect: NSRect(origin: .zero, size: size),
                             styleMask: [.titled, .fullSizeContentView],
                             backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        // Hosting view with autoresizing and no Auto Layout: constraints would resize the panel.
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        let hosting = NSHostingView(rootView: ThemedRoot { QuickPanelView(model: self.model) })
        hosting.sizingOptions = []
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        panel.contentView = container
        panel.setContentSize(size)
        return panel
    }

    private func style(_ panel: NSPanel) {
        panel.appearance = NSAppearance(named: Theme.palette.isLight ? .aqua : .darkAqua)
        panel.backgroundColor = Theme.nsWindow
    }

    /// Centred horizontally on the screen with the mouse, in its upper third.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { panel.center(); return }
        let frame = panel.frame
        let x = visible.midX - frame.width / 2
        let y = visible.maxY - visible.height * 0.22 - frame.height
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: max(visible.minY, y).rounded()))
    }

    /// Arrows, Enter, Esc, ⌘P and ⌘⌫. Everything else goes to the search field.
    private func handle(key: Int, command: Bool, window: Int) -> Bool {
        guard let panel, window == panel.windowNumber else { return false }
        switch key {
        case 125: model.move(1)
        case 126: model.move(-1)
        case 36, 76: choose(model.selected)
        case 53: close()
        case 35 where command: if let id = model.selected?.id { NoteStore.shared.togglePin(id); model.selectedID = id }
        case 51 where command:
            if let id = model.selected?.id {
                model.move(1)
                if model.selectedID == id { model.move(-1) }
                NoteStore.shared.moveToTrash(id)
            }
        default: return false
        }
        return true
    }
}

struct QuickPanelView: View {
    @ObservedObject var model: PickerModel
    @ObservedObject private var store = NoteStore.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = model.results
        let selected = model.selected
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(Theme.text3)
                TextField(tr("Buscar en tus notas…"), text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            Rectangle().fill(Theme.line).frame(height: 1)

            if store.active.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(results) { note in
                                    NoteRow(note: note, selected: note.id == selected?.id)
                                        .id(note.id)
                                        .onTapGesture(count: 2) { QuickPanelController.shared.choose(note) }
                                        .onTapGesture { model.selectedID = note.id }
                                }
                            }
                            .padding(8)
                        }
                        .onChange(of: model.selectedID) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
                    }
                    .frame(width: 290)
                    Rectangle().fill(Theme.line).frame(width: 1)
                    NotePreview(note: selected, empty: tr("Nada coincide con «%@».", model.query))
                        .background(Theme.card)
                }
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 16) {
                KeyHint(key: "↩", label: tr("Copiar"))
                KeyHint(key: "⌘P", label: selected?.pinned == true ? tr("Desfijar") : tr("Fijar"))
                KeyHint(key: "⌘⌫", label: tr("Papelera"))
                Spacer()
                KeyHint(key: "esc", label: tr("Cerrar"))
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 30, weight: .light)).foregroundStyle(Theme.accentText)
            Text(tr("Aún no hay notas")).font(.system(size: 15, weight: .semibold))
            Text(tr("Pulsa ⌘C dos veces seguidas sobre un texto y se guardará aquí."))
                .font(.system(size: 12)).foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
