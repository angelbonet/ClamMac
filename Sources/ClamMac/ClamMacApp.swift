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
            Image(systemName: !engine.engineInstalled ? "shield.slash" : engine.log.first?.isAlert == true && engine.busy == nil ? "shield.lefthalf.filled.trianglebadge.exclamationmark"
                  : (engine.settings.realtimeEnabled ? "checkmark.shield.fill" : "shield.slash"))
                .onAppear {      // solo pruebas: abrir la ventana al arrancar
                    if ProcessInfo.processInfo.environment["CLAMMAC_OPENWINDOW"] == "1" { openWindow(id: "main") }
                }
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
        Text(!engine.engineInstalled ? tr("⚠️ Sin protección: falta ClamAV") : engine.busy ?? (engine.settings.realtimeEnabled ? tr("Protegido · vigilando carpetas") : tr("Vigilancia desactivada")))
        if let d = engine.dbInfo { Text(tr("Firmas %@ · %@", d.signatureVersion, d.displayDate)).font(.caption) }
        if let u = engine.availableUpdate {
            Button(tr("⬆️ Actualizar a ClamMac %@ y reiniciar", u.version)) { Task { await engine.installAppUpdate() } }.disabled(engine.busy != nil)
        }
        Divider()
        Toggle("Vigilancia de carpetas", isOn: $engine.settings.realtimeEnabled).disabled(!engine.engineInstalled)
        Button("Análisis rápido") { Task { await engine.quickScan() } }.disabled(engine.busy != nil || !engine.engineInstalled)
        Button("Probar protección (fichero EICAR)") { Task { await engine.runSelfTest(); openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } }.disabled(engine.busy != nil || engine.selfTest == .running || !engine.engineInstalled)
        Button("Actualizar firmas ahora") { Task { await engine.updateSignatures() } }.disabled(engine.busy != nil || !engine.engineInstalled)
        Divider()
        Link("☕ Invita un café al desarrollador", destination: Dev.coffeeURL)
        Button("Abrir ClamMac…") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button("Salir") { engine.shutdown(); NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
