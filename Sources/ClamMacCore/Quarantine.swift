import Foundation

public struct QuarantineItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let originalPath: String
    public let signature: String
    public let date: Date
    public let size: Int64
}

public final class Quarantine: @unchecked Sendable {
    private let dir: URL
    private let fm = FileManager.default

    public init(dir: URL = ClamPaths.quarantineDir) {
        self.dir = dir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    private func dataURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).quarantined") }
    private func metaURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).json") }

    /// Mueve el fichero a cuarentena, le quita todos los permisos (no ejecutable ni legible por otros).
    @discardableResult
    public func add(path: String, signature: String) throws -> QuarantineItem {
        let id = UUID()
        let size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        try fm.moveItem(atPath: path, toPath: dataURL(id).path)
        try? fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: dataURL(id).path)
        let item = QuarantineItem(id: id, originalPath: path, signature: signature, date: Date(), size: size)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try enc.encode(item).write(to: metaURL(id), options: .atomic)
        return item
    }

    public func list() -> [QuarantineItem] {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? dec.decode(QuarantineItem.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date > $1.date }
    }

    /// Restaura al sitio original; si ya existe algo allí, añade sufijo " (restaurado)".
    @discardableResult
    public func restore(_ item: QuarantineItem) throws -> String {
        var dest = item.originalPath
        if fm.fileExists(atPath: dest) {
            let u = URL(fileURLWithPath: dest)
            dest = u.deletingLastPathComponent()
                .appendingPathComponent(u.deletingPathExtension().lastPathComponent + " (restaurado)")
                .appendingPathExtension(u.pathExtension).path
        }
        try fm.createDirectory(atPath: (dest as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataURL(item.id).path)
        try fm.moveItem(atPath: dataURL(item.id).path, toPath: dest)
        try? fm.removeItem(at: metaURL(item.id))
        return dest
    }

    public func delete(_ item: QuarantineItem) throws {
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dataURL(item.id).path)
        try fm.removeItem(at: dataURL(item.id))
        try? fm.removeItem(at: metaURL(item.id))
    }
}
