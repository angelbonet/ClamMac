import Foundation

/// Sustituye la app en ejecución por la versión nueva sin intervención del usuario:
/// prepara y verifica la app nueva, y un script ayudante (independiente del proceso) espera a que
/// ClamMac se cierre, intercambia las carpetas .app (con marcha atrás si algo falla) y la vuelve a abrir.
public enum SelfUpdater {
    public static let bundleID = "com.abdatabase.clammac"

    /// ¿Puede la app sustituirse a sí misma en su ubicación actual?
    public static func canReplace(appURL: URL) -> Bool {
        let p = appURL.path
        guard appURL.pathExtension == "app",
              !p.contains("/AppTranslocation/"), !p.hasPrefix("/Volumes/") else { return false }
        return FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path)
    }

    /// Monta el DMG, copia la app a una carpeta temporal, lo desmonta y verifica la copia.
    public static func prepareNewApp(from dmg: URL, expectedVersion: String) async throws -> URL {
        let work = ClamPaths.appSupport.appendingPathComponent("Updates", isDirectory: true)
        let mnt = work.appendingPathComponent("mnt-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: mnt, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mnt) }

        let att = await Shell.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mnt.path, dmg.path])
        guard att.status == 0 else { throw UpdateError.installFailed("no se pudo abrir el DMG: \(att.stderr)") }
        let newApp = work.appendingPathComponent("ClamMac-new.app")
        try? FileManager.default.removeItem(at: newApp)
        let src = mnt.appendingPathComponent("ClamMac.app")
        guard FileManager.default.fileExists(atPath: src.path) else {
            _ = await Shell.run("/usr/bin/hdiutil", ["detach", "-force", mnt.path]); throw UpdateError.installFailed("el DMG no contiene ClamMac.app")
        }
        let cp = await Shell.run("/usr/bin/ditto", [src.path, newApp.path])
        _ = await Shell.run("/usr/bin/hdiutil", ["detach", "-force", mnt.path])
        guard cp.status == 0 else { throw UpdateError.installFailed("no se pudo copiar la app nueva: \(cp.stderr)") }

        try await verifyApp(newApp, expectedVersion: expectedVersion)
        return newApp
    }

    static func verifyApp(_ app: URL, expectedVersion: String) async throws {
        func fail(_ m: String) -> UpdateError { try? FileManager.default.removeItem(at: app); return .badSignature(m) }
        let cs = await Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        guard cs.status == 0 else { throw fail("la firma de la app nueva no es válida") }
        let info = await Shell.run("/usr/bin/codesign", ["-dvv", app.path])
        guard (info.stdout + info.stderr).contains("TeamIdentifier=\(UpdateChecker.expectedTeamID)") else { throw fail("la app nueva no es del desarrollador esperado") }
        let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard plist?["CFBundleIdentifier"] as? String == bundleID else { throw fail("identificador de app inesperado") }
        guard plist?["CFBundleShortVersionString"] as? String == expectedVersion else { throw fail("la versión de la app no coincide con la release") }
        let gk = await Shell.run("/usr/sbin/spctl", ["-a", "-t", "exec", app.path])
        guard gk.status == 0 else { throw fail("Gatekeeper no acepta la app nueva (¿sin notarizar?)") }
    }

    /// Script ayudante (sh). Argumentos: PID NUEVA DESTINO LOG. Variables: VERIFY=0 / OPEN=0 solo para pruebas.
    static let helperScript = #"""
    #!/bin/sh
    PID="$1"; NEW="$2"; DEST="$3"; LOG="$4"
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
    reopen() { [ "$OPEN" = "0" ] || /usr/bin/open "$DEST"; }
    i=0
    while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 120 ]; do sleep 0.5; i=$((i+1)); done
    if kill -0 "$PID" 2>/dev/null; then log "ClamMac no se cerró a tiempo; actualización cancelada"; exit 1; fi
    BACKUP="$DEST.previous"
    rm -rf "$BACKUP"
    if ! mv "$DEST" "$BACKUP"; then log "no se pudo apartar la app actual; actualización cancelada"; reopen; exit 1; fi
    if /usr/bin/ditto "$NEW" "$DEST" && { [ "$VERIFY" = "0" ] || /usr/bin/codesign --verify --deep --strict "$DEST"; }; then
      log "actualización instalada"
      rm -rf "$BACKUP" "$NEW"
    else
      log "la copia falló; restaurando la versión anterior"
      rm -rf "$DEST"; mv "$BACKUP" "$DEST"
    fi
    reopen
    """#

    /// Lanza el ayudante desacoplado de ClamMac (sobrevive al cierre de la app).
    @discardableResult
    public static func launchHelper(pid: Int32 = ProcessInfo.processInfo.processIdentifier, newApp: URL, dest: URL, noRelaunch: Bool = false) throws -> URL {
        let dir = ClamPaths.appSupport.appendingPathComponent("Updates", isDirectory: true)
        let script = dir.appendingPathComponent("apply-update.sh")
        let log = ClamPaths.appSupport.appendingPathComponent("update.log")
        try helperScript.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let env = noRelaunch ? "OPEN=0 " : ""
        let cmd = "\(env)nohup /bin/sh \(q(script.path)) \(pid) \(q(newApp.path)) \(q(dest.path)) \(q(log.path)) >/dev/null 2>&1 &"
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = ["-c", cmd]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); p.waitUntilExit()
        return log
    }
}
