import AppKit
// Uso: swift seticon.swift <icono.icns> <fichero>   — pone un icono personalizado a un fichero (p. ej. el .dmg)
let a = CommandLine.arguments
guard a.count == 3, let img = NSImage(contentsOfFile: a[1]) else { print("uso: seticon <icns> <fichero>"); exit(1) }
exit(NSWorkspace.shared.setIcon(img, forFile: a[2], options: []) ? 0 : 2)
