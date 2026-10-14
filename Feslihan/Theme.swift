import SwiftUI

// MARK: - Colors
// "Modern Kitchen Editorial" — clean white/neutral system with basil accent.
// Legacy token names (cream, sand, stone, ember…) are kept and remapped so
// every screen inherits the new system.

enum DS {
    // Backgrounds (editorial neutrals — dark: near-black)
    static let cream = Color(light: 0xFFFFFF, dark: 0x0F0F0F)    // Paper White
    static let sand = Color(light: 0xF4F4F4, dark: 0x1C1C1C)     // Wash
    static let stone = Color(light: 0xE5E5E5, dark: 0x2B2B2B)    // Line

    // Text (near-black ink + neutral grays — inverted for dark)
    static let ink = Color(light: 0x111111, dark: 0xF2F2F2)      // Ink
    static let smoke = Color(light: 0x555555, dark: 0xB3B3B3)    // Gray 1
    static let dust = Color(light: 0x767676, dark: 0x8C8C8C)     // Gray 2

    // Accent (basil green — brightened for dark)
    static let ember = Color(light: 0x23834A, dark: 0x3DA363)        // Basil
    static let emberLight = Color(light: 0xE6F3EA, dark: 0x17301F)   // Basil Tint
    static let emberDark = Color(light: 0x000000, dark: 0x000000)    // Basil Dark (cooking mode)

    // Supporting (market-produce accents)
    static let terracotta = Color(light: 0xD93A2B, dark: 0xE05A4C)
    static let honey = Color(light: 0xF2A516, dark: 0xF2A516)
    static let honeyInk = Color(light: 0xB86E00, dark: 0xD98F1F)     // Saffron Ink
    static let tomato = Color(light: 0xD93A2B, dark: 0xE05A4C)
    static let eggplant = Color(light: 0x6B2D6B, dark: 0x9A5A9A)
    static let flour = Color.white

    // Shadows (flat system — hairline borders carry the structure)
    static let shadowCard = Color.clear
    static let shadowFloat = Color(hex: 0x000000, opacity: 0.04)
    static let shadowButton = Color.clear

    // Geometry — one radius everywhere
    static let radius: CGFloat = 8
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
        }
    }
}

// MARK: - Typography
// Serif (Lora-like → New York) for titles, plain sans (Geist-like → SF Pro)
// for everything else. No rounded faces in the editorial system.

extension Font {
    // Fonts are built on text styles so they scale with Dynamic Type while
    // keeping (near-)identical default point sizes to the design.
    /// Page titles — editorial serif, ~28pt, semibold
    static func displayLarge() -> Font { .system(.title, design: .serif).weight(.semibold) }
    /// Section titles — serif, ~22pt
    static func displayTitle() -> Font { .system(.title2, design: .serif).weight(.semibold) }
    /// Section headers — sans, ~17pt, semibold
    static func sectionHeader() -> Font { .system(.body).weight(.semibold) }
    /// Card titles — sans, ~15pt, semibold
    static func cardTitle() -> Font { .system(.subheadline).weight(.semibold) }
    /// Body — system sans, ~15pt, regular
    static func bodyText() -> Font { .system(.subheadline).weight(.regular) }
    /// Labels — sans, ~13pt, medium
    static func label() -> Font { .system(.footnote).weight(.medium) }
    /// Captions — sans, ~12pt, regular
    static func captionText() -> Font { .system(.caption).weight(.regular) }
    /// Button text — sans, ~16pt, semibold
    static func buttonFont() -> Font { .system(.callout).weight(.semibold) }
    /// Handwritten / decorative — serif italic, ~15pt
    static func handwritten() -> Font { .system(.subheadline, design: .serif).weight(.regular).italic() }
    /// Eyebrow — tiny uppercase tracker label, ~11pt
    static func eyebrow() -> Font { .system(.caption2).weight(.semibold) }
}
