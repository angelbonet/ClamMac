import Foundation

/// Fichero de prueba EICAR: cadena ASCII de 68 bytes estándar de la industria (EICAR + CARO) que TODO antivirus
/// detecta por convenio. No es malware ni contiene código que se ejecute: es solo texto.
public enum TestFile {
    public static let eicar = #"X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"#
    /// SHA-256 conocido del fichero EICAR de 68 bytes (sin salto de línea final).
    public static let eicarSHA256 = "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f"
    public static let namePrefix = "ClamMac-prueba-EICAR-"

    /// Crea el fichero de prueba dentro de `folder` y devuelve su ruta.
    public static func create(in folder: String) throws -> String {
        let dir = (folder as NSString).expandingTildeInPath
        let path = (dir as NSString).appendingPathComponent("\(namePrefix)\(UUID().uuidString.prefix(8)).com")
        try eicar.write(toFile: path, atomically: true, encoding: .ascii)
        return path
    }

    public static func isTestFile(path: String) -> Bool {
        (path as NSString).lastPathComponent.hasPrefix(namePrefix)
    }
}
