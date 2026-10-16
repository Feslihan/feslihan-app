import XCTest
@testable import Feslihan

final class MealSuggestionPlannerTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let startDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        year: 2026, month: 10, day: 16
    ).date!

    private func candidate(
        _ title: String,
        favorite: Bool = false,
        cuisine: String? = nil,
        tags: [String] = [],
        minutes: Int? = nil,
        ingredients: [String] = [],
        id: UUID = UUID()
    ) -> RecipeCandidate {
        RecipeCandidate(
            id: id,
            title: title,
            isFavorite: favorite,
            cuisine: cuisine,
            tags: tags,
            cookingTimeMinutes: minutes,
            ingredientBaseNames: ingredients
        )
    }

    // MARK: - Determinism

    func testSameDateProducesIdenticalPlan() {
        let pool = (1...10).map { candidate("Tarif \($0)", id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!) }
        let a = MealSuggestionPlanner.plan(candidates: pool, pantryNames: [], recentIds: [], startDate: startDate, calendar: calendar)
        let b = MealSuggestionPlanner.plan(candidates: pool, pantryNames: [], recentIds: [], startDate: startDate, calendar: calendar)
        XCTAssertEqual(a.map(\.recipeId), b.map(\.recipeId))
        XCTAssertEqual(a.map(\.body), b.map(\.body))
    }

    // MARK: - Ranking signals

    func testFavoriteOutranksNonFavorite() {
        let favorite = candidate("Favori Yemek", favorite: true)
        let plain = candidate("Sıradan Yemek")
        let plan = MealSuggestionPlanner.plan(
            candidates: [plain, favorite], pantryNames: [], recentIds: [],
            startDate: startDate, days: 1, calendar: calendar
        )
        XCTAssertEqual(plan.first?.recipeId, favorite.id)
    }

    func testPantryCoverageOutranksAndHandlesNFDTurkish() {
        // Pantry name arrives NFC (backend), recipe ingredient typed on iOS
        // arrives NFD — "soğan" with combining breve must still match.
        let nfdSogan = "sog\u{0306}an" // s-o-g+combining breve-a-n
        let covered = candidate("Soğanlı Yemek", ingredients: [nfdSogan, "tuz"])
        let uncovered = candidate("Egzotik Yemek", ingredients: ["safran", "istiridye"])

        let plan = MealSuggestionPlanner.plan(
            candidates: [uncovered, covered],
            pantryNames: ["soğan", "tuz"],
            recentIds: [], startDate: startDate, days: 1, calendar: calendar
        )
        XCTAssertEqual(plan.first?.recipeId, covered.id)

        let coverage = MealSuggestionPlanner.pantryCoverage(
            of: covered, pantry: Set(["soğan", "tuz"].map(MealSuggestionPlanner.normalized))
        )
        XCTAssertEqual(coverage, 1.0, accuracy: 0.001)
    }

    // MARK: - Repeats

    func testNoRepeatsAcrossSevenDaysWithEnoughRecipes() {
        let pool = (1...10).map { candidate("Tarif \($0)") }
        let plan = MealSuggestionPlanner.plan(
            candidates: pool, pantryNames: [], recentIds: [],
            startDate: startDate, days: 7, calendar: calendar
        )
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(Set(plan.map(\.recipeId)).count, 7, "7-day window should not repeat with 10 recipes")
    }

    func testSmallCollectionStillFillsEveryDayWithoutBackToBackRepeats() {
        let a = candidate("Yemek A")
        let b = candidate("Yemek B")
        let plan = MealSuggestionPlanner.plan(
            candidates: [a, b], pantryNames: [], recentIds: [],
            startDate: startDate, days: 7, calendar: calendar
        )
        XCTAssertEqual(plan.count, 7, "2 recipes must still produce 7 suggestions")
        for (prev, next) in zip(plan, plan.dropFirst()) {
            XCTAssertNotEqual(prev.recipeId, next.recipeId, "no recipe on consecutive days")
        }
    }

    func testRecentIdsAreAvoidedWhenAlternativesExist() {
        let recent = candidate("Geçen Hafta Önerilen")
        let fresh = candidate("Taze Öneri")
        let plan = MealSuggestionPlanner.plan(
            candidates: [recent, fresh], pantryNames: [], recentIds: [recent.id],
            startDate: startDate, days: 1, calendar: calendar
        )
        XCTAssertEqual(plan.first?.recipeId, fresh.id)
    }

    // MARK: - Messages

    func testMessageBranches() {
        let seed: UInt64 = 42

        let pantryHit = SuggestionMessages.message(
            for: candidate("Mercimek Çorbası", ingredients: ["mercimek"]),
            pantryCoverage: 0.8, seed: seed
        )
        XCTAssertTrue(pantryHit.body.contains("Kilerindeki"), pantryHit.body)
        XCTAssertTrue(pantryHit.body.contains("Mercimek Çorbası"))

        let favorite = SuggestionMessages.message(
            for: candidate("Karnıyarık", favorite: true),
            pantryCoverage: 0, seed: seed
        )
        XCTAssertTrue(favorite.body.contains("Favorilerinden"), favorite.body)

        let quick = SuggestionMessages.message(
            for: candidate("Menemen", minutes: 15),
            pantryCoverage: 0, seed: seed
        )
        XCTAssertTrue(quick.body.contains("15 dakika"), quick.body)

        let generic = SuggestionMessages.message(
            for: candidate("Kuru Fasulye", minutes: 90),
            pantryCoverage: 0, seed: seed
        )
        XCTAssertTrue(generic.body.contains("önerimiz"), generic.body)
    }

    func testEmptyCandidatesProduceEmptyPlan() {
        let plan = MealSuggestionPlanner.plan(
            candidates: [], pantryNames: ["tuz"], recentIds: [],
            startDate: startDate, calendar: calendar
        )
        XCTAssertTrue(plan.isEmpty)
    }
}
