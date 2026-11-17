import Foundation
import CoreServices

/// Vigila carpetas con FSEvents. Emite ficheros nuevos/modificados cuando su tamaño y fecha se estabilizan
/// (así no se analizan descargas a medias) y descarta temporales y .DS_Store.
public final class FolderWatcher: @unchecked Sendable {
    public typealias Handler = @Sendable ([String]) -> Void

    private let queue = DispatchQueue(label: "clammac.watcher")
    private var stream: FSEventStreamRef?
    private var timer: DispatchSourceTimer?
    private var pending: [String: Snapshot] = [:]
    private var excluded: Set<String>
    private let handler: Handler
    private let stableTicksRequired = 2
    private let maxWait: TimeInterval = 600

    private struct Snapshot { var size: Int64; var mtime: Date; var stable: Int; var since: Date }

    public init(excludeExtensions: [String], handler: @escaping Handler) {
        self.excluded = Set(excludeExtensions.map { $0.lowercased() })
        self.handler = handler
    }

    public static func isIgnored(path: String, excluded: Set<String>) -> Bool {
        let comps = path.split(separator: "/").map(String.init)
        guard let name = comps.last else { return true }
        if name == ".DS_Store" || name.hasPrefix("._") || name == ".localized" { return true }
        for c in comps {
            let ext = (c as NSString).pathExtension.lowercased()
            if !ext.isEmpty && excluded.contains(ext) { return true }
        }
        return false
    }

    public func start(paths: [String]) {
        stop()
        let expanded = paths.map { ($0 as NSString).expandingTildeInPath }
        guard !expanded.isEmpty else { return }
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let cb: FSEventStreamCallback = { _, info, count, rawPaths, flags, _ in
            guard let info = info else { return }
            let me = Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(rawPaths, to: NSArray.self) as? [String] ?? []
            for i in 0..<count { me.event(path: paths[i], flags: flags[i]) }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let s = FSEventStreamCreate(nil, cb, &ctx, expanded as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 2, repeating: 2)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    public func stop() {
        if let s = stream { FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s) }
        stream = nil
        timer?.cancel(); timer = nil
        queue.sync { pending.removeAll() }
    }

    private func event(path: String, flags: FSEventStreamEventFlags) {
        let f = Int(flags)
        guard f & kFSEventStreamEventFlagItemIsFile != 0,
              f & (kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemModified | kFSEventStreamEventFlagItemRenamed) != 0,
              f & kFSEventStreamEventFlagItemRemoved == 0,
              !FolderWatcher.isIgnored(path: path, excluded: excluded) else { return }
        if pending[path] == nil { pending[path] = Snapshot(size: -1, mtime: .distantPast, stable: 0, since: Date()) }
        else { pending[path]!.stable = 0 }
    }

    private func tick() {
        var ready: [String] = []
        for (path, snap) in pending {
            guard let a = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = a[.size] as? Int64, let mtime = a[.modificationDate] as? Date else {
                pending[path] = nil; continue      // borrado o renombrado
            }
            if size == snap.size && mtime == snap.mtime { pending[path]!.stable += 1 }
            else { pending[path] = Snapshot(size: size, mtime: mtime, stable: 0, since: snap.since) }
            if pending[path]!.stable >= stableTicksRequired || Date().timeIntervalSince(snap.since) > maxWait {
                ready.append(path); pending[path] = nil
            }
        }
        if !ready.isEmpty { handler(ready) }
    }
}
