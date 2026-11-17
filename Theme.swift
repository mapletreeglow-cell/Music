import SwiftUI
import UIKit

enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .rounded: return "Redondeada"
        case .serif: return "Serif"
        case .mono: return "Monoespaciada"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
}

struct AppTheme: Codable, Equatable {
    var accentHex = "1ED760"
    var backgroundHex = "121212"
    var surfaceHex = "262626"
    var textHex = "FFFFFF"
    var secondaryHex = "B3B3B3"
    var cornerRadius: Double = 8
    var font: FontChoice = .system
    var greetingName = ""
    var showQuickGrid = true
    var showRecent = true
    var showMostPlayed = true
    var showAlbums = true
    var showArtists = true
    var circularArtists = true
    var compactRows = false
}

struct ThemePreset: Identifiable {
    var id: String { name }
    let name: String
    let accent: String
    let background: String
    let surface: String
    let text: String
    let secondary: String

    func applied(to theme: AppTheme) -> AppTheme {
        var t = theme
        t.accentHex = accent
        t.backgroundHex = background
        t.surfaceHex = surface
        t.textHex = text
        t.secondaryHex = secondary
        return t
    }

    static let all: [ThemePreset] = [
        ThemePreset(name: "Verde clásico", accent: "1ED760", background: "121212", surface: "262626", text: "FFFFFF", secondary: "B3B3B3"),
        ThemePreset(name: "OLED negro", accent: "1ED760", background: "000000", surface: "141414", text: "FFFFFF", secondary: "9A9A9A"),
        ThemePreset(name: "Medianoche", accent: "5B8CFF", background: "0B0F1A", surface: "172033", text: "F2F5FF", secondary: "8C97B5"),
        ThemePreset(name: "Atardecer", accent: "FF6B4A", background: "1A0F12", surface: "2E1A1F", text: "FFF3EE", secondary: "C49A92"),
        ThemePreset(name: "Lavanda", accent: "B388FF", background: "15101F", surface: "251C36", text: "F6F0FF", secondary: "A596C4"),
        ThemePreset(name: "Rosa neón", accent: "FF3DA5", background: "12081A", surface: "261433", text: "FFFFFF", secondary: "BA94CC"),
        ThemePreset(name: "Papel", accent: "2E7D32", background: "F5F1E8", surface: "FFFFFF", text: "1A1A1A", secondary: "6B6B6B"),
        ThemePreset(name: "Hielo", accent: "0288D1", background: "EAF3FA", surface: "FFFFFF", text: "10202B", secondary: "5F7686")
    ]
}

@MainActor
final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet { persist() }
    }

    init() {
        if let d = UserDefaults.standard.data(forKey: "appTheme"),
           let t = try? JSONDecoder().decode(AppTheme.self, from: d) {
            theme = t
        } else {
            theme = AppTheme()
        }
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(theme) {
            UserDefaults.standard.set(d, forKey: "appTheme")
        }
    }

    var accent: Color { Color(hex: theme.accentHex) }
    var bg: Color { Color(hex: theme.backgroundHex) }
    var surface: Color { Color(hex: theme.surfaceHex) }
    var text: Color { Color(hex: theme.textHex) }
    var secondary: Color { Color(hex: theme.secondaryHex) }
    var radius: CGFloat { CGFloat(theme.cornerRadius) }
    var isDark: Bool { Color.luminance(hex: theme.backgroundHex) < 0.5 }

    /// Color del texto que va encima del color de acento (botón de play, etc.)
    var onAccent: Color { Color.luminance(hex: theme.accentHex) > 0.55 ? .black : .white }

    func binding(_ keyPath: WritableKeyPath<AppTheme, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: self.theme[keyPath: keyPath]) },
            set: { self.theme[keyPath: keyPath] = $0.hexString() }
        )
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    func hexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ x: CGFloat) -> Int { Int(round(max(0, min(1, x)) * 255)) }
        return String(format: "%02X%02X%02X", c(r), c(g), c(b))
    }

    static func luminance(hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
