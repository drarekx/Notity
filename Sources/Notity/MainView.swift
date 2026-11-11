import SwiftUI

/// Main window: every note (or the trash) with search, preview and actions.
struct MainView: View {
    enum Section: Hashable { case notes, trash }

    @ObservedObject private var store = NoteStore.shared
    @ObservedObject private var settings = Settings.shared
    @State private var section: Section = .notes
    @State private var query = ""
    @State private var selectedID: Note.ID?

    private var results: [Note] {
        (section == .notes ? store.active : store.trash).filter { $0.matches(query) }
    }

    var body: some View {
        let results = results
        let selected = results.first { $0.id == selectedID } ?? results.first
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            if results.isEmpty && query.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(results) { note in
                                NoteRow(note: note, selected: note.id == selected?.id)
                                    .onTapGesture { selectedID = note.id }
                                    .contextMenu { actions(for: note) }
                            }
                        }
                        .padding(10)
                    }
                    .frame(width: 320)
                    .background(Theme.sidebar)
                    Rectangle().fill(Theme.line).frame(width: 1)
                    VStack(spacing: 0) {
                        NotePreview(note: selected, empty: tr("Nada coincide con «%@».", query))
                        if let selected {
                            Rectangle().fill(Theme.line).frame(height: 1)
                            HStack(spacing: 8) { actions(for: selected) }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .onChange(of: section) { selectedID = nil }
        .onReceive(NotificationCenter.default.publisher(for: .debugShowTrash)) { _ in section = .trash }
    }

    private var header: some View {
        HStack(spacing: 12) {
            SegmentedControl(options: [(tr("Notas (%d)", store.active.count), Section.notes),
                                       (tr("Papelera (%d)", store.trash.count), Section.trash)],
                             selection: $section)
            AppTextField(placeholder: tr("Buscar…"), text: $query, icon: "magnifyingglass")
                .frame(maxWidth: 280)
            Spacer()
            if section == .trash && !store.trash.isEmpty {
                Button(tr("Vaciar papelera")) { store.emptyTrash() }.buttonStyle(.appDanger)
            } else if section == .notes {
                Button {
                    ClipboardWatcher.shared.saveCurrent()
                } label: {
                    Label(tr("Guardar portapapeles"), systemImage: "plus")
                }
                .buttonStyle(.appSecondary)
                .help(tr("Guarda ahora lo que hay en el portapapeles."))
            }
        }
        .padding(.leading, 84) // traffic lights
        .padding(.trailing, 14)
        .frame(height: 52)
    }

    @ViewBuilder
    private func actions(for note: Note) -> some View {
        if note.trashed == nil {
            Button(note.pinned ? tr("Desfijar") : tr("Fijar")) { store.togglePin(note.id) }
                .buttonStyle(.appGhost)
            Button(tr("Papelera")) { store.moveToTrash(note.id) }
                .buttonStyle(.appGhost)
            Button(tr("Copiar")) { store.copy(note) }
                .buttonStyle(.appPrimary)
        } else {
            Button(tr("Borrar para siempre")) { store.deleteForever(note.id) }
                .buttonStyle(.appGhost)
            Button(tr("Restaurar")) { store.restore(note.id) }
                .buttonStyle(.appPrimary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: section == .notes ? "doc.on.clipboard" : "trash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.accentText)
            if section == .notes {
                Text(tr("Aún no hay notas")).font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 8) {
                    step("1", tr("Selecciona un texto y pulsa ⌘C dos veces seguidas: se guarda como nota."))
                    step("2", tr("Un ⌘C normal no guarda nada, así que lo que no quieras conservar no se queda."))
                    step("3", tr("Pulsa %@ en cualquier sitio para buscarla y copiarla otra vez.", settings.shortcut.label))
                }
                .frame(maxWidth: 440)
            } else {
                Text(tr("La papelera está vacía")).font(.system(size: 20, weight: .semibold))
                Text(tr("Las notas caducadas o borradas se quedan aquí %d días.", NoteStore.trashDays))
                    .font(.system(size: 13)).foregroundStyle(Theme.text2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 20, height: 20)
                .background(Theme.accentFill, in: Circle())
            Text(text).font(.system(size: 13)).foregroundStyle(Theme.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
