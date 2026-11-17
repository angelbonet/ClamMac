import Foundation

/// Localiza los binarios de ClamAV (Homebrew Apple Silicon o Intel) y las rutas de datos de la app.
public enum ClamPaths {
    public static let prefixes = ["/opt/homebrew", "/usr/local"]

    public static func binary(_ name: String) -> String? {
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

    /// Directorio de firmas de Homebrew (se reutiliza, no se duplica).
    public static var databaseDir: String {
        for p in prefixes {
            let d = "\(p)/var/lib/clamav"
            if FileManager.default.fileExists(atPath: d) { return d }
        }
        return "/opt/homebrew/var/lib/clamav"
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
