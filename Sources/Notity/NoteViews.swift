import SwiftUI

/// "hace 5 min · Safari" in the current language.
func noteDetail(_ note: Note, now: Date = Date()) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Localizer.shared.locale
    formatter.unitsStyle = .short
    let date = note.trashed ?? note.created
    let when = now.timeIntervalSince(date) < 60 ? tr("ahora") : formatter.localizedString(for: date, relativeTo: now)
    return [when, note.app].compactMap { $0 }.joined(separator: " · ")
}

/// One note in a list.
struct NoteRow: View {
    let note: Note
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: note.pinned ? "pin.fill" : "text.alignleft")
                .font(.system(size: 11))
                .foregroundStyle(note.pinned ? Theme.accentText : Theme.text3)
                .frame(width: 16, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(noteDetail(note))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? Theme.navSelected : .clear, in: RoundedRectangle(cornerRadius: Theme.radius))
        .contentShape(Rectangle())
    }
}

/// Full text of a note, selectable.
struct NotePreview: View {
    let note: Note?
    var empty: String = ""

    var body: some View {
        if let note {
            ScrollView {
                Text(note.text)
                    .monospacedText(size: 12)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
            }
        } else {
            Text(empty)
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Keyboard hint like "↩ Copiar".
struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 17)
                .background(Theme.control, in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.system(size: 11))
        }
        .foregroundStyle(Theme.text3)
    }
}
