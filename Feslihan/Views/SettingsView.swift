import SwiftUI
import ClerkKit

struct SettingsView: View {
    @ObservedObject private var subscription = SubscriptionService.shared

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isWorking = false
    @State private var statusMessage: String?

    private let supportEmail = "destek@feslihan.app"
    private let termsURL = URL(string: "https://feslihan.app/kosullar")!
    private let privacyURL = URL(string: "https://feslihan.app/gizlilik")!

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Sürüm \(version) (\(build))"
    }

    private var supportMailURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=Feslihan%20Destek")
    }

    var body: some View {
        ZStack {
            DS.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    section(title: "Abonelik") {
                        SettingsRow(icon: "arrow.clockwise", title: "Satın Alımları Geri Yükle") {
                            restorePurchases()
                        }
                    }

                    section(title: "Yasal") {
                        SettingsLinkRow(icon: "doc.text", title: "Kullanım Koşulları", url: termsURL)
                        SettingsLinkRow(icon: "hand.raised", title: "Gizlilik Politikası", url: privacyURL)
                    }

                    section(title: "Destek") {
                        if let supportMailURL {
                            SettingsLinkRow(icon: "envelope", title: "Bize Yazın", subtitle: supportEmail, url: supportMailURL)
                        }
                    }

                    section(title: "Hesap") {
                        SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Çıkış Yap") {
                            showSignOutConfirm = true
                        }
                        SettingsRow(icon: "trash", title: "Hesabı Sil", destructive: true) {
                            showDeleteConfirm = true
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.label())
                            .foregroundStyle(DS.smoke)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    Text(appVersion)
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }

            if isWorking {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(DS.flour)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Çıkış yapmak istediğine emin misin?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Çıkış Yap", role: .destructive) { signOut() }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("Hesabını kalıcı olarak silmek istediğine emin misin? Bu işlem geri alınamaz.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Hesabı Sil", role: .destructive) { deleteAccount() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.label())
                .foregroundStyle(DS.smoke)
                .padding(.leading, 4)

            VStack(spacing: 2) {
                content()
            }
        }
    }

    private func restorePurchases() {
        isWorking = true
        statusMessage = nil
        Task {
            let success = await subscription.restorePurchases()
            isWorking = false
            statusMessage = success
                ? "Satın alımların geri yüklendi."
                : "Geri yüklenecek satın alım bulunamadı."
        }
    }

    private func signOut() {
        isWorking = true
        Task {
            try? await Clerk.shared.auth.signOut()
            isWorking = false
        }
    }

    private func deleteAccount() {
        isWorking = true
        statusMessage = nil
        Task {
            do {
                try await Clerk.shared.user?.delete()
            } catch {
                statusMessage = "Hesap silinemedi. Lütfen tekrar deneyin."
            }
            isWorking = false
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle, destructive: destructive)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle, destructive: false)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowContent: View {
    let icon: String
    let title: String
    var subtitle: String?
    var destructive: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(destructive ? DS.tomato : DS.ember)
                .frame(width: 40, height: 40)
                .background(destructive ? DS.tomato.opacity(0.12) : DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cardTitle())
                    .foregroundStyle(destructive ? DS.tomato : DS.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.dust)
        }
        .padding(14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
