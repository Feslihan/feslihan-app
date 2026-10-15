import SwiftUI

/// Circular avatar: remote image when available, otherwise the first letter
/// of the name on an ink disc (same pattern as the home header avatar).
struct AvatarView: View {
    let urlString: String?
    let name: String?
    var size: CGFloat = 34

    var body: some View {
        if let urlString, !urlString.isEmpty, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Text(initial)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(DS.flour)
            .frame(width: size, height: size)
            .background(DS.ink)
            .clipShape(Circle())
    }

    private var initial: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }
}

/// Formatting helpers for the social screens.
enum SocialFormat {
    /// "3 gün önce" from a backend ISO-8601 timestamp.
    static func relativeDate(_ iso: String) -> String? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: iso) ?? plain.date(from: iso) else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
