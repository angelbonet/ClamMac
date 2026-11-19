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

    func testBundledEnginePathsAndConf() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("clammac-eng-\(UUID().uuidString)")
        let eng = tmp.appendingPathComponent("eng"), data = tmp.appendingPathComponent("data")
        try fm.createDirectory(at: eng, withIntermediateDirectories: true)
        for b in ["clamscan", "freshclam"] {
            let f = eng.appendingPathComponent(b)
            try "#!/bin/sh\n".write(to: f, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: f.path)
        }
        setenv("CLAMMAC_ENGINE_DIR", eng.path, 1); setenv("CLAMMAC_DATA_DIR", data.path, 1)
        defer { unsetenv("CLAMMAC_ENGINE_DIR"); unsetenv("CLAMMAC_DATA_DIR"); try? fm.removeItem(at: tmp) }
        XCTAssertTrue(ClamPaths.usingBundledEngine)
        XCTAssertEqual(ClamPaths.clamscan, eng.appendingPathComponent("clamscan").path)
        XCTAssertEqual(ClamPaths.databaseDir, data.appendingPathComponent("Database").path)
        XCTAssertFalse(ClamPaths.hasDatabase)
        ClamPaths.writeFreshclamConf()
        let conf = try String(contentsOf: ClamPaths.freshclamConf, encoding: .utf8)
        XCTAssertTrue(conf.contains("DatabaseDirectory \(ClamPaths.databaseDir)"))
        XCTAssertFalse(conf.contains("Example"))
        for n in ["main.cvd", "daily.cld"] { fm.createFile(atPath: ClamPaths.databaseDir + "/" + n, contents: Data()) }
        XCTAssertTrue(ClamPaths.hasDatabase)
    }

    // MARK: idiomas
    func testTranslationsAreComplete() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let langs = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Localization").path)
            .filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }.sorted()
        XCTAssertGreaterThanOrEqual(langs.count, 16)
        XCTAssertTrue(Language.allCases.filter { $0 != .auto }.allSatisfy { langs.contains($0.rawValue) }, "selector con idioma sin traducción")
        let tables = try langs.map { l -> [String: String] in
            let url = root.appendingPathComponent("Localization/\(l).lproj/Localizable.strings")
            return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "falta o es inválido \(l)")
        }
        let base = Set(tables[langs.firstIndex(of: "es")!].keys)
        XCTAssertGreaterThan(base.count, 150)
        func marks(_ s: String) -> [String] { s.components(separatedBy: "%").dropFirst().map { String($0.prefix(while: { $0.isLetter || $0 == "@" }).prefix(2)) } }
        for (l, t) in zip(langs, tables) {
            XCTAssertEqual(Set(t.keys), base, "\(l): claves distintas")
            for (k, v) in t {
                XCTAssertFalse(v.isEmpty, "\(l): vacía «\(k)»")
                XCTAssertEqual(marks(k).map { $0.hasPrefix("ld") ? "ld" : "@" }, marks(v).map { $0.hasPrefix("ld") ? "ld" : "@" }, "\(l): marcadores distintos en «\(k)»")
            }
        }
        // Toda cadena tr("…") sin interpolar del código tiene traducción.
        let src = root.appendingPathComponent("Sources")
        let files = FileManager.default.enumerator(at: src, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let re = try NSRegularExpression(pattern: #"\btr\(\s*"((?:[^"\\]|\\.)*)""#)
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let key = (text as NSString).substring(with: m.range(at: 1)).replacingOccurrences(of: "\\\"", with: "\"")
                XCTAssertTrue(base.contains(key), "sin traducción: «\(key)» en \(f.lastPathComponent)")
            }
        }
    }

    // MARK: actualización de firmas (1.2.1)
    func testClassifyCoolDown() throws {
        let out = "WARNING: FreshClam previously received error code 429 or 403 from the CDN.\nWARNING: You are still on cool-down until after: 2026-11-19 17:52:21\n"
        guard case .coolDown(let until) = Updater.classify(out) else { return XCTFail("debería ser cool-down") }
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: try XCTUnwrap(until))
        XCTAssertEqual([c.year, c.month, c.day, c.hour, c.minute], [2026, 11, 19, 17, 52])
    }
    func testClassifyNetworkAndOther() {
        XCTAssertEqual(Updater.classify("ERROR: Can't connect to database.clamav.net"), .network)
        XCTAssertEqual(Updater.classify("ERROR: Can't open file"), .other)
    }
    func testMirrorConf() throws {
        ClamPaths.writeFreshclamMirrorConf(mirror: "https://example.org/clamav")
        ClamPaths.writeFreshclamConf()
        let official = try String(contentsOf: ClamPaths.freshclamConf, encoding: .utf8)
        XCTAssertTrue(official.contains("TestDatabases no"), "sin esto freshclam falla en Macs que no son el de desarrollo")
        let conf = try String(contentsOf: ClamPaths.freshclamMirrorConf, encoding: .utf8)
        XCTAssertTrue(conf.contains("TestDatabases no"))
        XCTAssertTrue(conf.contains("PrivateMirror https://example.org/clamav"))
        XCTAssertTrue(conf.contains("DNSDatabaseInfo no"))
    }
    func testSettingsOldFileKeepsMirrorDefault() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: Data("{\"realtimeEnabled\":false}".utf8))
        XCTAssertTrue(s.useSignatureMirror); XCTAssertNil(s.officialCoolDownUntil)
    }
    func testWhatsNewExistsForCurrentVersion() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let langs = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Localization").path).filter { $0.hasSuffix(".lproj") }
        for l in langs {
            let url = root.appendingPathComponent("Localization/\(l)/WhatsNew.strings")
            let d = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "falta WhatsNew en \(l)")
            XCTAssertFalse((d["1.2.1"] ?? "").isEmpty, "\(l): sin novedades de 1.2.1")
            XCTAssertFalse((d["1.2.2"] ?? "").isEmpty, "\(l): sin novedades de 1.2.2")
            XCTAssertFalse((d["1.2.3"] ?? "").isEmpty, "\(l): sin novedades de 1.2.3")
            XCTAssertFalse((d["1.2.4"] ?? "").isEmpty, "\(l): sin novedades de 1.2.4")
        }
    }

    func testMirrorFailureIsShownAlongsideOfficialError() {
        XCTAssertEqual(Updater.mirrorSuffix(""), "")
        XCTAssertTrue(Updater.mirrorSuffix("x").contains("x"))
        let r = UpdateResult(ok: false, updated: false, message: "m", failure: .network, detail: "")
        XCTAssertTrue(Updater.mirrorReason(r).contains("clamav.abdatabase.com"))
    }

    func testCoolDownWithExitZeroIsAFailure() {
        let out = "WARNING: FreshClam previously received error code 429 or 403 from the CDN.\nWARNING: You are still on cool-down until after: 2026-11-19 17:52:21\n"
        let r = Updater.interpret(ShellResult(status: 0, stdout: out, stderr: ""))
        XCTAssertFalse(r.ok)
        if case .coolDown = r.failure {} else { XCTFail("debería ser cool-down") }
    }
    func testStashAndRestoreFreshclamState() throws {
        let fm = FileManager.default, f = ClamPaths.freshclamState
        try? fm.removeItem(at: f); try? fm.removeItem(at: f.appendingPathExtension("official"))
        try Data("ORIGINAL".utf8).write(to: f)
        let stash = ClamPaths.stashFreshclamState()
        XCTAssertFalse(fm.fileExists(atPath: f.path), "debe apartarse")
        try Data("DEL-ESPEJO".utf8).write(to: f)              // lo que crearía freshclam contra el espejo
        ClamPaths.restoreFreshclamState(stash)
        XCTAssertEqual(try String(contentsOf: f, encoding: .utf8), "ORIGINAL")
        try? fm.removeItem(at: f)
    }
}
