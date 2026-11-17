import Foundation

public struct WatchedFolder: Codable, Identifiable, Hashable, Sendable {
    public var path: String
    public var enabled: Bool
    public var id: String { path }
    public init(path: String, enabled: Bool = true) { self.path = path; self.enabled = enabled }
}

public enum UpdateMode: String, Codable, CaseIterable, Sendable {
    case automatic, manual
}

public struct ScheduledScan: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    public var weekday: Int = 6          // 1=domingo ... 7=sábado (Calendar)
    public var hour: Int = 20
    public var minute: Int = 0
    public var folders: [String] = ["~/Downloads", "~/Desktop", "~/Documents", "/Applications"]
    public init() {}
    enum CodingKeys: String, CodingKey { case enabled, weekday, hour, minute, folders }
    public init(from d: Decoder) throws {
        self.init()
        let c = try d.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? weekday
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? hour
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? minute
        folders = try c.decodeIfPresent([String].self, forKey: .folders) ?? folders
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var watchedFolders: [WatchedFolder] = [
        WatchedFolder(path: NSHomeDirectory() + "/Downloads", enabled: true)
    ]
    public var realtimeEnabled: Bool = true
    public var updateMode: UpdateMode = .automatic
    public var updateIntervalHours: Int = 12
    public var lastUpdateCheck: Date?
    public var scheduledScan = ScheduledScan()
    /// Qué hacer al detectar una amenaza: true = cuarentena automática, false = solo avisar.
    /// Mantener clamd en marcha: análisis casi instantáneo, a cambio de ~1 GB de RAM.
    public var useDaemon: Bool = true
    public var autoQuarantine: Bool = true
    public var notificationsEnabled: Bool = true
    public var pushoverEnabled: Bool = false
    public var pushoverUser: String = ""
    // El token de Pushover va en el llavero, no aquí.
    public var excludeExtensions: [String] = ["download", "crdownload", "part", "partial", "tmp"]
    /// Buscar nuevas versiones de ClamMac en GitHub (como máximo una vez al día).
    public var autoCheckAppUpdates: Bool = true
    public var lastAppUpdateCheck: Date?

    public init() {}

    // Decodificación tolerante: un settings.json de una versión anterior (sin campos nuevos) no se pierde.
    enum CodingKeys: String, CodingKey {
        case watchedFolders, realtimeEnabled, updateMode, updateIntervalHours, lastUpdateCheck, scheduledScan,
             useDaemon, autoQuarantine, notificationsEnabled, pushoverEnabled, pushoverUser, excludeExtensions,
             autoCheckAppUpdates, lastAppUpdateCheck
    }
    public init(from d: Decoder) throws {
        self.init()
        let c = try d.container(keyedBy: CodingKeys.self)
        watchedFolders = try c.decodeIfPresent([WatchedFolder].self, forKey: .watchedFolders) ?? watchedFolders
        realtimeEnabled = try c.decodeIfPresent(Bool.self, forKey: .realtimeEnabled) ?? realtimeEnabled
        updateMode = try c.decodeIfPresent(UpdateMode.self, forKey: .updateMode) ?? updateMode
        updateIntervalHours = try c.decodeIfPresent(Int.self, forKey: .updateIntervalHours) ?? updateIntervalHours
        lastUpdateCheck = try c.decodeIfPresent(Date.self, forKey: .lastUpdateCheck)
        scheduledScan = try c.decodeIfPresent(ScheduledScan.self, forKey: .scheduledScan) ?? scheduledScan
        useDaemon = try c.decodeIfPresent(Bool.self, forKey: .useDaemon) ?? useDaemon
        autoQuarantine = try c.decodeIfPresent(Bool.self, forKey: .autoQuarantine) ?? autoQuarantine
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? notificationsEnabled
        pushoverEnabled = try c.decodeIfPresent(Bool.self, forKey: .pushoverEnabled) ?? pushoverEnabled
        pushoverUser = try c.decodeIfPresent(String.self, forKey: .pushoverUser) ?? pushoverUser
        excludeExtensions = try c.decodeIfPresent([String].self, forKey: .excludeExtensions) ?? excludeExtensions
        autoCheckAppUpdates = try c.decodeIfPresent(Bool.self, forKey: .autoCheckAppUpdates) ?? autoCheckAppUpdates
        lastAppUpdateCheck = try c.decodeIfPresent(Date.self, forKey: .lastAppUpdateCheck)
    }

    public static func load(from url: URL = ClamPaths.settingsFile) -> AppSettings {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let s = try? dec.decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    public func save(to url: URL = ClamPaths.settingsFile) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(self) { try? data.write(to: url, options: .atomic) }
    }
}
