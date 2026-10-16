import Foundation

/// Centralized links to the published legal documents, reused across onboarding,
/// the paywall and Settings so the URLs never drift between screens.
enum Legal {
    static let termsURL = URL(string: "https://api.feslihan.com.tr/kosullar")!
    static let privacyURL = URL(string: "https://api.feslihan.com.tr/gizlilik")!
    static let kvkkURL = URL(string: "https://api.feslihan.com.tr/kvkk")!

    /// Apple-required auto-renewable subscription disclosure (Turkish).
    static let subscriptionDisclosure = """
    Abonelikler otomatik olarak yenilenir. Ödeme, satın alma onaylandığında Apple Kimliğinize yansıtılır. \
    Mevcut dönem bitmeden en az 24 saat önce kapatılmadığı sürece abonelik otomatik olarak yenilenir ve \
    aynı ücret tahsil edilir. Aboneliklerinizi satın alma sonrasında App Store hesap ayarlarınızdan \
    yönetebilir veya iptal edebilirsiniz.
    """
}
