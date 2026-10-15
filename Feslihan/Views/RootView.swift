import SwiftUI
import ClerkKit
import ClerkKitUI

struct RootView: View {
    @State private var authIsPresented = false
    @Bindable private var clerk = Clerk.shared

    var body: some View {
        if let user = clerk.user {
            SplashView()
                .task {
                    SubscriptionService.shared.isReady = false
                    await syncUserToBackend(user)
                    SubscriptionService.shared.setUser(user.id)
                    await SubscriptionService.shared.refreshStatus()
                    SubscriptionService.shared.isReady = true
                }
                .task {
                    // Backfill missing creator profile pictures from this device
                    await APIService.backfillCreatorPictures()
                }
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Editorial left-aligned hero
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(DS.ember)

                        Text("Feslihan")
                            .font(.system(size: 52, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)
                            .padding(.top, 22)

                        Text("Annenin yemek defteri, her zaman cebinde.")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(DS.smoke)
                            .frame(maxWidth: 260, alignment: .leading)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)

                    VStack(spacing: 10) {
                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Giriş Yap")
                                .font(.buttonFont())
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DS.flour)
                                .background(DS.ember)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                        }
                        .accessibilityIdentifier("auth.signInButton")

                        Button {
                            authIsPresented = true
                        } label: {
                            Text("Kayıt Ol")
                                .font(.buttonFont())
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DS.ink)
                                .background(DS.cream)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radius)
                                        .stroke(DS.ink, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                        }
                        .accessibilityIdentifier("auth.signUpButton")

                        Text("Devam ederek [Kullanım Koşulları](\(Legal.termsURL.absoluteString)) ve [Gizlilik Politikası](\(Legal.privacyURL.absoluteString))'nı kabul etmiş olursunuz.")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                            .tint(DS.ember)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
                }
            }
            .sheet(isPresented: $authIsPresented) {
                AuthView()
            }
        }
    }

    private func syncUserToBackend(_ user: ClerkKit.User) async {
        guard let url = URL(string: "\(APIService.baseURL)/users/sync") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? await Clerk.shared.session?.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Identity is derived from the token server-side; body carries profile fields only.
        let body: [String: Any?] = [
            "email": user.primaryEmailAddress?.emailAddress,
            "name": [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " "),
            "avatar_url": user.imageUrl
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
        _ = try? await URLSession.shared.data(for: request)
    }
}
