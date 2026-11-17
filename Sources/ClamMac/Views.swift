import SwiftUI
import UniformTypeIdentifiers
import ClamMacCore

enum NavSection: String, CaseIterable, Identifiable {
    case estado = "Estado", vigilancia = "Vigilancia", analisis = "Análisis", cuarentena = "Cuarentena", firmas = "Firmas", ajustes = "Ajustes", registro = "Registro", acerca = "Acerca de"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .estado: "shield.checkered"; case .vigilancia: "eye"; case .analisis: "magnifyingglass"
        case .cuarentena: "archivebox"; case .firmas: "arrow.triangle.2.circlepath"
        case .ajustes: "gearshape"; case .registro: "list.bullet.rectangle"; case .acerca: "info.circle"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var engine: Engine
    @State private var selection: NavSection? = .estado

    var body: some View {
        NavigationSplitView {
            List(NavSection.allCases, selection: $selection) { s in
                Label(s.rawValue, systemImage: s.icon).tag(s)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .safeAreaInset(edge: .bottom) { CoffeeLink().padding(10) }
        } detail: {
            ScrollView { Group {
                switch selection ?? .estado {
                case .estado: StatusView()
                case .vigilancia: WatchView()
                case .analisis: ScanView()
                case .cuarentena: QuarantineView()
                case .firmas: SignaturesView()
                case .ajustes: SettingsView()
                case .registro: LogView()
                case .acerca: AboutView()
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading) }
        }
        // Con la ventana abierta la app aparece en el Dock (con su icono); al cerrarla vuelve a ser solo barra de menú.
        .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }
}

struct StatusView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Estado").font(.largeTitle.bold())
            if let u = e.availableUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hay una versión nueva de ClamMac: \(u.version)").font(.headline)
                    if !u.notes.isEmpty { Text(u.notes).font(.callout).lineLimit(6) }
                    HStack {
                        Button(e.canSelfUpdate ? "Actualizar y reiniciar" : "Descargar e instalar") { Task { await e.installAppUpdate() } }.disabled(e.busy != nil)
                        Link("Ver en GitHub", destination: u.pageURL)
                    }
                    Text(e.canSelfUpdate ? "ClamMac se cerrará y volverá a abrirse sola en unos segundos. No tienes que hacer nada más."
                                         : "Esta copia no puede actualizarse sola: se abrirá el instalador y deberás arrastrar la app a Aplicaciones.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            if !e.engineInstalled { Banner(text: "ClamAV no está instalado. En Terminal: brew install clamav", color: .red) }
            if !e.hasFullDiskAccess {
                Banner(text: "Falta Acceso total al disco: macOS ocultará ficheros al análisis. Ajustes del Sistema → Privacidad y seguridad → Acceso total al disco → añade ClamMac.", color: .orange)
                Button("Abrir ajustes de privacidad") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
            }
            Row("Vigilancia", e.settings.realtimeEnabled ? "Activa (\(e.settings.watchedFolders.filter(\.enabled).count) carpeta(s))" : "Desactivada")
            Row("Motor", e.daemonReady ? "clamd en marcha (rápido)" : "clamscan bajo demanda")
            Row("Firmas", e.dbInfo.map { "v\($0.signatureVersion) · \($0.displayDate)" } ?? "—")
            Row("Actualización", e.settings.updateMode == .automatic ? "Automática cada \(e.settings.updateIntervalHours) h" : "Manual")
            Row("En cuarentena", "\(e.quarantined.count) elemento(s)")
            if let b = e.busy { HStack { ProgressView().controlSize(.small); Text(b) } }
            HStack {
                Button("Análisis rápido") { Task { await e.quickScan() } }.disabled(e.busy != nil)
                Button("Actualizar firmas") { Task { await e.updateSignatures() } }.disabled(e.busy != nil)
            }
        }
    }
}

struct WatchView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vigilancia de carpetas").font(.largeTitle.bold())
            Toggle("Analizar automáticamente lo que entra en estas carpetas", isOn: $e.settings.realtimeEnabled).toggleStyle(.switch)
            Text("Cada fichero nuevo o modificado se analiza cuando termina de escribirse. Las descargas a medias (.download, .crdownload…) se esperan.")
                .font(.callout).foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading) {
                    ForEach($e.settings.watchedFolders) { $f in
                        HStack {
                            Toggle("", isOn: $f.enabled).labelsHidden()
                            Text((f.path as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button { e.settings.watchedFolders.removeAll { $0.path == f.path } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
                        }
                    }
                    if e.settings.watchedFolders.isEmpty { Text("Ninguna carpeta").foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }
            Button("Añadir carpeta…") {
                if let p = pickFolder(), !e.settings.watchedFolders.contains(where: { $0.path == p }) {
                    e.settings.watchedFolders.append(WatchedFolder(path: p))
                }
            }
            Toggle("Mover amenazas a cuarentena automáticamente", isOn: $e.settings.autoQuarantine)
        }
    }
}

struct ScanView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Análisis").font(.largeTitle.bold())
            HStack {
                Button("Análisis rápido (Descargas, Escritorio, Documentos)") { Task { await e.quickScan() } }
                Button("Elegir carpeta…") { if let p = pickFolder() { Task { await e.scan(folders: [p]) } } }
            }.disabled(e.busy != nil)
            if let b = e.busy { HStack { ProgressView().controlSize(.small); Text(b) } }
            if let r = e.lastReport {
                GroupBox("Último análisis") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(r.scannedFiles) ficheros analizados")
                        if r.permissionDenied > 0 { Text("\(r.permissionDenied) sin permiso de lectura").foregroundStyle(.orange) }
                        if r.threats.isEmpty { Label("Sin amenazas", systemImage: "checkmark.circle").foregroundStyle(.green) }
                        ForEach(r.threats) { t in Label("\((t.path as NSString).lastPathComponent) — \(t.signature)", systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
            }
            Divider()
            Text("Análisis programado").font(.title3.bold())
            Toggle("Activar", isOn: $e.settings.scheduledScan.enabled)
            if e.settings.scheduledScan.enabled {
                HStack {
                    Picker("Día", selection: $e.settings.scheduledScan.weekday) {
                        ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1].capitalized).tag($0) }
                    }.frame(width: 220)
                    Stepper("Hora: \(String(format: "%02d:%02d", e.settings.scheduledScan.hour, e.settings.scheduledScan.minute))",
                            value: $e.settings.scheduledScan.hour, in: 0...23)
                }
                Text("Carpetas: " + e.settings.scheduledScan.folders.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                Text("Antes de analizar se actualizan las firmas.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct QuarantineView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Cuarentena").font(.largeTitle.bold())
            if e.quarantined.isEmpty { Text("Vacía").foregroundStyle(.secondary) }
            ForEach(e.quarantined) { i in
                GroupBox {
                    HStack {
                        VStack(alignment: .leading) {
                            Text((i.originalPath as NSString).lastPathComponent).bold()
                            Text("\(i.signature) · \(i.date.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                            Text(i.originalPath).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Button("Restaurar") { e.restore(i) }
                        Button("Eliminar", role: .destructive) { e.deleteQuarantined(i) }
                    }.padding(4)
                }
            }
        }
    }
}

struct SignaturesView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Biblioteca de amenazas").font(.largeTitle.bold())
            Row("Motor", e.dbInfo.map { "ClamAV \($0.version)" } ?? "—")
            Row("Versión de firmas", e.dbInfo?.signatureVersion ?? "—")
            Row("Fecha", e.dbInfo?.displayDate ?? "—")
            Row("Última comprobación", e.settings.lastUpdateCheck?.formatted(date: .abbreviated, time: .shortened) ?? "nunca")
            Picker("Actualización", selection: $e.settings.updateMode) {
                Text("Automática").tag(UpdateMode.automatic); Text("Manual").tag(UpdateMode.manual)
            }.pickerStyle(.segmented).frame(width: 300)
            if e.settings.updateMode == .automatic {
                Picker("Frecuencia", selection: $e.settings.updateIntervalHours) {
                    Text("Cada hora").tag(1); Text("Cada 4 horas").tag(4); Text("Cada 12 horas").tag(12)
                    Text("Diaria").tag(24); Text("Semanal").tag(168)
                }.frame(width: 300)
            }
            HStack {
                Button("Actualizar ahora") { Task { await e.updateSignatures() } }.disabled(e.busy != nil)
                if let b = e.busy { ProgressView().controlSize(.small); Text(b) }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var e: Engine
    @State private var token = Keychain.get(account: "pushover-token") ?? ""
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ajustes").font(.largeTitle.bold())
            Toggle("Abrir ClamMac al iniciar sesión", isOn: Binding(get: { e.launchAtLogin }, set: { e.launchAtLogin = $0 }))
            Toggle("Mantener clamd en marcha (análisis instantáneo, ~1 GB de RAM)", isOn: $e.settings.useDaemon)
            Toggle("Notificaciones del sistema", isOn: $e.settings.notificationsEnabled)
            Divider()
            Toggle("Avisos por Pushover", isOn: $e.settings.pushoverEnabled)
            if e.settings.pushoverEnabled {
                TextField("User key", text: $e.settings.pushoverUser).textFieldStyle(.roundedBorder).frame(width: 340)
                SecureField("App token (se guarda en el llavero)", text: $token).textFieldStyle(.roundedBorder).frame(width: 340)
                    .onChange(of: token) { _, v in Keychain.set(v, account: "pushover-token") }
            }
            Divider()
            Toggle("Buscar nuevas versiones de ClamMac en GitHub (una vez al día)", isOn: $e.settings.autoCheckAppUpdates)
            HStack {
                Button("Buscar actualizaciones ahora") { Task { await e.checkAppUpdate(manual: true) } }.disabled(e.busy != nil)
                Text("Versión instalada: \(e.currentVersion)").foregroundStyle(.secondary)
            }
            if let m = e.updateStatus { Text(m).font(.callout).foregroundStyle(.secondary) }
            Divider()
            Text("Datos: \(ClamPaths.appSupport.path)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}

struct LogView: View {
    @EnvironmentObject var e: Engine
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Registro").font(.largeTitle.bold())
            ForEach(e.log) { l in
                HStack(alignment: .top) {
                    Text(l.date.formatted(date: .omitted, time: .standard)).monospacedDigit().foregroundStyle(.secondary)
                    Text(l.text).foregroundStyle(l.isAlert ? Color.red : Color.primary)
                }.font(.callout)
            }
        }
    }
}

struct Row: View {
    let k: String, v: String
    init(_ k: String, _ v: String) { self.k = k; self.v = v }
    var body: some View { HStack { Text(k).foregroundStyle(.secondary).frame(width: 150, alignment: .leading); Text(v) } }
}

struct Banner: View {
    let text: String, color: Color
    var body: some View {
        Text(text).padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor func pickFolder() -> String? {
    let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false
    return p.runModal() == .OK ? p.url?.path : nil
}


// MARK: - Desarrollador / café
enum Dev {
    static let coffeeURL = URL(string: "https://buymeacoffee.com/angelbonet")!
    static let webURL = URL(string: "https://abdatabase.com")!
    static let author = "Ángel Bonet"
    static let company = "ABDatabase"
}

struct CoffeeLink: View {
    var body: some View {
        Link(destination: Dev.coffeeURL) {
            Label("Invita un café al desarrollador", systemImage: "cup.and.saucer.fill")
                .font(.callout).frame(maxWidth: .infinity)
                .padding(.vertical, 7).padding(.horizontal, 8)
                .foregroundStyle(Color.orange)
                .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("buymeacoffee.com/angelbonet")
    }
}

struct AboutView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Acerca de").font(.largeTitle.bold())
            HStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ClamMac").font(.title.bold())
                    Text("Versión \(version)").foregroundStyle(.secondary)
                    Text("Interfaz nativa para el antivirus ClamAV en macOS").font(.callout).foregroundStyle(.secondary)
                }
            }
            Divider()
            Text("Creado por \(Dev.author) · \(Dev.company)").font(.title3)
            Text("ClamMac es gratuito. Si te resulta útil y quieres apoyar su desarrollo, puedes invitarme a un café.")
                .foregroundStyle(.secondary)
            HStack {
                CoffeeLink().frame(width: 300)
                Link(destination: Dev.webURL) { Label("abdatabase.com", systemImage: "globe") }
            }
            Divider()
            Text("ClamAV® es una marca de Cisco Systems. ClamMac no está afiliado a Cisco ni a Apple.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
