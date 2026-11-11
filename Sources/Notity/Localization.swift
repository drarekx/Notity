import Combine
import Foundation

/// Languages the UI is translated to. Spanish strings are the keys.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, es, ca
    var id: String { rawValue }

    /// Shown in its own language, so anyone can find theirs.
    var nativeName: String {
        switch self {
        case .system: return tr("Sistema")
        case .en: return "English"
        case .es: return "Español"
        case .ca: return "Català"
        }
    }
}

final class Localizer: ObservableObject {
    static let shared = Localizer()

    @Published var choice: AppLanguage {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: "appLanguage") }
    }

    private init() {
        choice = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    }

    /// The language actually used: the chosen one, or the first supported system language (English otherwise).
    var language: AppLanguage {
        if choice != .system { return choice }
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2))
            if let match = AppLanguage(rawValue: code), match != .system { return match }
        }
        return .en
    }

    var locale: Locale { Locale(identifier: language.rawValue) }

    func translate(_ key: String) -> String {
        switch language {
        case .en: return Translations.en[key] ?? key
        case .ca: return Translations.ca[key] ?? key
        default: return key
        }
    }
}

/// Translated UI text. `key` is the Spanish text.
func tr(_ key: String) -> String {
    Localizer.shared.translate(key)
}

/// Translated format string (`%@`, `%d`) with arguments.
func tr(_ key: String, _ args: CVarArg...) -> String {
    String(format: Localizer.shared.translate(key), locale: Localizer.shared.locale, arguments: args)
}

private enum Translations {
    static let en: [String: String] = [
        "Detectar ⌘C con el teclado": "Detect ⌘C from the keyboard",
        "Para apps como iTerm2, que no vuelven a copiar si el texto no ha cambiado. Pide el permiso de Monitorización de entrada; Notity solo mira si pulsas ⌘C, nunca lo que escribes.": "For apps like iTerm2, which don't copy again if the text hasn't changed. Needs the Input Monitoring permission; Notity only checks whether you press ⌘C, never what you type.",
        "Activo: el doble ⌘C funciona en todas las apps.": "On: double ⌘C works in every app.",
        "Falta el permiso. Activa Notity en Monitorización de entrada.": "Permission missing. Turn on Notity in Input Monitoring.",
        "Abrir Ajustes del Sistema…": "Open System Settings…",
        "1 día": "1 day",
        "30 días": "30 days",
        "7 días": "7 days",
        "Abre el panel de búsqueda desde cualquier app.": "Opens the search panel from any app.",
        "Atajo": "Shortcut",
        "Aún no hay notas": "No notes yet",
        "Borrar para siempre": "Delete Forever",
        "Buscar en tus notas…": "Search your notes…",
        "Buscar nota…": "Find Note…",
        "Buscar…": "Search…",
        "Caducidad": "Expiry",
        "Cerrar": "Close",
        "Copia dos veces (⌘C ⌘C) para guardar": "Copy twice (⌘C ⌘C) to save",
        "Desfijar": "Unpin",
        "Fijar": "Pin",
        "Guarda ahora lo que hay en el portapapeles.": "Saves what is on the clipboard now.",
        "Guardar": "Saving",
        "Guardar al copiar dos veces (⌘C ⌘C)": "Save when copying twice (⌘C ⌘C)",
        "Guardar portapapeles": "Save Clipboard",
        "Guardar portapapeles ahora": "Save Clipboard Now",
        "La papelera está vacía": "The trash is empty",
        "Las notas caducadas o borradas se quedan aquí %d días.": "Expired or deleted notes stay here for %d days.",
        "Las notas fijadas no caducan. Las caducadas pasan a la papelera, de donde se pueden recuperar durante %d días.": "Pinned notes never expire. Expired notes go to the trash, where they can be restored for %d days.",
        "Lento": "Slow",
        "Nada coincide con «%@».": "Nothing matches “%@”.",
        "Normal": "Normal",
        "Nota guardada": "Note saved",
        "Notas (%d)": "Notes (%d)",
        "Nunca": "Never",
        "Papelera": "Trash",
        "Papelera (%d)": "Trash (%d)",
        "Pulsa %@ en cualquier sitio para buscarla y copiarla otra vez.": "Press %@ anywhere to find it and copy it again.",
        "Pulsa ⌘C dos veces seguidas sobre un texto y se guardará aquí.": "Press ⌘C twice in a row on some text and it will be saved here.",
        "Restaurar": "Restore",
        "Rápido": "Fast",
        "Selecciona un texto y pulsa ⌘C dos veces seguidas: se guarda como nota.": "Select some text and press ⌘C twice in a row: it is saved as a note.",
        "Sin atajo": "None",
        "Tiempo entre las dos copias": "Time between both copies",
        "Un ⌘C normal no guarda nada, así que lo que no quieras conservar no se queda.": "A normal ⌘C saves nothing, so whatever you don't want to keep isn't kept.",
        "Un ⌘C normal no guarda nada. Las contraseñas que copian los gestores (1Password, Bitwarden, Llavero…) no se guardan nunca.": "A normal ⌘C saves nothing. Passwords copied by password managers (1Password, Bitwarden, Keychain…) are never saved.",
        "Vaciar papelera": "Empty Trash",
        "ahora": "now",
        "Últimas notas": "Recent notes",
        "%@ %@ está disponible": "%@ %@ is available",
        "%@ está actualizado": "%@ is up to date",
        "Abrir %@": "Open %@",
        "Abrir al iniciar sesión": "Open at login",
        "Acerca de %@": "About %@",
        "Actualizaciones": "Updates",
        "Actualizando…": "Updating…",
        "Actualizar ahora": "Update Now",
        "Ajustes": "Settings",
        "Ajustes de %@": "%@ Settings",
        "Ajustes…": "Settings…",
        "Al abrir la app y una vez al día, desde GitHub (%@).": "At launch and once a day, from GitHub (%@).",
        "Buscando…": "Checking…",
        "Buscar actualizaciones automáticamente": "Check for updates automatically",
        "Buscar actualizaciones…": "Check for Updates…",
        "Buscar ahora": "Check Now",
        "Cerrar ventana": "Close Window",
        "Colores": "Colours",
        "Copiar": "Copy",
        "Cortar": "Cut",
        "Deshacer": "Undo",
        "Edición": "Edit",
        "El archivo descargado no coincide con su huella SHA-256. No se ha instalado nada.": "The downloaded file doesn't match its SHA-256 checksum. Nothing was installed.",
        "Es gratis y sin anuncios. Si te ahorra tiempo, puedes invitarme a un café.": "It's free and ad-free. If it saves you time, you can buy me a coffee.",
        "General": "General",
        "GitHub no respondió correctamente. Inténtalo más tarde.": "GitHub didn't respond correctly. Try again later.",
        "Idioma": "Language",
        "Invítame a un café…": "Buy Me a Coffee…",
        "La actualización falló": "The update failed",
        "La descarga no contiene una versión válida de %@.": "The download doesn't contain a valid version of %@.",
        "La versión %@ no incluye los archivos de actualización.": "Version %@ doesn't include the update files.",
        "Minimizar": "Minimize",
        "Mostrar todo": "Show All",
        "Mueve %@ a la carpeta Aplicaciones, ábrela de nuevo y vuelve a intentarlo.": "Move %@ to the Applications folder, open it again and retry.",
        "Más tarde": "Later",
        "No hay permiso para escribir en %@.\nUsa el instalador:\n\n%@": "No permission to write to %@.\nUse the installer:\n\n%@",
        "No se pudo buscar actualizaciones": "Couldn't check for updates",
        "No se pudo cambiar: %@": "Couldn't change it: %@",
        "No se pudo descomprimir la actualización.": "Couldn't unzip the update.",
        "No se puede actualizar": "Can't update",
        "No se puede actualizar desde aquí": "Can't update from here",
        "Ocultar %@": "Hide %@",
        "Ocultar otras": "Hide Others",
        "Omitir esta versión": "Skip This Version",
        "Original (por defecto)": "Original (default)",
        "Pegar": "Paste",
        "Rehacer": "Redo",
        "Salir de %@": "Quit %@",
        "Seleccionar todo": "Select All",
        "Sistema": "System",
        "Temas clásicos de editores y terminales, con sus colores oficiales.": "Classic editor and terminal themes, with their official colours.",
        "Tienes la versión %@.": "You have version %@.",
        "Tienes la última versión (%@).": "You have the latest version (%@).",
        "Ventana": "Window",
        "Versión %@": "Version %@",
        "Guarda lo que copias dos veces y recupéralo al momento.": "Keep what you copy twice and get it back instantly.",
        "¿Te es útil %@?": "Is %@ useful to you?",
    ]

    static let ca: [String: String] = [
        "Detectar ⌘C con el teclado": "Detecta ⌘C amb el teclat",
        "Para apps como iTerm2, que no vuelven a copiar si el texto no ha cambiado. Pide el permiso de Monitorización de entrada; Notity solo mira si pulsas ⌘C, nunca lo que escribes.": "Per a apps com iTerm2, que no tornen a copiar si el text no ha canviat. Demana el permís de Monitoratge d'entrada; Notity només mira si prems ⌘C, mai el que escrius.",
        "Activo: el doble ⌘C funciona en todas las apps.": "Actiu: el doble ⌘C funciona a totes les apps.",
        "Falta el permiso. Activa Notity en Monitorización de entrada.": "Falta el permís. Activa Notity a Monitoratge d'entrada.",
        "Abrir Ajustes del Sistema…": "Obre la Configuració del Sistema…",
        "1 día": "1 dia",
        "30 días": "30 dies",
        "7 días": "7 dies",
        "Abre el panel de búsqueda desde cualquier app.": "Obre el tauler de cerca des de qualsevol app.",
        "Atajo": "Drecera",
        "Aún no hay notas": "Encara no hi ha notes",
        "Borrar para siempre": "Esborra per sempre",
        "Buscar en tus notas…": "Cerca a les teves notes…",
        "Buscar nota…": "Cerca una nota…",
        "Buscar…": "Cerca…",
        "Caducidad": "Caducitat",
        "Cerrar": "Tanca",
        "Copia dos veces (⌘C ⌘C) para guardar": "Copia dues vegades (⌘C ⌘C) per desar",
        "Desfijar": "Desfixa",
        "Fijar": "Fixa",
        "Guarda ahora lo que hay en el portapapeles.": "Desa ara el que hi ha al porta-retalls.",
        "Guardar": "Desar",
        "Guardar al copiar dos veces (⌘C ⌘C)": "Desa en copiar dues vegades (⌘C ⌘C)",
        "Guardar portapapeles": "Desa el porta-retalls",
        "Guardar portapapeles ahora": "Desa el porta-retalls ara",
        "La papelera está vacía": "La paperera és buida",
        "Las notas caducadas o borradas se quedan aquí %d días.": "Les notes caducades o esborrades es queden aquí %d dies.",
        "Las notas fijadas no caducan. Las caducadas pasan a la papelera, de donde se pueden recuperar durante %d días.": "Les notes fixades no caduquen. Les caducades van a la paperera, d'on es poden recuperar durant %d dies.",
        "Lento": "Lent",
        "Nada coincide con «%@».": "Res no coincideix amb «%@».",
        "Normal": "Normal",
        "Nota guardada": "Nota desada",
        "Notas (%d)": "Notes (%d)",
        "Nunca": "Mai",
        "Papelera": "Paperera",
        "Papelera (%d)": "Paperera (%d)",
        "Pulsa %@ en cualquier sitio para buscarla y copiarla otra vez.": "Prem %@ a qualsevol lloc per trobar-la i copiar-la una altra vegada.",
        "Pulsa ⌘C dos veces seguidas sobre un texto y se guardará aquí.": "Prem ⌘C dues vegades seguides sobre un text i es desarà aquí.",
        "Restaurar": "Restaura",
        "Rápido": "Ràpid",
        "Selecciona un texto y pulsa ⌘C dos veces seguidas: se guarda como nota.": "Selecciona un text i prem ⌘C dues vegades seguides: es desa com a nota.",
        "Sin atajo": "Sense drecera",
        "Tiempo entre las dos copias": "Temps entre les dues còpies",
        "Un ⌘C normal no guarda nada, así que lo que no quieras conservar no se queda.": "Un ⌘C normal no desa res, així que el que no vulguis conservar no s'hi queda.",
        "Un ⌘C normal no guarda nada. Las contraseñas que copian los gestores (1Password, Bitwarden, Llavero…) no se guardan nunca.": "Un ⌘C normal no desa res. Les contrasenyes que copien els gestors (1Password, Bitwarden, Clauer…) no es desen mai.",
        "Vaciar papelera": "Buida la paperera",
        "ahora": "ara",
        "Últimas notas": "Últimes notes",
        "%@ %@ está disponible": "%@ %@ està disponible",
        "%@ está actualizado": "%@ està actualitzada",
        "Abrir %@": "Obre %@",
        "Abrir al iniciar sesión": "Obre en iniciar la sessió",
        "Acerca de %@": "Quant a %@",
        "Actualizaciones": "Actualitzacions",
        "Actualizando…": "Actualitzant…",
        "Actualizar ahora": "Actualitza ara",
        "Ajustes": "Configuració",
        "Ajustes de %@": "Configuració de %@",
        "Ajustes…": "Configuració…",
        "Al abrir la app y una vez al día, desde GitHub (%@).": "En obrir l'app i un cop al dia, des de GitHub (%@).",
        "Buscando…": "Cercant…",
        "Buscar actualizaciones automáticamente": "Cerca actualitzacions automàticament",
        "Buscar actualizaciones…": "Cerca actualitzacions…",
        "Buscar ahora": "Cerca ara",
        "Cerrar ventana": "Tanca la finestra",
        "Colores": "Colors",
        "Copiar": "Copia",
        "Cortar": "Retalla",
        "Deshacer": "Desfés",
        "Edición": "Edició",
        "El archivo descargado no coincide con su huella SHA-256. No se ha instalado nada.": "El fitxer baixat no coincideix amb la seva empremta SHA-256. No s'ha instal·lat res.",
        "Es gratis y sin anuncios. Si te ahorra tiempo, puedes invitarme a un café.": "És gratis i sense anuncis. Si t'estalvia temps, em pots convidar a un cafè.",
        "General": "General",
        "GitHub no respondió correctamente. Inténtalo más tarde.": "GitHub no ha respost correctament. Torna-ho a provar més tard.",
        "Idioma": "Idioma",
        "Invítame a un café…": "Convida'm a un cafè…",
        "La actualización falló": "L'actualització ha fallat",
        "La descarga no contiene una versión válida de %@.": "La baixada no conté una versió vàlida de %@.",
        "La versión %@ no incluye los archivos de actualización.": "La versió %@ no inclou els fitxers d'actualització.",
        "Minimizar": "Minimitza",
        "Mostrar todo": "Mostra-ho tot",
        "Mueve %@ a la carpeta Aplicaciones, ábrela de nuevo y vuelve a intentarlo.": "Mou %@ a la carpeta Aplicacions, torna-la a obrir i torna-ho a provar.",
        "Más tarde": "Més tard",
        "No hay permiso para escribir en %@.\nUsa el instalador:\n\n%@": "No hi ha permís per escriure a %@.\nFes servir l'instal·lador:\n\n%@",
        "No se pudo buscar actualizaciones": "No s'han pogut cercar actualitzacions",
        "No se pudo cambiar: %@": "No s'ha pogut canviar: %@",
        "No se pudo descomprimir la actualización.": "No s'ha pogut descomprimir l'actualització.",
        "No se puede actualizar": "No es pot actualitzar",
        "No se puede actualizar desde aquí": "No es pot actualitzar des d'aquí",
        "Ocultar %@": "Amaga %@",
        "Ocultar otras": "Amaga les altres",
        "Omitir esta versión": "Omet aquesta versió",
        "Original (por defecto)": "Original (per defecte)",
        "Pegar": "Enganxa",
        "Rehacer": "Refés",
        "Salir de %@": "Surt de %@",
        "Seleccionar todo": "Selecciona-ho tot",
        "Sistema": "Sistema",
        "Temas clásicos de editores y terminales, con sus colores oficiales.": "Temes clàssics d'editors i terminals, amb els seus colors oficials.",
        "Tienes la versión %@.": "Tens la versió %@.",
        "Tienes la última versión (%@).": "Tens l'última versió (%@).",
        "Ventana": "Finestra",
        "Versión %@": "Versió %@",
        "Guarda lo que copias dos veces y recupéralo al momento.": "Desa el que copies dues vegades i recupera-ho a l'instant.",
        "¿Te es útil %@?": "T'és útil %@?",
    ]
}
