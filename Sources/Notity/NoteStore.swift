import AppKit
import Foundation

/// A saved piece of text.
struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    /// When it was saved (or saved again).
    var created: Date
    /// App that was in front when it was copied.
    var app: String?
    var pinned = false
    /// Set when the note is in the trash.
    var trashed: Date?

    /// First non-empty line, for lists and menus.
    var title: String {
        let line = text.split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// Case and accent insensitive: every word of the query must appear.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        return words.allSatisfy {
            text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || (app?.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }
}

/// Notes on disk: `~/Library/Application Support/Notity/notes.json`.
@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    /// Days a trashed note can be restored before it is deleted for good.
    static let trashDays = 7
    /// Longer texts are not saved (they are rarely a note and slow the lists down).
    static let maxLength = 200_000

    @Published private(set) var notes: [Note] = []
    private let file: URL
    private let saveQueue = DispatchQueue(label: "com.egluu.notity.save")
    private var purgeTimer: Timer?

    private init() {
        var folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppInfo.name, isDirectory: true)
        #if DEBUG
        // Tests and screenshots use their own folder, never the real notes.
        if let custom = ProcessInfo.processInfo.environment["NOTITY_DATA_DIR"] {
            folder = URL(fileURLWithPath: custom, isDirectory: true)
        }
        #endif
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("notes.json")
        if let data = try? Data(contentsOf: file) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = (try? decoder.decode([Note].self, from: data)) ?? []
        }
        purge()
        purgeTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            MainActor.assumeIsolated { NoteStore.shared.purge() }
        }
    }

    /// Notes not in the trash: pinned first, then newest.
    var active: [Note] {
        notes.filter { $0.trashed == nil }.sorted {
            $0.pinned != $1.pinned ? $0.pinned : $0.created > $1.created
        }
    }

    /// Trashed notes, most recently trashed first.
    var trash: [Note] {
        notes.filter { $0.trashed != nil }.sorted { ($0.trashed ?? .distantPast) > ($1.trashed ?? .distantPast) }
    }

    /// Saves a text. The same text again moves the existing note to the top. Returns false if ignored.
    @discardableResult
    func add(_ text: String, app: String?) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= Self.maxLength else { return false }
        if let index = notes.firstIndex(where: { $0.text == text }) {
            notes[index].created = Date()
            notes[index].trashed = nil
            if let app { notes[index].app = app }
        } else {
            notes.append(Note(text: text, created: Date(), app: app))
        }
        save()
        return true
    }

    func togglePin(_ id: Note.ID) {
        update(id) { $0.pinned.toggle() }
    }

    func moveToTrash(_ id: Note.ID) {
        update(id) { $0.trashed = Date(); $0.pinned = false }
    }

    func restore(_ id: Note.ID) {
        update(id) { $0.trashed = nil; $0.created = Date() }
    }

    func deleteForever(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        save()
    }

    func emptyTrash() {
        notes.removeAll { $0.trashed != nil }
        save()
    }

    /// Puts the note on the clipboard (without saving it again).
    func copy(_ note: Note) {
        ClipboardWatcher.shared.write(note.text)
    }

    /// Expired notes go to the trash; old trash is deleted.
    func purge(now: Date = Date()) {
        var changed = false
        let days = Settings.shared.expiryDays
        for index in notes.indices where notes[index].trashed == nil && !notes[index].pinned && days > 0 {
            if notes[index].created < now.addingTimeInterval(-Double(days) * 86_400) {
                notes[index].trashed = now
                changed = true
            }
        }
        let limit = now.addingTimeInterval(-Double(Self.trashDays) * 86_400)
        let before = notes.count
        notes.removeAll { ($0.trashed ?? .distantFuture) < limit }
        if changed || notes.count != before { save() }
    }

    #if DEBUG
    /// Sample notes for screenshots.
    func seed() {
        let now = Date()
        notes = [
            Note(text: "Revisa este código Swift y propón mejoras de rendimiento sin cambiar la API pública. Explica cada cambio en una línea.",
                 created: now.addingTimeInterval(-120), app: "Visual Studio Code"),
            Note(text: "git log --oneline --graph --decorate -20", created: now.addingTimeInterval(-3_600), app: "Terminal", pinned: true),
            Note(text: "Resume este hilo en 5 puntos y dime qué decisiones quedan pendientes.\n\nTono: directo, sin adornos.",
                 created: now.addingTimeInterval(-7_200), app: "Safari"),
            Note(text: "https://developer.apple.com/documentation/appkit/nspasteboard", created: now.addingTimeInterval(-86_400), app: "Safari"),
            Note(text: "Calle Mayor 12, 3º 2ª — 08001 Barcelona", created: now.addingTimeInterval(-2 * 86_400), app: "Mail"),
            Note(text: "SELECT id, email FROM users WHERE created_at > now() - interval '7 days';",
                 created: now.addingTimeInterval(-3 * 86_400), app: "TablePlus"),
            Note(text: "Borrador antiguo que ya no hace falta", created: now.addingTimeInterval(-9 * 86_400), app: "Notas",
                 trashed: now.addingTimeInterval(-3_600)),
        ]
        save()
    }
    #endif

    private func update(_ id: Note.ID, _ change: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[index])
        save()
    }

    private func save() {
        let snapshot = notes
        let file = file
        saveQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: file, options: [.atomic])
            // Notes can hold private text: only the user can read the file.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }
}
