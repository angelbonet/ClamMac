import Foundation
import CryptoKit

public struct ReleaseInfo: Sendable, Equatable {
    public let version: String      // "1.0.1" (sin la «v»)
    public let notes: String
    public let dmgURL: URL
    public let sha256: String?      // hash esperado del DMG, de la release
    public let pageURL: URL
}

public enum UpdateError: Error, LocalizedError {
    case network(String), noAsset, noHash, hashMismatch, badSignature(String)
    public var errorDescription: String? {
        switch self {
        case .network(let m): return "Sin conexión con GitHub: \(m)"
        case .noAsset: return "La release no incluye un DMG."
        case .noHash: return "La release no publica el SHA-256 del DMG; no se instala automáticamente."
        case .hashMismatch: return "El SHA-256 del DMG descargado no coincide con el publicado. Descarga cancelada."
        case .badSignature(let m): return "El DMG no está firmado y notarizado por el desarrollador: \(m)"
        }
    }
}

/// Busca nuevas versiones en las releases de GitHub y descarga/verifica el DMG.
public enum UpdateChecker {
    public static let repo = "angelbonet/ClamMac"
    public static let expectedTeamID = "54HHDMD6T8"      // Innovaorto AIE

    /// Compara versiones numéricas ("1.10.0" > "1.9.2"); ignora una «v» inicial.
    public static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    public static func parse(json: Data) -> ReleaseInfo? {
        guard let o = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let tag = o["tag_name"] as? String,
              (o["draft"] as? Bool) != true, (o["prerelease"] as? Bool) != true,
              let html = (o["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
        let notes = o["body"] as? String ?? ""
        let assets = o["assets"] as? [[String: Any]] ?? []
        guard let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
              let urlStr = dmg["browser_download_url"] as? String, let url = URL(string: urlStr),
              url.host == "github.com" else { return nil }
        var sha: String?
        if let d = dmg["digest"] as? String, d.hasPrefix("sha256:") { sha = String(d.dropFirst(7)).lowercased() }
        if sha == nil, let r = notes.range(of: #"(?i)sha-?256[^0-9a-f]{0,6}([0-9a-f]{64})"#, options: .regularExpression) {
            sha = String(notes[r].suffix(64)).lowercased()
        }
        return ReleaseInfo(version: tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV")), notes: notes, dmgURL: url, sha256: sha, pageURL: html)
    }

    /// Devuelve la última release si es más nueva que `current`; nil si ya estás al día.
    public static func check(current: String, session: URLSession = .shared) async throws -> ReleaseInfo? {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ClamMac/\(current)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw UpdateError.network("respuesta inválida") }
            if http.statusCode == 404 { return nil }                   // aún sin releases
            guard http.statusCode == 200 else { throw UpdateError.network("HTTP \(http.statusCode)") }
            guard let rel = parse(json: data) else { return nil }
            return isNewer(rel.version, than: current) ? rel : nil
        } catch let e as UpdateError { throw e } catch { throw UpdateError.network(error.localizedDescription) }
    }

    public static func sha256(of url: URL) throws -> String {
        let h = try FileHandle(forReadingFrom: url); defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Descarga el DMG a Application Support/Updates y lo verifica (hash + firma Developer ID + notarización).
    public static func downloadAndVerify(_ rel: ReleaseInfo) async throws -> URL {
        guard let expected = rel.sha256 else { throw UpdateError.noHash }
        let (tmp, _): (URL, URLResponse)
        do { (tmp, _) = try await URLSession.shared.download(from: rel.dmgURL) } catch { throw UpdateError.network(error.localizedDescription) }
        let dir = ClamPaths.appSupport.appendingPathComponent("Updates", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("ClamMac-\(rel.version).dmg")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        guard try sha256(of: dest) == expected else { try? FileManager.default.removeItem(at: dest); throw UpdateError.hashMismatch }
        try await verifySignature(dest)
        return dest
    }

    static func verifySignature(_ dmg: URL) async throws {
        let info = await Shell.run("/usr/bin/codesign", ["-dvv", dmg.path])
        guard (info.stdout + info.stderr).contains("TeamIdentifier=\(expectedTeamID)") else {
            try? FileManager.default.removeItem(at: dmg); throw UpdateError.badSignature("el equipo firmante no es el esperado")
        }
        let gk = await Shell.run("/usr/sbin/spctl", ["-a", "-t", "open", "--context", "context:primary-signature", dmg.path])
        guard gk.status == 0 else {
            try? FileManager.default.removeItem(at: dmg); throw UpdateError.badSignature("Gatekeeper no lo acepta (¿sin notarizar?)")
        }
    }
}
