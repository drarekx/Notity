import AppKit
import SwiftUI

struct SettingsPane: View {
    @ObservedObject private var localizer = Localizer.shared
    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var settings = Settings.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(tr("Ajustes")).font(.system(size: 22, weight: .semibold))
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("Guardar"))
                    SwitchRow(title: tr("Guardar al copiar dos veces (⌘C ⌘C)"),
                              detail: tr("Un ⌘C normal no guarda nada. Las contraseñas que copian los gestores (1Password, Bitwarden, Llavero…) no se guardan nunca."),
                              isOn: $settings.doubleCopy)
                    HStack {
                        Text(tr("Tiempo entre las dos copias")).foregroundStyle(settings.doubleCopy ? Theme.text : Theme.text3)
                        Spacer()
                        SegmentedControl(options: [(tr("Rápido"), 0.35), (tr("Normal"), 0.5), (tr("Lento"), 0.8)],
                                         selection: $settings.doubleCopyWindow)
                            .disabled(!settings.doubleCopy)
                    }
                }
                .appCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("Caducidad"))
                    Text(tr("Las notas fijadas no caducan. Las caducadas pasan a la papelera, de donde se pueden recuperar durante %d días.", NoteStore.trashDays))
                        .font(.system(size: 12)).foregroundStyle(Theme.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    SegmentedControl(options: [(tr("1 día"), 1), (tr("7 días"), 7), (tr("30 días"), 30), (tr("Nunca"), 0)],
                                     selection: $settings.expiryDays)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("Atajo"))
                    Text(tr("Abre el panel de búsqueda desde cualquier app."))
                        .font(.system(size: 12)).foregroundStyle(Theme.text2)
                    SegmentedControl(options: Shortcut.allCases.map { ($0.label, $0) }, selection: $settings.shortcut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(tr("Colores"))
                    Text(tr("Temas clásicos de editores y terminales, con sus colores oficiales."))
                        .font(.system(size: 12)).foregroundStyle(Theme.text2)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], spacing: 14) {
                        ForEach(AppTheme.allCases) { theme in
                            Button { settings.theme = theme } label: {
                                ThemeSwatch(theme: theme, selected: settings.theme == theme)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(theme.name)
                        }
                    }
                }
                .appCard()

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(tr("General"))
                    SwitchRow(title: tr("Abrir al iniciar sesión"),
                              isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    if let loginError {
                        Label(loginError, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(Theme.warn)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .appCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(tr("Idioma"))
                    SegmentedControl(options: AppLanguage.allCases.map { ($0.nativeName, $0) },
                                     selection: $localizer.choice)
                }
                .appCard()

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(tr("Actualizaciones"))
                    SwitchRow(title: tr("Buscar actualizaciones automáticamente"),
                              detail: tr("Al abrir la app y una vez al día, desde GitHub (%@).", AppInfo.repo),
                              isOn: Binding(get: { updater.autoCheck }, set: { updater.autoCheck = $0 }))
                    HStack {
                        Text(tr("Versión %@", Updater.currentVersion)).foregroundStyle(Theme.text2)
                        Spacer()
                        Button(updater.state == .idle ? tr("Buscar ahora") : tr("Buscando…")) {
                            Task { await updater.check(userInitiated: true) }
                        }
                        .buttonStyle(.appSecondary)
                        .disabled(updater.state != .idle)
                    }
                }
                .appCard()

                HStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 18)).foregroundStyle(Theme.accentText)
                        .frame(width: 36, height: 36)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("¿Te es útil %@?", AppInfo.name)).fontWeight(.medium)
                        Text(tr("Es gratis y sin anuncios. Si te ahorra tiempo, puedes invitarme a un café."))
                            .font(.system(size: 12)).foregroundStyle(Theme.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(tr("Invítame a un café…")) { NSWorkspace.shared.open(AppInfo.buyMeACoffee) }
                        .buttonStyle(.appSecondary)
                }
                .appCard()
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginError = LoginItem.setEnabled(enabled).map { tr("No se pudo cambiar: %@", $0) }
        launchAtLogin = LoginItem.isEnabled
    }
}
