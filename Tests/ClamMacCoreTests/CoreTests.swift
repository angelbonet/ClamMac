import XCTest
@testable import ClamMacCore

final class CoreTests: XCTestCase {
    static let eicar = #"X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"#

    func tmpDir() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("clammac-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testParseFound() {
        let out = "/Users/a/Downloads/x: y.zip: Win.Test.EICAR_HDB-1 FOUND\n----------- SCAN SUMMARY -----------\nScanned files: 12\n"
        let r = Scanner.parse(output: out)
        XCTAssertEqual(r.threats.count, 1)
        XCTAssertEqual(r.threats[0].path, "/Users/a/Downloads/x: y.zip")
        XCTAssertEqual(r.threats[0].signature, "Win.Test.EICAR_HDB-1")
        XCTAssertEqual(r.scannedFiles, 12)
    }

    func testParseVersion() {
        let v = Updater.parseVersion("ClamAV 1.5.4/28182/Fri Nov 13 07:24:28 2026\n")
        XCTAssertEqual(v?.version, "1.5.4"); XCTAssertEqual(v?.signatureVersion, "28182")
    }

    func testDisplayDate() {
        let v = DatabaseInfo(version: "1.5.4", signatureVersion: "28186", date: "Tue Nov 17 07:30:05 2026")
        XCTAssertFalse(v.displayDate.contains("Tue"), v.displayDate)
        XCTAssertTrue(v.displayDate.contains("2026"))
        // la hora no debe cambiar: clamscan ya da hora local (07:30), no UTC
        XCTAssertTrue(v.displayDate.contains("7:30"), v.displayDate)
        XCTAssertEqual(DatabaseInfo(version: "", signatureVersion: "", date: "raro").displayDate, "raro")
    }

    func testVersionCompare() {
        XCTAssertTrue(UpdateChecker.isNewer("1.10.0", than: "1.9.2"))
        XCTAssertTrue(UpdateChecker.isNewer("v1.0.1", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.9.9", than: "1.0.0"))
    }

    func testParseRelease() {
        let sha = String(repeating: "ab", count: 32)
        let json = """
        {"tag_name":"v1.2.0","draft":false,"prerelease":false,"html_url":"https://github.com/angelbonet/ClamMac/releases/tag/v1.2.0",
         "body":"Novedades\\nSHA-256: \(sha)",
         "assets":[{"name":"ClamMac-1.2.0.dmg","browser_download_url":"https://github.com/angelbonet/ClamMac/releases/download/v1.2.0/ClamMac-1.2.0.dmg"}]}
        """.data(using: .utf8)!
        let r = UpdateChecker.parse(json: json)
        XCTAssertEqual(r?.version, "1.2.0"); XCTAssertEqual(r?.sha256, sha)
        // digest de la API tiene prioridad y un host ajeno a github.com se rechaza
        let evil = String(data: json, encoding: .utf8)!.replacingOccurrences(of: "https://github.com/angelbonet/ClamMac/releases/download", with: "https://evil.example/x")
        XCTAssertNil(UpdateChecker.parse(json: evil.data(using: .utf8)!))
        let pre = String(data: json, encoding: .utf8)!.replacingOccurrences(of: "\"prerelease\":false", with: "\"prerelease\":true")
        XCTAssertNil(UpdateChecker.parse(json: pre.data(using: .utf8)!))
    }

    func testOldSettingsFileKeepsValues() throws {
        let u = try tmpDir().appendingPathComponent("s.json")
        try #"{"updateMode":"manual","updateIntervalHours":4,"useDaemon":false}"#.write(to: u, atomically: true, encoding: .utf8)
        let l = AppSettings.load(from: u)
        XCTAssertEqual(l.updateMode, .manual); XCTAssertEqual(l.updateIntervalHours, 4)
        XCTAssertFalse(l.useDaemon); XCTAssertTrue(l.autoCheckAppUpdates)
    }

    /// Prueba real contra GitHub (solo con CLAMMAC_LIVE=1): encuentra la release, la descarga y la verifica.
    func testLiveGitHubRelease() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CLAMMAC_LIVE"] == "1", "prueba de red desactivada")
        let none = try await UpdateChecker.check(current: "99.0.0")
        XCTAssertNil(none, "con una versión futura no debe ofrecer actualización")
        let rel = try await UpdateChecker.check(current: "0.0.1")
        let r = try XCTUnwrap(rel, "debe encontrar una release más nueva que 0.0.1")
        XCTAssertNotNil(r.sha256)
        let dmg = try await UpdateChecker.downloadAndVerify(r)
        defer { try? FileManager.default.removeItem(at: dmg) }
        XCTAssertEqual(try UpdateChecker.sha256(of: dmg), r.sha256)
        print("LIVE OK version=\(r.version) sha=\(r.sha256 ?? "-") size=\((try? FileManager.default.attributesOfItem(atPath: dmg.path)[.size]) ?? 0)")
    }

    // MARK: ayudante de autoactualización (script real, con VERIFY/OPEN desactivados)
    func runHelper(pid: Int32, new: URL, dest: URL, log: URL, env: [String: String] = [:]) throws {
        let d = try tmpDir(); let sc = d.appendingPathComponent("h.sh")
        try SelfUpdater.helperScript.write(to: sc, atomically: true, encoding: .utf8)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [sc.path, "\(pid)", new.path, dest.path, log.path]
        p.environment = ["VERIFY": "0", "OPEN": "0", "PATH": "/usr/bin:/bin"].merging(env) { $1 }
        try p.run(); p.waitUntilExit()
    }
    func fakeApp(_ dir: URL, _ name: String, marker: String) throws -> URL {
        let a = dir.appendingPathComponent(name); try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try marker.write(to: a.appendingPathComponent("v.txt"), atomically: true, encoding: .utf8); return a
    }

    func testHelperReplacesApp() throws {
        let d = try tmpDir(); let old = try fakeApp(d, "ClamMac.app", marker: "viejo"); let new = try fakeApp(d, "new.app", marker: "nuevo")
        let log = d.appendingPathComponent("u.log")
        try runHelper(pid: 999_999, new: new, dest: old, log: log)    // PID inexistente: no espera
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v.txt")), "nuevo")
        XCTAssertFalse(FileManager.default.fileExists(atPath: new.path), "la copia temporal se borra")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path + ".previous"), "la copia de seguridad se borra")
        XCTAssertTrue(try String(contentsOf: log).contains("instalada"))
    }

    func testHelperRollsBackOnFailure() throws {
        let d = try tmpDir(); let old = try fakeApp(d, "ClamMac.app", marker: "viejo")
        let missing = d.appendingPathComponent("no-existe.app"), log = d.appendingPathComponent("u.log")
        try runHelper(pid: 999_999, new: missing, dest: old, log: log)
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v.txt")), "viejo", "debe quedar la app anterior")
        XCTAssertTrue(try String(contentsOf: log).contains("restaurando"))
    }

    func testHelperWaitsForAppToQuit() throws {
        let d = try tmpDir(); let old = try fakeApp(d, "ClamMac.app", marker: "viejo"); let new = try fakeApp(d, "new.app", marker: "nuevo")
        let sleeper = Process(); sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep"); sleeper.arguments = ["2"]; try sleeper.run()
        let t0 = Date()
        try runHelper(pid: sleeper.processIdentifier, new: new, dest: old, log: d.appendingPathComponent("u.log"))
        XCTAssertGreaterThan(Date().timeIntervalSince(t0), 1.0, "debe esperar a que la app termine")
        XCTAssertEqual(try String(contentsOf: old.appendingPathComponent("v.txt")), "nuevo")
    }

    func testCanReplace() {
        XCTAssertFalse(SelfUpdater.canReplace(appURL: URL(fileURLWithPath: "/Volumes/ClamMac/ClamMac.app")))
        XCTAssertFalse(SelfUpdater.canReplace(appURL: URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/d/ClamMac.app")))
        XCTAssertFalse(SelfUpdater.canReplace(appURL: URL(fileURLWithPath: "/tmp/ClamMac")))      // no es .app
        XCTAssertTrue(SelfUpdater.canReplace(appURL: URL(fileURLWithPath: NSTemporaryDirectory() + "ClamMac.app")))
    }

    func testEicarTestFile() throws {
        XCTAssertEqual(TestFile.eicar.utf8.count, 68)
        let d = try tmpDir(); let p = try TestFile.create(in: d.path)
        XCTAssertTrue(TestFile.isTestFile(path: p)); XCTAssertFalse(TestFile.isTestFile(path: "/a/eicar.com"))
        XCTAssertEqual(try UpdateChecker.sha256(of: URL(fileURLWithPath: p)), TestFile.eicarSHA256, "debe ser el EICAR oficial")
    }

    func testEicarInsideZipIsDetected() async throws {
        try XCTSkipIf(ClamPaths.clamscan == nil, "ClamAV no instalado")
        let d = try tmpDir(); let p = try TestFile.create(in: d.path)
        let zip = d.appendingPathComponent("t.zip")
        let z = await Shell.run("/usr/bin/zip", ["-q", "-j", zip.path, p]); XCTAssertEqual(z.status, 0)
        let r = await Scanner(daemon: ClamdManager()).scan(files: [zip.path])
        XCTAssertEqual(r.threats.count, 1, "el ZIP con EICAR debe detectarse; error=\(r.engineError ?? "-")")
    }

    func testIgnored() {
        let ex: Set<String> = ["download", "crdownload"]
        XCTAssertTrue(FolderWatcher.isIgnored(path: "/a/.DS_Store", excluded: ex))
        XCTAssertTrue(FolderWatcher.isIgnored(path: "/a/f.zip.download/f.zip", excluded: ex))
        XCTAssertTrue(FolderWatcher.isIgnored(path: "/a/f.crdownload", excluded: ex))
        XCTAssertFalse(FolderWatcher.isIgnored(path: "/a/f.zip", excluded: ex))
    }

    func testSettingsRoundTrip() throws {
        let u = try tmpDir().appendingPathComponent("s.json")
        var s = AppSettings(); s.lastUpdateCheck = Date(timeIntervalSince1970: 1_700_000_000); s.updateMode = .manual
        s.save(to: u)
        let l = AppSettings.load(from: u)
        XCTAssertEqual(l.updateMode, .manual); XCTAssertEqual(l.lastUpdateCheck, s.lastUpdateCheck)
    }

    func testQuarantineCycle() throws {
        let d = try tmpDir(); let q = Quarantine(dir: d.appendingPathComponent("q"))
        let f = d.appendingPathComponent("bad.txt"); try "x".write(to: f, atomically: true, encoding: .utf8)
        let item = try q.add(path: f.path, signature: "Test")
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.path))
        XCTAssertEqual(q.list().count, 1)
        let restored = try q.restore(item)
        XCTAssertEqual(restored, f.path); XCTAssertTrue(FileManager.default.fileExists(atPath: f.path))
        XCTAssertEqual(q.list().count, 0)
        let item2 = try q.add(path: f.path, signature: "Test"); try q.delete(item2)
        XCTAssertEqual(q.list().count, 0)
    }

    func testEicarDetectedByClamscan() async throws {
        try XCTSkipIf(ClamPaths.clamscan == nil, "ClamAV no instalado")
        let d = try tmpDir(); let f = d.appendingPathComponent("eicar.com")
        try Self.eicar.write(to: f, atomically: true, encoding: .utf8)
        let r = await Scanner(daemon: ClamdManager()).scan(files: [f.path])
        XCTAssertEqual(r.threats.count, 1, "engineError=\(r.engineError ?? "-")")
    }

    func testWatcherEmitsStableFileOnce() async throws {
        let d = try tmpDir()
        let exp = expectation(description: "file")
        let got = NSLock(); var seen: [String] = []
        let w = FolderWatcher(excludeExtensions: ["download"]) { files in
            got.lock(); seen += files; got.unlock(); exp.fulfill()
        }
        w.start(paths: [d.path]); defer { w.stop() }
        try await Task.sleep(nanoseconds: 700_000_000)
        try "hola".write(to: d.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "tmp".write(to: d.appendingPathComponent("b.zip.download"), atomically: true, encoding: .utf8)
        await fulfillment(of: [exp], timeout: 15)
        got.lock(); defer { got.unlock() }
        XCTAssertEqual(seen.map { ($0 as NSString).lastPathComponent }, ["a.txt"])
    }
}
