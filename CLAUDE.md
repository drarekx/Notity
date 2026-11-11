# Notity

Guarda lo que copias dos veces y recupéralo al momento. App nativa de macOS de barra de menús (sin icono en el Dock). Swift + AppKit/SwiftUI, sin dependencias en el código. Repo: https://github.com/drarekx/Notity (constante `AppInfo.repo` en `AppDelegate.swift`, también en `install.sh` y README).

Creada con la skill `crear-app-mac`: misma estructura, instalador, actualizador, temas, idiomas y menú que Wallpy, DemoImages y Droppy.

## Compilar y ejecutar

```sh
swift build                      # debug, comprobación rápida
./build-app.sh                   # release → build/Notity.app + build/Notity.zip (universal con Xcode; nativo con solo CLT)
VERSION=1.2.0 ./build-app.sh     # versión en Info.plist (por defecto 1.0.0)
open build/Notity.app
.build/debug/Notity -appLanguage ca   # probar otro idioma sin tocar los ajustes
```

- Requisitos: macOS 14+. `Package.swift` usa tools 5.10 (modo Swift 5).
- No hay tests. Verificar compilando y lanzando la app (y con capturas, ver «Pruebas manuales»).
- La copia instalada vive en `/Applications/Notity.app`; la de `build/` es de desarrollo y tiene versión 1.0.0, así que su actualizador siempre ve versiones nuevas.

## Publicar una versión

```sh
git tag v1.0.1 && git push origin v1.0.1
```

`.github/workflows/release.yml` (macos-15) compila con `VERSION` = tag y crea el release con `Notity.zip` y `Notity.zip.sha256`. `Updater.swift` consulta `releases/latest`, verifica el SHA-256 y el `Info.plist` y cambia el bundle. `build.yml` compila arm64 + x86_64 y verifica que `en` y `ca` tienen las mismas claves y que todo `tr()` está traducido. La app no está notarizada (firma ad-hoc). Commits con la skill `commit:commit`.

## Estructura (`Sources/Notity/`)

| Archivo | Qué hace |
|---|---|
| `main.swift`, `AppDelegate.swift` | Arranque, `AppInfo` (nombre, repo, Buy Me a Coffee, `menuBarApp`), icono y menú de la barra de menús, ventanas (principal y Ajustes), menú principal, gancho de depuración |
| `MainView.swift` | Ventana principal: notas y papelera, búsqueda, vista previa y acciones |
| `NoteStore.swift` | `Note` y `NoteStore`: notas en `~/Library/Application Support/Notity/notes.json` (0600), caducidad (`purge`, cada 10 min) y papelera de 7 días; `seed()` de muestra (debug) |
| `ClipboardWatcher.swift` | Sondea `NSPasteboard.changeCount` cada 50 ms: el mismo texto dos veces dentro de `doubleCopyWindow` → nota. Ignora tipos de nspasteboard.org (contraseñas) y sus propias escrituras |
| `KeyWatcher.swift` | Opcional (Ajustes → «Detectar ⌘C con el teclado»): event tap de solo escucha (Monitorización de entrada) que detecta ⌘C ⌘C por teclas y guarda el portapapeles 150 ms después. Mientras funciona, `ClipboardWatcher` no detecta dobles copias. Reintenta cada 2 s y al activarse la app hasta tener permiso |
| `HotKey.swift` | `Shortcut` (opciones de Ajustes) y atajo global con Carbon `RegisterEventHotKey` |
| `QuickPanel.swift` | Panel tipo Spotlight (`KeyPanel`, `QuickPanelController`, `PickerModel`): ↑↓, ↩ copia y devuelve el foco a la app anterior, ⌘P fija, ⌘⌫ papelera, esc |
| `SavedBubble.swift` | Burbuja «Nota guardada» junto al puntero al guardar (panel sin bordes, no activa ni recibe clics, se desvanece en 1 s) |
| `NoteViews.swift` | `NoteRow`, `NotePreview`, `KeyHint`, `noteDetail` (fecha relativa · app) |
| `SettingsPane.swift` | Ajustes: guardar (doble ⌘C), caducidad, atajo, colores, abrir al iniciar sesión, idioma, actualizaciones, invitar a un café |
| `Settings.swift` | `UserDefaults` (`com.egluu.notity`), `LoginItem` (`SMAppService`) |
| `Theme.swift` | Colores (sacados del tema elegido) y controles comunes: `AppButtonStyle`, `IconButton`, `SegmentedControl`, `SectionLabel`, `AppTextField`, `SwitchRow`, `appCard` |
| `Themes.swift` | `AppTheme` (Original, Solarized, Dracula, Nord, Gruvbox, Monokai, One Dark, Tokyo Night, Catppuccin, Rosé Pine, Everforest, Kanagawa, GitHub Dark), `ThemedRoot`, `ThemeSwatch` |
| `Updater.swift` | Autoactualización desde GitHub Releases con SHA-256 |
| `Localization.swift` | Idiomas (en, es, ca): `tr()`, `Localizer`, tablas |
| `Icon/AppIcon.html` | Fuente del icono. `scripts/make-icon.sh` lo renderiza con Chrome headless y genera `Resources/AppIcon.icns` (versionado) e `Icon/AppIcon-1024.png` |

## Convenciones

- Código, comentarios y commits en inglés. Interfaz en castellano, inglés y catalán.
- **Todo texto visible pasa por `tr("…")`** (o `tr("… %@ …", arg)`). La clave es el texto en castellano; añadir la traducción a `en` y `ca` en `Localization.swift` con los mismos `%@`/`%d`. Nunca interpolar dentro de un texto traducible. Los nombres propios (temas, formatos) no se traducen.
- Estilo: usar `Theme` y sus componentes, nunca colores sueltos. Toda ventana nueva va dentro de `ThemedRoot { … }` (sigue el tema y el idioma).
- Estado de UI en tipos `@MainActor`; trabajo pesado (archivos, procesos) fuera del hilo principal.
- Borrar archivos del usuario = papelera (`trashItem`/`recycle`), nunca `removeItem`.
- El menú de la barra (o el de la app) mantiene siempre: Ajustes…, Buscar actualizaciones…, Invítame a un café… (`cup.and.saucer`), versión y Salir.
- Mantener el README al día (con capturas en `docs/`) cuando cambian funciones visibles.

## Cosas que ya costaron (no repetir)

- **`NSHostingController`/`NSHostingView` redimensionan la ventana**: `sizingOptions = []`, `setContentSize` y después `setFrameAutosaveName`. En paneles hechos a mano, el `NSHostingView` con autoresizing y **sin Auto Layout**: con restricciones, `_changeWindowFrameFromConstraintsIfNecessary` impone el tamaño mínimo de SwiftUI.
- Nunca `setFrame(…, animate: true)` con SwiftUI dentro: da saltos. Cambiar el marco de golpe y animar el contenido.
- **`@Published` avisa en `willSet`**: un sink que redimensiona o repinta ahí ve el valor viejo y la vista se queda desfasada. Hacerlo en `DispatchQueue.main.async` o con `.receive(on: RunLoop.main)`.
- **Sin menú principal no funcionan ⌘C/⌘V/⌘A** en campos de texto de una app de barra de menús: `setupMainMenu()` lo crea aunque no se vea.
- Los `NSPanel` se esconden al desactivarse la app (`hidesOnDeactivate = false` si deben quedarse); un panel `.nonactivatingPanel` necesita `canBecomeKey` para escribir en él y `makeKey()` antes de enfocar un campo.
- Monitores globales: `NSEvent.addGlobalMonitorForEvents` de ratón no pide permisos; de teclado pide Accesibilidad. Atajos globales sin permisos: Carbon `RegisterEventHotKey`. ⌥⌘D está cogido (Dock).
- **Instalador con `curl | bash`**: con `set -u` y locale C, `"$NAME…"` hace que bash lea los bytes de «…» como parte del nombre → `unbound variable`. Usar siempre `${NAME}` pegado a texto no ASCII.
- **Abrir al iniciar sesión**: solo desde la copia de Aplicaciones (`LoginItem.enableOnceFromApplications`); desde `build/` registraría la de desarrollo. `open build/Notity.app --args -unregisterLoginItem YES` lo quita.
- La app no está notarizada (firma ad-hoc): los permisos de privacidad (Descargas, Accesibilidad…) pueden volver a pedirse tras cada actualización.
- Builds universales (`--arch arm64 --arch x86_64`) necesitan Xcode completo; `build-app.sh` cae a la arquitectura nativa con solo CLT.
- **Runners de GitHub**: `macos-14` ya no existe. En `macos-15` el job puede quedarse en cola; relanzar con `gh run rerun <id>`.
- `main.swift` envuelve el arranque en `MainActor.assumeIsolated` porque `AppDelegate` es `@MainActor`.

- **El sandbox de Bash aísla el portapapeles**: `pbcopy` dentro del sandbox no llega a la app. Las pruebas del doble ⌘C se hacen fuera del sandbox (`pbcopy` dos veces con `sleep 0.2`; una contraseña, con un script que añada `org.nspasteboard.ConcealedType`).
- **Monitor de teclado local y Swift 6**: pasar el `NSEvent` a `MainActor.assumeIsolated` avisa de `Sendable`; sacar antes `keyCode`, modificadores y `windowNumber` y devolver `nil`/`event` fuera.
- **iTerm2 no vuelve a escribir el portapapeles** si el texto seleccionado ya está (copia al seleccionar o en el primer ⌘C): el `changeCount` no cambia y el doble ⌘C no se ve. Por eso existe `KeyWatcher`. Para diagnosticar otra app, un registro del portapapeles cada 10 ms (`changeCount`, tipos, app delante) mientras el usuario copia.
- El permiso de Monitorización de entrada va por binario: el de debug lanzado desde la terminal no lo tiene (`keys` en el gancho imprime el estado); probar el tap con la copia instalada.
- El panel es `.titled` (esquinas y sombra del sistema) con título oculto: su SwiftUI necesita `.ignoresSafeArea(.container, edges: .top)` o deja un hueco arriba. Igual la ventana principal con `titleVisibility = .hidden`.

## Pruebas manuales

- **Gancho de depuración** (solo debug): `.build/debug/Notity` y `DistributedNotificationCenter` `com.egluu.notity.debug` con objeto `main`, `settings`, `theme:<id>`, `panel`, `bubble`, `keys` (estado del `KeyWatcher` en stdout), `query:<texto>`, `trash`, `lang:<es|en|ca>`, `seed` (notas de muestra) o `shot:<carpeta>` (guarda un PNG de cada ventana visible, sin permiso de grabación de pantalla).
- **Datos de prueba**: `NOTITY_DATA_DIR=<carpeta> .build/debug/Notity` (solo debug) usa otra carpeta para `notes.json`; nunca probar con las notas reales.
- Sin teclado real no se prueban: el atajo global, ↑↓/↩/⌘P/⌘⌫ del panel ni la vuelta del foco a la app anterior. Añadir ahí los comandos que haga falta para llevar la app a cada estado sin ratón.
- **Capturas** (con permiso de grabación de pantalla): `screencapture -x -l <id de ventana>` saca solo la ventana, sin el escritorio. Los ids, con `CGWindowListCopyWindowInfo` filtrando por propietario `Notity`.
- El binario de debug usa el dominio de `UserDefaults` `Notity`, no `com.egluu.notity`, pero comparte `~/Library/Application Support/Notity`: hacer copia antes de probar y restaurarla después.
