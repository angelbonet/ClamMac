import Foundation

public struct Threat: Identifiable, Hashable, Codable, Sendable {
    public var id = UUID()
    public let path: String
    public let signature: String
    public init(path: String, signature: String) { self.path = path; self.signature = signature }
}

public struct ScanReport: Sendable {
    public var threats: [Threat] = []
    public var scannedFiles: Int = 0
    public var permissionDenied: Int = 0
    public var engineError: String?
    public var clean: Bool { threats.isEmpty && engineError == nil }
}

public final class Scanner: @unchecked Sendable {
    public let daemon: ClamdManager
    public init(daemon: ClamdManager) { self.daemon = daemon }

    /// Parsea salida de clamscan/clamdscan: "ruta: Firma FOUND".
    public static func parse(output: String, errors: String = "") -> ScanReport {
        var r = ScanReport()
        for line in output.split(separator: "\n") {
            guard line.hasSuffix(" FOUND"), let idx = line.range(of: ": ", options: .backwards,
                  range: line.startIndex..<line.index(line.endIndex, offsetBy: -6)) else { continue }
            let path = String(line[line.startIndex..<idx.lowerBound])
            let sig = String(line[idx.upperBound..<line.index(line.endIndex, offsetBy: -6)])
            r.threats.append(Threat(path: path, signature: sig))
        }
        if let m = output.range(of: #"Scanned files: (\d+)"#, options: .regularExpression) {
            r.scannedFiles = Int(output[m].split(separator: " ").last ?? "0") ?? 0
        }
        r.permissionDenied = (output + errors).components(separatedBy: "Operation not permitted").count - 1
        return r
    }

    /// Analiza ficheros concretos (modo vigilancia). Usa clamd si está vivo; si no, clamscan.
    public func scan(files: [String]) async -> ScanReport {
        guard !files.isEmpty else { return ScanReport() }
        let listURL = FileManager.default.temporaryDirectory.appendingPathComponent("clammac-\(UUID().uuidString).txt")
        try? files.joined(separator: "\n").write(to: listURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: listURL) }
        return await run(extra: ["--file-list=\(listURL.path)"], fileCount: files.count)
    }

    /// Analiza carpetas de forma recursiva (modo bajo demanda). Siempre clamscan, con progreso por línea.
    public func scan(folders: [String], excludeDirs: [String] = ["node_modules", "\\.git"]) async -> ScanReport {
        guard let bin = ClamPaths.clamscan else { return err(tr("clamscan no encontrado (brew install clamav)")) }
        var args = ["-r", "--infected", "--database=\(ClamPaths.databaseDir)"] + ClamPaths.certsArgs
        args += excludeDirs.map { "--exclude-dir=\($0)" }
        args += folders.map { ($0 as NSString).expandingTildeInPath }
        let res = await Shell.run(bin, args)
        var r = Scanner.parse(output: res.stdout, errors: res.stderr)
        if res.status >= 2 && r.threats.isEmpty { r.engineError = res.stderr.isEmpty ? tr("clamscan salió con código %ld", Int(res.status)) : res.stderr }
        return r
    }

    private func run(extra: [String], fileCount: Int) async -> ScanReport {
        if daemon.isRunning, let bin = ClamPaths.clamdscan {
            let res = await Shell.run(bin, ["--config-file=\(daemon.configURL.path)", "--fdpass", "--infected"] + extra)
            var r = Scanner.parse(output: res.stdout, errors: res.stderr)
            if res.status >= 2 && r.threats.isEmpty {
                // clamd caído o rechazó: caer a clamscan en vez de dejar ficheros sin analizar
                return await fallback(extra: extra, fileCount: fileCount)
            }
            r.scannedFiles = max(r.scannedFiles, fileCount)
            return r
        }
        return await fallback(extra: extra, fileCount: fileCount)
    }

    private func fallback(extra: [String], fileCount: Int) async -> ScanReport {
        guard let bin = ClamPaths.clamscan else { return err(tr("clamscan no encontrado (brew install clamav)")) }
        let res = await Shell.run(bin, ["--infected", "--database=\(ClamPaths.databaseDir)"] + ClamPaths.certsArgs + extra)
        var r = Scanner.parse(output: res.stdout, errors: res.stderr)
        if res.status >= 2 && r.threats.isEmpty { r.engineError = res.stderr.isEmpty ? tr("clamscan salió con código %ld", Int(res.status)) : res.stderr }
        r.scannedFiles = max(r.scannedFiles, fileCount)
        return r
    }

    private func err(_ m: String) -> ScanReport { var r = ScanReport(); r.engineError = m; return r }
}
