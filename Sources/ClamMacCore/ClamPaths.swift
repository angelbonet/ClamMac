import Foundation

/// Localiza los binarios de ClamAV (Homebrew Apple Silicon o Intel) y las rutas de datos de la app.
public enum ClamPaths {
    public static let prefixes = ["/opt/homebrew", "/usr/local"]

    /// Motor ClamAV incluido dentro de la app (Contents/Helpers). `CLAMMAC_ENGINE_DIR` lo fuerza en pruebas.
    public static var bundledDir: String? {
        let candidates: [String] = [
            ProcessInfo.processInfo.environment["CLAMMAC_ENGINE_DIR"],
            Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers").path
        ].compactMap { $0 }.filter { !$0.isEmpty }
        return candidates.first { FileManager.default.isExecutableFile(atPath: "\($0)/clamscan") }
    }
    public static var usingBundledEngine: Bool { bundledDir != nil }

    /// Certificado raíz con el que ClamAV 1.5 verifica las firmas digitales de las bases (.cvd.sign).
    /// El motor incluido lo trae en Contents/Resources/certs; sin esto muestra «NULL X509 store» y no verifica.
    public static var certsArgs: [String] {
        guard let b = bundledDir else { return [] }
        for d in ["\(b)/../Resources/certs", "\(b)/certs"] where FileManager.default.fileExists(atPath: "\(d)/clamav.crt") {
            return ["--cvdcertsdir=\((d as NSString).standardizingPath)"]
        }
        return []
    }

    public static func binary(_ name: String) -> String? {
        if let b = bundledDir {
            let path = "\(b)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        for p in prefixes {
            for sub in ["bin", "sbin"] {
                let path = "\(p)/\(sub)/\(name)"
                if FileManager.default.isExecutableFile(atPath: path) { return path }
            }
        }
        return nil
    }

    public static var clamscan: String? { binary("clamscan") }
    public static var clamdscan: String? { binary("clamdscan") }
    public static var clamd: String? { binary("clamd") }
    public static var freshclam: String? { binary("freshclam") }
    public static var brew: String? { binary("brew") }

    /// Tras `brew install clamav` solo existe freshclam.conf.sample: crea el .conf (quitando la línea «Example»).
    public static func ensureFreshclamConf() {
        for p in prefixes {
            let dir = "\(p)/etc/clamav"
            let conf = "\(dir)/freshclam.conf", sample = conf + ".sample"
            guard !FileManager.default.fileExists(atPath: conf),
                  let text = try? String(contentsOfFile: sample, encoding: .utf8) else { continue }
            let out = text.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.trimmingCharacters(in: .whitespaces) != "Example" }.joined(separator: "\n")
            try? out.write(toFile: conf, atomically: true, encoding: .utf8)
        }
    }

    /// Directorio de firmas de Homebrew (se reutiliza, no se duplica).
    public static var databaseDir: String {
        if usingBundledEngine {                       // motor propio → firmas propias (sin depender de Homebrew)
            let d = appSupport.appendingPathComponent("Database", isDirectory: true)
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            return d.path
        }
        for p in prefixes {
            let d = "\(p)/var/lib/clamav"
            if FileManager.default.fileExists(atPath: d) { return d }
        }
        return "/opt/homebrew/var/lib/clamav"
    }

    /// ¿Hay ya una base de firmas utilizable?
    public static var hasDatabase: Bool {
        let fm = FileManager.default, d = databaseDir
        return ["main", "daily"].allSatisfy { fm.fileExists(atPath: "\(d)/\($0).cvd") || fm.fileExists(atPath: "\(d)/\($0).cld") }
    }

    /// Primera vez con motor propio: si Homebrew ya tiene firmas, se copian para no descargar ~300 MB de nuevo.
    public static func seedDatabaseFromHomebrew() {
        guard usingBundledEngine, !hasDatabase else { return }
        let fm = FileManager.default
        for p in prefixes {
            let src = "\(p)/var/lib/clamav"
            guard let files = try? fm.contentsOfDirectory(atPath: src) else { continue }
            for f in files where f.hasSuffix(".cvd") || f.hasSuffix(".cld") {
                try? fm.copyItem(atPath: "\(src)/\(f)", toPath: "\(databaseDir)/\(f)")
            }
            if hasDatabase { return }
        }
    }

    /// Espejo de firmas de abDatabase (cvdupdate): una sola petición al CDN de ClamAV para todas las clínicas.
    public static let defaultMirror = "https://clamav.abdatabase.com"

    /// freshclam.conf propio de la app (el motor incluido no trae ninguno): descarga directa del CDN oficial.
    public static var freshclamConf: URL { appSupport.appendingPathComponent("freshclam.conf") }
    public static func writeFreshclamConf() {
        let text = "DatabaseDirectory \(databaseDir)\nDatabaseMirror database.clamav.net\nCompressLocalDatabase no\n"
        if (try? String(contentsOf: freshclamConf, encoding: .utf8)) != text { try? text.write(to: freshclamConf, atomically: true, encoding: .utf8) }
    }

    /// freshclam.dat guarda el cool-down del CDN oficial. Se aparta (renombrándolo) antes de usar el espejo.
    public static var freshclamState: URL { URL(fileURLWithPath: databaseDir).appendingPathComponent("freshclam.dat") }
    public static func stashFreshclamState() -> URL? {
        let fm = FileManager.default, src = freshclamState, dst = src.appendingPathExtension("official")
        guard fm.fileExists(atPath: src.path) else { return nil }
        try? fm.removeItem(at: dst)
        do { try fm.moveItem(at: src, to: dst); return dst } catch { return nil }
    }
    /// Descarta el freshclam.dat que haya creado la ejecución contra el espejo y recupera el original.
    public static func restoreFreshclamState(_ stash: URL?) {
        let fm = FileManager.default
        try? fm.removeItem(at: freshclamState)
        if let stash, fm.fileExists(atPath: stash.path) { try? fm.moveItem(at: stash, to: freshclamState) }
    }

    /// freshclam.conf que descarga del espejo privado (sin consulta DNS al CDN oficial).
    public static var freshclamMirrorConf: URL { appSupport.appendingPathComponent("freshclam-mirror.conf") }
    public static func writeFreshclamMirrorConf(mirror: String = defaultMirror) {
        let text = "DatabaseDirectory \(databaseDir)\nPrivateMirror \(mirror)\nDNSDatabaseInfo no\nCompressLocalDatabase no\n"
        if (try? String(contentsOf: freshclamMirrorConf, encoding: .utf8)) != text { try? text.write(to: freshclamMirrorConf, atomically: true, encoding: .utf8) }
    }

    public static var appSupport: URL {
        // CLAMMAC_DATA_DIR: solo para pruebas aisladas (no toca los datos reales)
        let url: URL
        if let d = ProcessInfo.processInfo.environment["CLAMMAC_DATA_DIR"], !d.isEmpty {
            url = URL(fileURLWithPath: d, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            url = base.appendingPathComponent("ClamMac", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var quarantineDir: URL {
        let url = appSupport.appendingPathComponent("Quarantine", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return url
    }

    public static var settingsFile: URL { appSupport.appendingPathComponent("settings.json") }
    public static var logFile: URL { appSupport.appendingPathComponent("clammac.log") }
}
