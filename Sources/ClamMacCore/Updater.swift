import Foundation

public struct DatabaseInfo: Sendable, Equatable {
    public var version: String      // p.ej. "1.5.4"
    public var signatureVersion: String   // p.ej. "28182"
    public var date: String         // texto tal cual lo da ClamAV

    /// Fecha de las firmas en el idioma del sistema; si no se puede interpretar, el texto original.
    public var displayDate: String {
        let p = DateFormatter()
        p.locale = Locale(identifier: "en_US_POSIX"); p.timeZone = .current   // clamscan imprime la hora en local (ctime)
        p.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        guard let d = p.date(from: date) else { return date }
        let o = DateFormatter(); o.locale = Locale.current; o.dateStyle = .medium; o.timeStyle = .short
        return o.string(from: d)
    }
}

public struct UpdateResult: Sendable {
    public let ok: Bool
    public let updated: Bool
    public let message: String
}

public enum Updater {
    /// Ejecuta freshclam. `updated` es true si bajó firmas nuevas.
    public static func updateNow() async -> UpdateResult {
        guard let bin = ClamPaths.freshclam else {
            return UpdateResult(ok: false, updated: false, message: "freshclam no encontrado (brew install clamav)")
        }
        var args: [String] = []
        for p in ClamPaths.prefixes {
            let conf = "\(p)/etc/clamav/freshclam.conf"
            if FileManager.default.fileExists(atPath: conf) { args.append("--config-file=\(conf)"); break }
        }
        let res = await Shell.run(bin, args, timeout: 600)
        let text = res.stdout + res.stderr
        let ok = res.status == 0
        let updated = ok && text.contains("updated (version")
        let msg: String
        if !ok { msg = text.split(separator: "\n").suffix(3).joined(separator: " ") }
        else if updated { msg = "Firmas actualizadas" }
        else { msg = "Las firmas ya estaban al día" }
        return UpdateResult(ok: ok, updated: updated, message: msg)
    }

    /// Lee versión del motor y de las firmas con `clamscan --version`.
    public static func databaseInfo() async -> DatabaseInfo? {
        guard let bin = ClamPaths.clamscan else { return nil }
        let res = await Shell.run(bin, ["--version", "--database=\(ClamPaths.databaseDir)"])
        return parseVersion(res.stdout)
    }

    public static func parseVersion(_ s: String) -> DatabaseInfo? {
        // "ClamAV 1.5.4/28182/Fri Nov 13 07:24:28 2026"
        let line = s.split(separator: "\n").first.map(String.init) ?? s
        guard line.hasPrefix("ClamAV ") else { return nil }
        let parts = line.dropFirst(7).split(separator: "/", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return DatabaseInfo(version: parts.first ?? "?", signatureVersion: "?", date: "?") }
        return DatabaseInfo(version: parts[0], signatureVersion: parts[1], date: parts[2])
    }
}
