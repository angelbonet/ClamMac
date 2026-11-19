import Foundation

/// Traduce una cadena. La clave es el texto en español (idioma base); si no hay traducción se muestra tal cual.
/// Marcadores: `%@` para texto y `%ld` para enteros (siempre `Int`).
/// El idioma lo elige macOS según las preferencias del usuario, o el que fije la app (`Language`).
public func tr(_ key: String, _ args: CVarArg...) -> String {
    let f = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? f : String(format: f, locale: Locale.current, arguments: args)
}

/// Idiomas de la app. `auto` sigue el idioma del sistema.
public enum Language: String, CaseIterable, Identifiable, Sendable {
    case auto, es, ca, en, fr, de, it, ptPT = "pt-PT", ptBR = "pt-BR", nl, pl, ro, sv, el, cs, ja, ar
    public var id: String { rawValue }

    /// Nombre en su propio idioma (no se traduce); `auto` se muestra con la clave traducible «Automático (idioma del sistema)».
    public var nativeName: String? {
        switch self {
        case .auto: nil
        case .es: "Español"; case .ca: "Català"; case .en: "English"; case .fr: "Français"; case .de: "Deutsch"
        case .it: "Italiano"; case .ptPT: "Português (Portugal)"; case .ptBR: "Português (Brasil)"; case .nl: "Nederlands"
        case .pl: "Polski"; case .ro: "Română"; case .sv: "Svenska"; case .el: "Ελληνικά"; case .cs: "Čeština"
        case .ja: "日本語"; case .ar: "العربية"
        }
    }

    /// Idioma fijado por el usuario en la app (nil = seguir al sistema).
    public static var override: Language {
        let dom = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let first = (dom?["AppleLanguages"] as? [String])?.first else { return .auto }
        let l = Language(rawValue: first) ?? Language(rawValue: String(first.prefix(2))) ?? .auto
        return l
    }

    /// Fija el idioma (efectivo al reiniciar la app). `auto` borra la preferencia y vuelve a seguir al sistema.
    public static func setOverride(_ l: Language) {
        if l == .auto { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([l.rawValue], forKey: "AppleLanguages") }
        UserDefaults.standard.synchronize()
    }
}
