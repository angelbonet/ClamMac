import Foundation

/// Arranca y para un clamd propio de la app (socket Unix en Application Support, sin tocar /opt/homebrew/etc).
public final class ClamdManager: @unchecked Sendable {
    private var process: Process?
    public init() {}

    public var socketURL: URL { ClamPaths.appSupport.appendingPathComponent("clamd.sock") }
    public var configURL: URL { ClamPaths.appSupport.appendingPathComponent("clamd.conf") }

    public var isRunning: Bool {
        (process?.isRunning ?? false) && FileManager.default.fileExists(atPath: socketURL.path)
    }

    func writeConfig() {
        let conf = """
        DatabaseDirectory \(ClamPaths.databaseDir)
        LocalSocket \(socketURL.path)
        LocalSocketMode 600
        Foreground yes
        LogFile \(ClamPaths.appSupport.appendingPathComponent("clamd.log").path)
        LogTime yes
        MaxThreads 4
        SelfCheck 3600
        """
        try? conf.write(to: configURL, atomically: true, encoding: .utf8)
    }

    @discardableResult
    public func start() -> Bool {
        if isRunning { return true }
        guard let bin = ClamPaths.clamd else { return false }
        writeConfig()
        // limpia un clamd huérfano de una ejecución anterior que no cerró limpiamente
        let k = Process(); k.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        k.arguments = ["-f", configURL.path]; try? k.run(); k.waitUntilExit()
        try? FileManager.default.removeItem(at: socketURL)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["--config-file=\(configURL.path)"] + ClamPaths.certsArgs
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        process = p
        return true
    }

    /// Espera a que aparezca el socket (clamd tarda unos segundos en cargar las firmas).
    public func waitUntilReady(timeout: TimeInterval = 90) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if FileManager.default.fileExists(atPath: socketURL.path) { return true }
            if !(process?.isRunning ?? false) { return false }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    /// Pide a clamd recargar firmas tras un freshclam (SIGUSR2).
    public func reload() {
        if let p = process, p.isRunning { kill(p.processIdentifier, SIGUSR2) }
    }

    public func stop() {
        if let p = process, p.isRunning { p.terminate(); p.waitUntilExit() }
        process = nil
        try? FileManager.default.removeItem(at: socketURL)
    }
}
