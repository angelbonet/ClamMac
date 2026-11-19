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

/// Por qué falló una actualización de firmas (para explicarlo en pantalla en vez de dejar «v? · ?» sin más).
public enum UpdateFailure: Sendable, Equatable {
    /// El CDN de ClamAV ha limitado/bloqueado esta IP (429/403); freshclam no reintenta hasta `until`.
    case coolDown(until: Date?)
    /// Sin conexión con el servidor de firmas (DNS, firewall, proxy, TLS…).
    case network
    case other
}

public struct UpdateResult: Sendable {
    public let ok: Bool
    public let updated: Bool
    public let message: String
    public let failure: UpdateFailure?
    /// Salida de freshclam (últimas líneas) para el diagnóstico.
    public let detail: String
    public init(ok: Bool, updated: Bool, message: String, failure: UpdateFailure? = nil, detail: String = "") {
        self.ok = ok; self.updated = updated; self.message = message; self.failure = failure; self.detail = detail
    }
}

public enum Updater {
    /// Ejecuta freshclam. `updated` es true si bajó firmas nuevas.
    /// Con el motor incluido: primero el espejo de abDatabase (si `useMirror`) y, si falla, el CDN oficial,
    /// salvo que `officialBlockedUntil` esté en el futuro (cool-down): entonces no se vuelve a llamar al CDN.
    public static func updateNow(useMirror: Bool = true, officialBlockedUntil: Date? = nil) async -> UpdateResult {
        guard let bin = ClamPaths.freshclam else {
            return UpdateResult(ok: false, updated: false, message: tr("freshclam no encontrado (brew install clamav)"))
        }
        guard ClamPaths.usingBundledEngine else {            // motor de Homebrew: configuración de Homebrew, sin espejo
            ClamPaths.ensureFreshclamConf()
            var args: [String] = []
            for p in ClamPaths.prefixes {
                let conf = "\(p)/etc/clamav/freshclam.conf"
                if FileManager.default.fileExists(atPath: conf) { args.append("--config-file=\(conf)"); break }
            }
            return interpret(await Shell.run(bin, args + ClamPaths.certsArgs, timeout: 600))
        }
        ClamPaths.seedDatabaseFromHomebrew()
        var mirrorNote = ""
        if useMirror {
            ClamPaths.writeFreshclamMirrorConf()
            let r = interpret(await Shell.run(bin, ["--config-file=\(ClamPaths.freshclamMirrorConf.path)"] + ClamPaths.certsArgs, timeout: 600))
            if r.ok { return r }
            mirrorNote = "[espejo] " + r.detail + "\n"
        }
        if let until = officialBlockedUntil, until > Date() {
            return UpdateResult(ok: false, updated: false, message: failureMessage(.coolDown(until: until), raw: ""),
                                failure: .coolDown(until: until), detail: mirrorNote + "[cool-down hasta \(until)]")
        }
        ClamPaths.writeFreshclamConf()
        let r = interpret(await Shell.run(bin, ["--config-file=\(ClamPaths.freshclamConf.path)"] + ClamPaths.certsArgs, timeout: 600))
        return UpdateResult(ok: r.ok, updated: r.updated, message: r.message, failure: r.failure, detail: mirrorNote + "[oficial] " + r.detail)
    }

    /// Convierte la salida de freshclam en un resultado con el motivo del fallo.
    static func interpret(_ res: ShellResult) -> UpdateResult {
        let text = res.stdout + res.stderr
        let tail = text.split(separator: "\n").suffix(12).joined(separator: "\n")
        if res.status == 0 {
            let updated = text.contains("updated (version")
            return UpdateResult(ok: true, updated: updated, message: updated ? tr("Firmas actualizadas") : tr("Las firmas ya estaban al día"), detail: tail)
        }
        let f = classify(text)
        return UpdateResult(ok: false, updated: false, message: failureMessage(f, raw: text), failure: f, detail: tail)
    }

    /// Clasifica un fallo de freshclam. Un 429/403 del CDN deja a freshclam en «cool-down» hasta una hora que imprime.
    public static func classify(_ text: String) -> UpdateFailure {
        let t = text.lowercased()
        if t.contains("cool-down") || t.contains("rate limited") || t.contains("error code 429") || t.contains("error code 403") || t.contains("http 429") {
            return .coolDown(until: coolDownEnd(in: text))
        }
        for k in ["can't connect", "cannot connect", "couldn't resolve", "could not resolve", "can't resolve", "connection", "timed out", "timeout",
                  "network", "ssl", "tls", "certificate", "can't download", "can't retrieve", "no such host", "unreachable"] where t.contains(k) { return .network }
        return .other
    }

    /// Hora de fin del cool-down: «You are still on cool-down until after: 2026-11-19 17:52:21» (hora local).
    public static func coolDownEnd(in text: String) -> Date? {
        guard let r = text.range(of: #"until after:\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"#, options: .regularExpression) else { return nil }
        let s = String(text[r]).replacingOccurrences(of: "until after:", with: "").trimmingCharacters(in: .whitespaces)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: s)
    }

    /// Mensaje comprensible para el usuario.
    public static func failureMessage(_ f: UpdateFailure, raw: String) -> String {
        switch f {
        case .coolDown(let until):
            if let u = until {
                let d = DateFormatter(); d.locale = Locale.current
                d.dateStyle = Calendar.current.isDateInToday(u) ? .none : .medium; d.timeStyle = .short
                return tr("El servidor de firmas ha limitado temporalmente las descargas desde esta red. ClamMac lo reintentará solo a las %@; no hace falta pulsar nada.", d.string(from: u))
            }
            return tr("El servidor de firmas ha limitado temporalmente las descargas desde esta red. ClamMac lo reintentará solo más tarde; no hace falta pulsar nada.")
        case .network:
            return tr("No se pudo conectar con el servidor de firmas. Comprueba la conexión a internet, el cortafuegos o el proxy (database.clamav.net y clamav.abdatabase.com, puerto 443).")
        case .other:
            let l = raw.split(separator: "\n").suffix(3).joined(separator: " ")
            return l.isEmpty ? tr("No se pudieron actualizar las firmas.") : l
        }
    }

    /// Lee versión del motor y de las firmas con `clamscan --version`.
    public static func databaseInfo() async -> DatabaseInfo? {
        guard let bin = ClamPaths.clamscan else { return nil }
        let res = await Shell.run(bin, ["--version", "--database=\(ClamPaths.databaseDir)"] + ClamPaths.certsArgs)
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
