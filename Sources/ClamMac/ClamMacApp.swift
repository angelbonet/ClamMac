import SwiftUI
import ClamMacCore

@main
struct ClamMacApp: App {
    @StateObject private var engine = Engine()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContent(engine: engine)
        } label: {
            Image(systemName: engine.log.first?.isAlert == true && engine.busy == nil ? "shield.lefthalf.filled.trianglebadge.exclamationmark"
                  : (engine.settings.realtimeEnabled ? "checkmark.shield.fill" : "shield.slash"))
        }
        Window("ClamMac", id: "main") {
            MainView().environmentObject(engine)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 900, height: 600)
    }
}

struct MenuContent: View {
    @ObservedObject var engine: Engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(engine.busy ?? (engine.settings.realtimeEnabled ? "Protegido · vigilando carpetas" : "Vigilancia desactivada"))
        if let d = engine.dbInfo { Text("Firmas \(d.signatureVersion) · \(d.displayDate)").font(.caption) }
        if let u = engine.availableUpdate {
            Button("⬆️ Actualizar a ClamMac \(u.version) y reiniciar") { Task { await engine.installAppUpdate() } }.disabled(engine.busy != nil)
        }
        Divider()
        Toggle("Vigilancia de carpetas", isOn: $engine.settings.realtimeEnabled)
        Button("Análisis rápido") { Task { await engine.quickScan() } }.disabled(engine.busy != nil)
        Button("Actualizar firmas ahora") { Task { await engine.updateSignatures() } }.disabled(engine.busy != nil)
        Divider()
        Link("☕ Invita un café al desarrollador", destination: Dev.coffeeURL)
        Button("Abrir ClamMac…") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button("Salir") { engine.shutdown(); NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
