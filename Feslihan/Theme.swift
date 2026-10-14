import SwiftUI

// MARK: - Colors

enum DS {
    // Backgrounds (warm paper tones — dark: deep espresso)
    static let cream = Color(light: 0xFFF8F0, dark: 0x161210)   // Aged Paper
    static let sand = Color(light: 0xF5EDE3, dark: 0x241F1B)     // Linen
    static let stone = Color(light: 0xEDE0D0, dark: 0x332C26)    // Parchment

    // Text (warm espresso tones — inverted for dark)
    static let ink = Color(light: 0x2C1810, dark: 0xF2E9DF)      // Espresso
    static let smoke = Color(light: 0x6B5244, dark: 0xBCA99B)    // Walnut
    static let dust = Color(light: 0xA89585, dark: 0x8C7D6F)     // Oat

    // Accent (basil green — brightened for dark)
    static let ember = Color(light: 0x4A7C59, dark: 0x6CA47B)        // Fresh Basil
    static let emberLight = Color(light: 0xE8F0E4, dark: 0x24352A)   // Basil Tint
    static let emberDark = Color(light: 0x2E4F38, dark: 0x8FBF9D)    // Deep Herb

    // Supporting
    static let terracotta = Color(light: 0xC67B5C, dark: 0xD28E6F)
    static let honey = Color(light: 0xE8A838, dark: 0xECB54D)
    static let tomato = Color(light: 0xD94F3B, dark: 0xE3604C)
    static let flour = Color.white

    // Shadows (warm cast-iron, never cold black)
    static let shadowCard = Color(hex: 0x2C1810, opacity: 0.06)
    static let shadowFloat = Color(hex: 0x2C1810, opacity: 0.10)
    static let shadowButton = Color(hex: 0x4A7C59, opacity: 0.22)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Adaptive color that resolves to `light` or `dark` based on the active color scheme.
    init(light: UInt, dark: UInt, opacity: Double = 1.0) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: CGFloat(opacity)
            )
        })
    }
}

// MARK: - Back Button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.ink)
                .frame(width: 38, height: 38)
                .background(DS.sand)
                .clipShape(Circle())
                .shadow(color: DS.shadowCard, radius: 4, y: 2)
        }
    }
}

// MARK: - Typography

extension Font {
    // Fonts are built on text styles so they scale with Dynamic Type while
    // keeping (near-)identical default point sizes to the original design.
    /// Page titles — warm serif, ~28pt, semibold
    static func displayLarge() -> Font { .system(.title, design: .serif).weight(.semibold) }
    /// Section titles — serif, ~22pt
    static func displayTitle() -> Font { .system(.title2, design: .serif).weight(.semibold) }
    /// Section headers — rounded sans, ~20pt, medium
    static func sectionHeader() -> Font { .system(.title3, design: .rounded).weight(.medium) }
    /// Card titles — rounded sans, ~16pt, semibold
    static func cardTitle() -> Font { .system(.callout, design: .rounded).weight(.semibold) }
    /// Body — system sans, ~15pt, regular
    static func bodyText() -> Font { .system(.subheadline).weight(.regular) }
    /// Labels — rounded sans, ~13pt, semibold
    static func label() -> Font { .system(.footnote, design: .rounded).weight(.semibold) }
    /// Captions — rounded sans, ~11pt
    static func captionText() -> Font { .system(.caption2, design: .rounded).weight(.medium) }
    /// Button text — rounded sans, ~16pt, bold
    static func buttonFont() -> Font { .system(.callout, design: .rounded).weight(.bold) }
    /// Handwritten / decorative — serif italic, ~15pt
    static func handwritten() -> Font { .system(.subheadline, design: .serif).weight(.regular).italic() }
}
