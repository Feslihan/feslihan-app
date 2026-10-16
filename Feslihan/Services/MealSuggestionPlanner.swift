import Foundation

/// A saved recipe reduced to the signals the suggestion heuristic needs.
/// Mapped from the SwiftData `Recipe` at the call site so the planner stays
/// a pure, testable value-type function.
struct RecipeCandidate {
    let id: UUID
    let title: String
    let isFavorite: Bool
    let cuisine: String?
    let tags: [String]
    let cookingTimeMinutes: Int?
    let ingredientBaseNames: [String]
}

/// One day's pick: which recipe, and the notification title/body to show.
struct DailySuggestion {
    let date: Date
    let recipeId: UUID
    let recipeTitle: String
    let title: String
    let body: String
}

/// Picks "what to cook tomorrow" from the user's saved recipes — favorites
/// first, things the pantry already covers, no repeats within two weeks, and
/// some day-to-day variety. Deterministic per calendar day (seeded RNG) so
/// rescheduling on every app launch never churns already-scheduled content.
enum MealSuggestionPlanner {

    // MARK: - Normalization

    /// Canonical form for Turkish ingredient names: NFC (iOS text input
    /// produces NFD, the backend stores NFC) + Turkish-locale lowercasing.
    static func normalized(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Planning

    static func plan(
        candidates: [RecipeCandidate],
        pantryNames: Set<String>,
        recentIds: Set<UUID>,
        startDate: Date,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [DailySuggestion] {
        guard !candidates.isEmpty, days > 0 else { return [] }

        let pantry = Set(pantryNames.map(normalized))
        var suggestions: [DailySuggestion] = []
        var pickedInWindow: Set<UUID> = []
        var previousPick: RecipeCandidate?

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            var rng = SplitMix64(seed: daySeed(for: date, calendar: calendar))

            // Score the full pool; apply repeat penalties rather than hard
            // filters so tiny collections (fewer recipes than days) still get
            // a suggestion every day — just never the same as yesterday.
            let scored = candidates.map { candidate -> (RecipeCandidate, Double) in
                (candidate, score(
                    candidate,
                    pantry: pantry,
                    recentIds: recentIds,
                    pickedInWindow: pickedInWindow,
                    previousPick: previousPick,
                    rng: &rng
                ))
            }

            let eligible = scored.filter { $0.0.id != previousPick?.id }
            guard let (pick, _) = (eligible.isEmpty ? scored : eligible).max(by: { $0.1 < $1.1 }) else { continue }

            let coverage = pantryCoverage(of: pick, pantry: pantry)
            let message = SuggestionMessages.message(
                for: pick,
                pantryCoverage: coverage,
                seed: daySeed(for: date, calendar: calendar)
            )

            suggestions.append(DailySuggestion(
                date: date,
                recipeId: pick.id,
                recipeTitle: pick.title,
                title: message.title,
                body: message.body
            ))
            pickedInWindow.insert(pick.id)
            previousPick = pick
        }

        return suggestions
    }

    // MARK: - Scoring

    private static func score(
        _ candidate: RecipeCandidate,
        pantry: Set<String>,
        recentIds: Set<UUID>,
        pickedInWindow: Set<UUID>,
        previousPick: RecipeCandidate?,
        rng: inout SplitMix64
    ) -> Double {
        var score = 0.0

        if candidate.isFavorite { score += 3.0 }
        score += pantryCoverage(of: candidate, pantry: pantry) * 4.0

        if recentIds.contains(candidate.id) || pickedInWindow.contains(candidate.id) {
            score -= 5.0
        }

        if let previous = previousPick {
            if let cuisine = candidate.cuisine, cuisine == previous.cuisine {
                score -= 1.5
            }
            let sharedTags = Set(candidate.tags).intersection(previous.tags).count
            score -= Double(sharedTags) * 0.5
        }

        // Small deterministic jitter: breaks ties and rotates picks between
        // otherwise-equal recipes without destabilizing same-day reschedules.
        score += rng.nextUnit() * 0.75
        return score
    }

    static func pantryCoverage(of candidate: RecipeCandidate, pantry: Set<String>) -> Double {
        guard !pantry.isEmpty, !candidate.ingredientBaseNames.isEmpty else { return 0 }
        let matched = candidate.ingredientBaseNames.filter { pantry.contains(normalized($0)) }.count
        return Double(matched) / Double(candidate.ingredientBaseNames.count)
    }

    /// Stable seed for a calendar day (day ordinal since the era).
    static func daySeed(for date: Date, calendar: Calendar) -> UInt64 {
        let ordinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return UInt64(ordinal) ^ 0x6665_736C_6968_616E // "feslihan"
    }
}

// MARK: - Messages

/// Warm Turkish notification texts. Phrasing deliberately avoids attaching
/// suffixes to recipe titles (no "Çorbası'na" inflection bugs).
enum SuggestionMessages {
    private static let titles = [
        "Yarın ne pişirsem? 🍲",
        "Yarının menüsü hazır 🌿",
        "Akşam yemeği fikri 💡",
    ]

    static func message(
        for candidate: RecipeCandidate,
        pantryCoverage: Double,
        seed: UInt64
    ) -> (title: String, body: String) {
        var rng = SplitMix64(seed: seed &+ 0x9E37)
        let title = titles[Int(rng.next() % UInt64(titles.count))]

        let body: String
        if pantryCoverage >= 0.6 {
            body = "Kilerindeki malzemeler yetiyor — yarın için önerimiz: \(candidate.title). Afiyet olsun!"
        } else if candidate.isFavorite {
            body = "Favorilerinden bir klasik: \(candidate.title). Yarın tam zamanı!"
        } else if let minutes = candidate.cookingTimeMinutes, minutes <= 30 {
            body = "Yarın için pratik bir fikir: \(candidate.title) — sadece \(minutes) dakika."
        } else {
            body = "Yarın için önerimiz: \(candidate.title). Ne dersin?"
        }
        return (title, body)
    }
}

// MARK: - Seeded RNG

/// SplitMix64: tiny deterministic PRNG so plans are reproducible per day.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
