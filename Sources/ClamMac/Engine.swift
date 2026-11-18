import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement
import ClamMacCore

enum SelfTest: Equatable {
    case idle, running
    case passed(String), warning(String), failed(String)
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
    var isAlert = false
}

@MainActor
final class Engine: ObservableObject {
    @Published var settings: AppSettings { didSet { if settings != oldValue { settingsChanged(old: oldValue) } } }
    @Published var dbInfo: DatabaseInfo?
    @Published var log: [LogEntry] = []
    @Published var quarantined: [QuarantineItem] = []
    @Published var busy: String?            // "Analizando…", "Actualizando firmas…"
    @Published var daemonReady = false
    @Published var lastReport: ScanReport?
    @Published var hasFullDiskAccess = true
    @Published var engineInstalled = ClamPaths.clamscan != nil
    @Published var selfTest: SelfTest = .idle
    @Published var hasSignatures = ClamPaths.hasDatabase
    @Published var installingEngine = false
    @Published var engineInstallError: String?
    @Published var hasBrew = ClamPaths.brew != nil
    private var engineWatch: Timer?
    @Published var availableUpdate: ReleaseInfo?
    @Published var updateStatus: String?     // mensaje de la última búsqueda de versiones

    let daemon = ClamdManager()
    let quarantine = Quarantine()
    lazy var scanner = Scanner(daemon: daemon)
    private var watcher: FolderWatcher?
    private var ticker: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var lastScheduledMinute = ""
    private var testDetections = Set<String>()      // ficheros de prueba EICAR ya detectados (para la autoprueba)

    init() {
        settings = AppSettings.load()
        refreshQuarantine()
        checkFullDiskAccess()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.shutdown()
        }
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { [weak self] in self?.shutdown(); exit(0) }
            src.resume()
            signalSources.append(src)
        }
        Task { await start() }
    }

    // MARK: arranque
    func start() async {
        guard engineInstalled else {
            add(tr("ClamAV no está instalado: ClamMac no protege hasta instalarlo"), alert: true)
            watchForEngine(); return
        }
        noteVersionChange()
        if !ClamPaths.hasDatabase {          // primera vez con el motor incluido: descarga de firmas antes de arrancar
            add(tr("Primera ejecución: preparando las firmas de ClamAV (puede tardar unos minutos)…"))
            await updateSignatures()
        }
        hasSignatures = ClamPaths.hasDatabase
        dbInfo = await Updater.databaseInfo()
        if settings.useDaemon { await startDaemon() }
        applyWatcher()
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.minuteTick() }
        }
        minuteTick()
        add(tr("ClamMac %@ iniciado", currentVersion))
        if ProcessInfo.processInfo.environment["CLAMMAC_AUTOSELFTEST"] == "1" {      // solo pruebas
            await runSelfTest(); add("AUTOSELFTEST: \(selfTest)"); shutdown(); NSApp.terminate(nil)
        }
    }

    /// Mientras falte ClamAV, comprueba cada 3 s si ya está (instalado por la app o a mano) y arranca la protección.
    private func watchForEngine() {
        engineWatch?.invalidate()
        engineWatch = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { return }
                self.hasBrew = ClamPaths.brew != nil
                guard ClamPaths.clamscan != nil, !self.installingEngine else { return }
                t.invalidate(); self.engineWatch = nil
                self.engineInstalled = true
                self.add(tr("ClamAV detectado: arrancando la protección"))
                await self.start()
                await self.updateSignatures()
            }
        }
    }

    /// Instala ClamAV con Homebrew sin que el usuario tenga que abrir Terminal.
    func installEngine() async {
        guard let brew = ClamPaths.brew, !installingEngine else { return }
        installingEngine = true; engineInstallError = nil
        add(tr("Instalando ClamAV con Homebrew (puede tardar unos minutos)…"))
        let cmd = "export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_AUTO_UPDATE=1; '\(brew)' install clamav"
        let r = await Shell.run("/bin/bash", ["-c", cmd], timeout: 1800)
        installingEngine = false
        if r.status == 0, ClamPaths.clamscan != nil {
            add(tr("ClamAV instalado correctamente"))
            // el temporizador de vigilancia lo detecta y arranca; si no estaba activo, lo forzamos
            if engineWatch == nil { engineInstalled = true; await start(); await updateSignatures() }
        } else {
            let tail = (r.stdout + r.stderr).split(separator: "\n").suffix(3).joined(separator: " ")
            engineInstallError = tr("No se pudo instalar ClamAV. %@", tail)
            add(engineInstallError!, alert: true)
        }
    }

    func startDaemon() async {
        daemon.start()
        daemonReady = await daemon.waitUntilReady()
        add(daemonReady ? tr("clamd listo (análisis instantáneo)") : tr("clamd no arrancó; se usará clamscan"), alert: !daemonReady)
    }

    private func settingsChanged(old: AppSettings) {
        settings.save()
        if old.watchedFolders != settings.watchedFolders || old.realtimeEnabled != settings.realtimeEnabled
            || old.excludeExtensions != settings.excludeExtensions { applyWatcher() }
        if old.useDaemon != settings.useDaemon {
            if settings.useDaemon { Task { await startDaemon() } } else { daemon.stop(); daemonReady = false }
        }
        if old.pushoverEnabled != settings.pushoverEnabled && settings.pushoverEnabled { requestNotificationAuth() }
    }

    // MARK: vigilancia
    func applyWatcher() {
        watcher?.stop(); watcher = nil
        guard settings.realtimeEnabled else { add(tr("Vigilancia desactivada")); return }
        let paths = settings.watchedFolders.filter(\.enabled).map(\.path)
        guard !paths.isEmpty else { return }
        let w = FolderWatcher(excludeExtensions: settings.excludeExtensions) { [weak self] files in
            Task { @MainActor in await self?.handleNewFiles(files) }
        }
        w.start(paths: paths)
        watcher = w
        add(tr("Vigilando: %@", paths.map { ($0 as NSString).abbreviatingWithTildeInPath }.joined(separator: ", ")))
    }

    func handleNewFiles(_ files: [String]) async {
        let report = await scanner.scan(files: files)
        if let e = report.engineError { add(tr("Error del motor: %@", e), alert: true); return }
        if report.permissionDenied > 0 { checkFullDiskAccess(); add(tr("%ld fichero(s) sin permiso de lectura", report.permissionDenied), alert: true) }
        if report.threats.isEmpty {
            add(tr("Analizado: %@", files.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")))
        } else { await handleThreats(report.threats) }
    }

    private func handleThreats(_ threats: [Threat]) async {
        for t in threats {
            var action = tr("sin mover")
            if settings.autoQuarantine {
                do { try quarantine.add(path: t.path, signature: t.signature); action = tr("enviado a cuarentena") }
                catch { action = tr("no se pudo mover a cuarentena: %@", error.localizedDescription) }
            }
            let name = (t.path as NSString).lastPathComponent
            if TestFile.isTestFile(path: t.path) { testDetections.insert(name); add(tr("PRUEBA: detectado %@ en %@ — %@", t.signature, name, action)); continue }
            add(tr("AMENAZA %@ en %@ — %@", t.signature, name, action), alert: true)
            notify(title: tr("Amenaza detectada"), body: "\(name): \(t.signature) (\(action))")
        }
        refreshQuarantine()
    }

    // MARK: análisis bajo demanda
    func quickScan() async {
        let folders = ["~/Downloads", "~/Desktop", "~/Documents"]
        await scan(folders: folders)
    }

    func scan(folders: [String]) async {
        guard busy == nil else { return }
        busy = tr("Analizando…")
        add(tr("Análisis iniciado: %@", folders.joined(separator: ", ")))
        let r = await scanner.scan(folders: folders)
        busy = nil
        lastReport = r
        if let e = r.engineError { add(tr("Error del motor: %@", e), alert: true); return }
        if r.permissionDenied > 0 { checkFullDiskAccess() }
        add(tr("Análisis terminado: %ld ficheros, %ld amenaza(s)", r.scannedFiles, r.threats.count)
            + (r.permissionDenied > 0 ? tr(", %ld sin permiso", r.permissionDenied) : ""), alert: !r.clean)
        if !r.threats.isEmpty { await handleThreats(r.threats) }
        else if settings.notificationsEnabled { notify(title: tr("Análisis terminado"), body: tr("%ld ficheros, sin amenazas", r.scannedFiles)) }
    }

    // MARK: firmas
    func updateSignatures() async {
        guard busy == nil else { return }
        busy = tr("Actualizando firmas…")
        let r = await Updater.updateNow()
        busy = nil
        settings.lastUpdateCheck = Date()
        add(tr("Firmas: %@", r.message), alert: !r.ok)
        if r.updated { daemon.reload() }
        hasSignatures = ClamPaths.hasDatabase
        dbInfo = await Updater.databaseInfo()
    }

    private func minuteTick() {
        // actualización automática
        if settings.updateMode == .automatic, busy == nil {
            let due = settings.lastUpdateCheck.map { Date().timeIntervalSince($0) >= Double(settings.updateIntervalHours) * 3600 } ?? true
            if due { Task { await updateSignatures() } }
        }
        // actualizaciones de la propia app: como mucho una vez al día
        if settings.autoCheckAppUpdates {
            let due = settings.lastAppUpdateCheck.map { Date().timeIntervalSince($0) >= 24 * 3600 } ?? true
            if due { Task { await checkAppUpdate() } }
        }
        // análisis programado
        let s = settings.scheduledScan
        if s.enabled {
            let c = Calendar.current, now = Date()
            let comps = c.dateComponents([.weekday, .hour, .minute], from: now)
            let key = "\(c.ordinality(of: .day, in: .era, for: now) ?? 0)-\(comps.hour ?? 0)-\(comps.minute ?? 0)"
            if comps.weekday == s.weekday, comps.hour == s.hour, comps.minute == s.minute, key != lastScheduledMinute {
                lastScheduledMinute = key
                Task { await updateSignatures(); await scan(folders: s.folders) }
            }
        }
    }

    // MARK: autoprueba (fichero EICAR)
    /// Crea un fichero EICAR en una carpeta vigilada y comprueba que ClamMac lo detecta y lo aparta.
    func runSelfTest() async {
        guard selfTest != .running, busy == nil else { return }
        selfTest = .running
        add(tr("Prueba de protección iniciada"))
        let folder = settings.realtimeEnabled
            ? settings.watchedFolders.first(where: { $0.enabled && FileManager.default.fileExists(atPath: $0.path) })?.path : nil
        guard let folder else {
            // Sin vigilancia: solo se puede probar el motor, no la protección automática.
            let tmp = FileManager.default.temporaryDirectory.path
            guard let p = try? TestFile.create(in: tmp) else { selfTest = .failed(tr("No se pudo crear el fichero de prueba.")); return }
            defer { try? FileManager.default.removeItem(atPath: p) }
            let r = await scanner.scan(files: [p])
            if let e = r.engineError { selfTest = .failed(tr("Error del motor: %@", e)) }
            else if r.threats.isEmpty { selfTest = .failed(tr("El motor NO detectó el fichero de prueba. Actualiza las firmas y reinstala ClamAV.")) }
            else { selfTest = .warning(tr("El motor detecta amenazas, pero la vigilancia de carpetas está desactivada: no se protegería automáticamente. Actívala en Vigilancia.")) }
            add("Prueba de protección: \(selfTest)")
            return
        }
        let path: String
        do { path = try TestFile.create(in: folder) } catch {
            selfTest = .failed(tr("No se pudo crear el fichero de prueba en %@: %@", (folder as NSString).abbreviatingWithTildeInPath, error.localizedDescription)); return
        }
        let name = (path as NSString).lastPathComponent
        for _ in 0..<40 {                                     // hasta ~40 s
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let item = quarantine.list().first { ($0.originalPath as NSString).lastPathComponent == name }
            let gone = !FileManager.default.fileExists(atPath: path)
            if let item {                                      // detectado y apartado: limpiar la prueba
                try? quarantine.delete(item); refreshQuarantine()
                selfTest = .passed(tr("Todo funciona: ClamMac detectó el fichero de prueba en %@ y lo apartó a cuarentena.", (folder as NSString).abbreviatingWithTildeInPath))
                add(tr("Prueba de protección superada")); return
            }
            if gone && !settings.autoQuarantine { break }      // alguien lo borró: no se puede concluir nada
            if !settings.autoQuarantine, testDetections.contains(name) {
                try? FileManager.default.removeItem(atPath: path)
                selfTest = .passed(tr("Todo funciona: ClamMac detectó el fichero de prueba. (La cuarentena automática está desactivada, por eso solo se avisa.)"))
                add(tr("Prueba de protección superada")); return
            }
        }
        try? FileManager.default.removeItem(atPath: path)
        selfTest = .failed(tr("ClamMac no detectó el fichero de prueba en 40 s. Revisa: 1) el permiso de Acceso total al disco, 2) que la carpeta esté vigilada y activada, 3) que las firmas estén descargadas."))
        add(tr("Prueba de protección FALLIDA"), alert: true)
    }

    // MARK: cuarentena
    func refreshQuarantine() { quarantined = quarantine.list() }
    func restore(_ i: QuarantineItem) { do { let p = try quarantine.restore(i); add(tr("Restaurado: %@", p)) } catch { add(tr("No se pudo restaurar: %@", error.localizedDescription), alert: true) }; refreshQuarantine() }
    func deleteQuarantined(_ i: QuarantineItem) { do { try quarantine.delete(i); add(tr("Eliminado de cuarentena: %@", (i.originalPath as NSString).lastPathComponent)) } catch { add(tr("No se pudo eliminar: %@", error.localizedDescription), alert: true) }; refreshQuarantine() }

    // MARK: sistema
    func checkFullDiskAccess() {
        // ~/Library/Safari solo es legible con Acceso total al disco
        let p = NSHomeDirectory() + "/Library/Safari"
        hasFullDiskAccess = (try? FileManager.default.contentsOfDirectory(atPath: p)) != nil
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do { if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
            catch { add(tr("Inicio automático: %@", error.localizedDescription), alert: true) }
            objectWillChange.send()
        }
    }

    func requestNotificationAuth() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String) {
        guard settings.notificationsEnabled else { return }
        if Bundle.main.bundleIdentifier != nil {
            let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
        }
        if settings.pushoverEnabled, let token = Keychain.get(account: "pushover-token") {
            let user = settings.pushoverUser, host = Host.current().localizedName ?? "Mac"
            Task.detached { await Pushover.send(title: "ClamMac · \(host): \(title)", message: body, user: user, token: token) }
        }
    }

    func add(_ text: String, alert: Bool = false) {
        log.insert(LogEntry(text: text, isAlert: alert), at: 0)
        if log.count > 500 { log.removeLast(log.count - 500) }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(alert ? "!" : " ") \(text)\n"
        if let h = try? FileHandle(forWritingTo: ClamPaths.logFile) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? line.write(to: ClamPaths.logFile, atomically: true, encoding: .utf8) }
    }

    /// Tras una actualización avisa («ClamMac se ha actualizado a X»). Ignora la versión simulada de pruebas.
    private func noteVersionChange() {
        guard ProcessInfo.processInfo.environment["CLAMMAC_FAKE_VERSION"] == nil else { return }
        let now = currentVersion
        if let last = settings.lastRunVersion, UpdateChecker.isNewer(now, than: last) {
            add(tr("ClamMac se ha actualizado de %@ a %@", last, now))
            notify(title: tr("ClamMac actualizada"), body: tr("Ahora usas la versión %@. La protección está activa.", now))
        }
        if settings.lastRunVersion != now { settings.lastRunVersion = now }
    }

    // MARK: actualizaciones de la app (GitHub)
    var currentVersion: String {
        ProcessInfo.processInfo.environment["CLAMMAC_FAKE_VERSION"]      // solo para pruebas
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    func checkAppUpdate(manual: Bool = false) async {
        guard busy == nil || manual else { return }
        do {
            let rel = try await UpdateChecker.check(current: currentVersion)
            settings.lastAppUpdateCheck = Date()
            availableUpdate = rel
            if let r = rel {
                updateStatus = tr("Hay una versión nueva: %@", r.version)
                add(tr("Nueva versión de ClamMac disponible: %@", r.version))
                notify(title: tr("ClamMac %@ disponible", r.version), body: tr("Ábrelo para actualizarla con un clic."))
                if ProcessInfo.processInfo.environment["CLAMMAC_AUTOINSTALL"] == "1" { await installAppUpdate() }   // solo pruebas
            } else { updateStatus = tr("ClamMac %@ está al día", currentVersion); if manual { add(updateStatus!) } }
        } catch { updateStatus = error.localizedDescription; if manual { add(error.localizedDescription, alert: true) } }
    }

    /// true si la app puede sustituirse a sí misma (instalada en /Applications u otra carpeta con permiso).
    var canSelfUpdate: Bool { SelfUpdater.canReplace(appURL: Bundle.main.bundleURL) }

    func installAppUpdate() async {
        guard let rel = availableUpdate, busy == nil else { return }
        busy = tr("Descargando ClamMac %@…", rel.version)
        do {
            let dmg = try await UpdateChecker.downloadAndVerify(rel)
            if canSelfUpdate {
                busy = tr("Preparando la actualización…")
                let newApp = try await SelfUpdater.prepareNewApp(from: dmg, expectedVersion: rel.version)
                try? FileManager.default.removeItem(at: dmg)
                add(tr("ClamMac %@ verificada. Se reiniciará sola en unos segundos.", rel.version))
                let noRelaunch = ProcessInfo.processInfo.environment["CLAMMAC_UPDATE_NO_RELAUNCH"] == "1"   // solo pruebas
                try SelfUpdater.launchHelper(newApp: newApp, dest: Bundle.main.bundleURL, noRelaunch: noRelaunch)
                shutdown()
                NSApp.terminate(nil)
                return
            }
            // Ubicación sin permiso de escritura (p. ej. ejecutada desde el DMG): se abre el DMG y se explica el paso manual.
            add(tr("ClamMac %@ descargada y verificada. Cierra ClamMac (menú del escudo › Salir), arrastra la app nueva a Aplicaciones y ábrela.", rel.version), alert: true)
            notify(title: tr("Actualización lista"), body: tr("Cierra ClamMac, arrastra la app nueva a Aplicaciones y ábrela."))
            NSWorkspace.shared.open(dmg)
        } catch { add(error.localizedDescription, alert: true); updateStatus = error.localizedDescription }
        busy = nil
    }

    func shutdown() { watcher?.stop(); daemon.stop() }

    /// Reinicia la app (p. ej. tras cambiar de idioma): un proceso aparte la vuelve a abrir cuando esta se cierra.
    func relaunch() {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", Bundle.main.bundleURL.path]
        try? p.run()
        shutdown(); NSApp.terminate(nil)
    }
}
