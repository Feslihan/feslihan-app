import Foundation

enum FeslihanError: LocalizedError {
    case videoLoadFailed
    case recipeParseFailed
    case captionFetchFailed
    case noInputProvided
    case notARecipe
    case quotaExceeded
    case mealPlanQuotaExceeded

    var errorDescription: String? {
        switch self {
        case .videoLoadFailed:
            return "Video yüklenemedi"
        case .recipeParseFailed:
            return "Tarif işlenemedi"
        case .captionFetchFailed:
            return "Video açıklaması alınamadı"
        case .noInputProvided:
            return "Bir URL veya video seçmelisiniz"
        case .notARecipe:
            return "Bu içerik bir yemek tarifi değil. Lütfen bir tarif videosu linki girin."
        case .quotaExceeded:
            return "Bu ay yeni tarif tarama hakkın doldu."
        case .mealPlanQuotaExceeded:
            return "Bu ay plan oluşturma hakkın doldu."
        }
    }
}
