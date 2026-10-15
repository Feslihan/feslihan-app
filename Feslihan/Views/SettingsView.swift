import SwiftUI
import UIKit
import ClerkKit

struct SettingsView: View {
    @ObservedObject private var subscription = SubscriptionService.shared
    @Environment(\.modelContext) private var modelContext

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var exportFile: ExportFile?

    @AppStorage(NotificationService.enabledKey) private var dailySuggestionEnabled = false
    @AppStorage(NotificationService.minutesKey) private var dailySuggestionMinutes = NotificationService.defaultMinutes
    @State private var notificationPermissionDenied = false

    /// DatePicker binding: minutes-after-midnight ↔ a Date on today.
    private var suggestionTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: dailySuggestionMinutes / 60,
                    minute: dailySuggestionMinutes % 60,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                dailySuggestionMinutes = (c.hour ?? 20) * 60 + (c.minute ?? 0)
            }
        )
    }

    private let supportEmail = "destek@feslihan.app"

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

                    section(title: "Bildirimler") {
                        SettingsToggleRow(
                            icon: "bell",
                            title: "Günlük yemek önerisi",
                            subtitle: "Her akşam yarın için bir tarif önerelim",
                            isOn: $dailySuggestionEnabled
                        )
                        .accessibilityIdentifier("settings.notificationsToggle")

                        if dailySuggestionEnabled {
                            SettingsTimeRow(
                                icon: "clock",
                                title: "Bildirim saati",
                                selection: suggestionTimeBinding
                            )
                            .accessibilityIdentifier("settings.notificationsTimePicker")

                            if notificationPermissionDenied {
                                SettingsRow(icon: "exclamationmark.triangle",
                                            title: "Bildirimlere izin verilmedi",
                                            subtitle: "Ayarlar'dan açabilirsin") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .accessibilityIdentifier("settings.notificationsDeniedHint")
                            }
                        }
                    }

                    section(title: "Yasal") {
                        SettingsLinkRow(icon: "doc.text", title: "Kullanım Koşulları", url: Legal.termsURL)
                        SettingsLinkRow(icon: "hand.raised", title: "Gizlilik Politikası", url: Legal.privacyURL)
                        SettingsLinkRow(icon: "lock.doc", title: "KVKK Aydınlatma Metni", url: Legal.kvkkURL)
                    }

                    section(title: "Destek") {
                        if let supportMailURL {
                            SettingsLinkRow(icon: "envelope", title: "Bize Yazın", subtitle: supportEmail, url: supportMailURL)
                        }
                    }

                    section(title: "Hesap") {
                        SettingsRow(icon: "square.and.arrow.down", title: "Verilerimi İndir") {
                            exportData()
                        }
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .sheet(item: $exportFile) { file in
            ActivityView(items: [file.url])
        }
        .task {
            // Keep the denied hint accurate when returning from iOS Settings.
            if dailySuggestionEnabled {
                notificationPermissionDenied = await NotificationService.shared.authorizationStatus() == .denied
            }
        }
        .onChange(of: dailySuggestionEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await NotificationService.shared.requestAuthorization()
                    if granted {
                        notificationPermissionDenied = false
                        await NotificationService.shared.refreshIfEnabled(context: modelContext)
                    } else {
                        // Keep the toggle on so the hint row explains the
                        // state; scheduling without permission is a no-op.
                        notificationPermissionDenied = await NotificationService.shared.authorizationStatus() == .denied
                    }
                } else {
                    notificationPermissionDenied = false
                    await NotificationService.shared.cancelAll()
                }
            }
        }
        .onChange(of: dailySuggestionMinutes) { _, _ in
            Task { await NotificationService.shared.refreshIfEnabled(context: modelContext) }
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

    /// KVKK data export: download all personal data and present a share sheet.
    private func exportData() {
        isWorking = true
        statusMessage = nil
        Task {
            guard let data = await APIService.exportMyData() else {
                isWorking = false
                statusMessage = "Veriler indirilemedi. Lütfen tekrar deneyin."
                return
            }
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("feslihan-verilerim.json")
            do {
                try data.write(to: fileURL, options: .atomic)
                exportFile = ExportFile(url: fileURL)
            } catch {
                statusMessage = "Veriler kaydedilemedi. Lütfen tekrar deneyin."
            }
            isWorking = false
        }
    }

    private func deleteAccount() {
        isWorking = true
        statusMessage = nil
        Task {
            // KVKK erasure: remove backend data first, while the session token is
            // still valid, then delete the Clerk account (which signs the user out).
            _ = await APIService.deleteMyData()
            do {
                try await Clerk.shared.user?.delete()
            } catch {
                statusMessage = "Hesap silinemedi. Lütfen tekrar deneyin."
            }
            isWorking = false
        }
    }
}

/// Identifiable wrapper so the exported file can drive a `.sheet(item:)`.
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIKit share sheet used to hand the KVKK data export to the user.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 40, height: 40)
                .background(DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cardTitle())
                    .foregroundStyle(DS.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DS.ember)
        }
        .padding(14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SettingsTimeRow: View {
    let icon: String
    let title: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DS.ember)
                .frame(width: 40, height: 40)
                .background(DS.emberLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.cardTitle())
                .foregroundStyle(DS.ink)

            Spacer()

            DatePicker("", selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(DS.ember)
        }
        .padding(14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .clipShape(RoundedRectangle(cornerRadius: 8))

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
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
