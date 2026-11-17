import Foundation

public struct ShellResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
}

public enum Shell {
    /// Ejecuta un proceso sin bloquear el hilo llamante.
    public static func run(_ exe: String, _ args: [String], timeout: TimeInterval? = nil) async -> ShellResult {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                var outData = Data(), errData = Data()
                let lock = NSLock()
                out.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData; lock.lock(); outData.append(d); lock.unlock()
                }
                err.fileHandleForReading.readabilityHandler = { h in
                    let d = h.availableData; lock.lock(); errData.append(d); lock.unlock()
                }
                do { try p.run() } catch {
                    cont.resume(returning: ShellResult(status: -1, stdout: "", stderr: "\(error)"))
                    return
                }
                if let t = timeout {
                    DispatchQueue.global().asyncAfter(deadline: .now() + t) { if p.isRunning { p.terminate() } }
                }
                p.waitUntilExit()
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                lock.lock()
                outData.append(out.fileHandleForReading.readDataToEndOfFile())
                errData.append(err.fileHandleForReading.readDataToEndOfFile())
                let r = ShellResult(status: p.terminationStatus,
                                    stdout: String(decoding: outData, as: UTF8.self),
                                    stderr: String(decoding: errData, as: UTF8.self))
                lock.unlock()
                cont.resume(returning: r)
            }
        }
    }
}
