import SwiftUI

/// Inbox of recipes friends have sent me ("Benimle Paylaşılanlar").
/// Accepting adds the recipe to my library on the backend; it appears in
/// Tariflerim on the next sync. Presented as a sheet from the home header.
struct SharedInboxView: View {
    /// Called after any accept/dismiss so the presenter can refresh badges.
    var onChange: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var items: [ShareInboxItemDTO] = []
    @State private var isLoading = true
    @State private var acceptedIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 80)
                } else if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(DS.dust)
                        Text("Paylaşılan tarif yok")
                            .font(.label())
                            .foregroundStyle(DS.smoke)
                        Text("Arkadaşların sana tarif gönderdiğinde burada görünür.")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                    .padding(.horizontal, 40)
                } else {
                    VStack(spacing: 14) {
                        ForEach(items) { item in
                            inboxRow(item)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                    .accessibilityIdentifier("inbox.list")
                }
            }
            .background(DS.cream)
            .navigationTitle("Benimle Paylaşılanlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ink)
                    }
                }
            }
            .task {
                items = await APIService.fetchShareInbox()
                isLoading = false
            }
        }
    }

    private func inboxRow(_ item: ShareInboxItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sender line
            HStack(spacing: 10) {
                AvatarView(urlString: item.sender.avatar_url, name: item.sender.name, size: 32)

                VStack(alignment: .leading, spacing: 1) {
                    (Text(item.sender.displayName).fontWeight(.semibold) + Text(" sana bir tarif gönderdi"))
                        .font(.label())
                        .foregroundStyle(DS.ink)
                    if let when = SocialFormat.relativeDate(item.created_at) {
                        Text(when)
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                    }
                }
            }

            // Recipe summary
            HStack(spacing: 12) {
                Group {
                    if let path = item.recipe.thumbnail_url,
                       let url = URL(string: path.hasPrefix("http") ? path : "\(APIService.baseURL)\(path)") {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            DS.stone.opacity(0.3)
                        }
                    } else {
                        ZStack {
                            DS.stone.opacity(0.3)
                            Image(systemName: "fork.knife")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(DS.dust)
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.recipe.title)
                        .font(.cardTitle())
                        .foregroundStyle(DS.ink)
                        .lineLimit(2)
                    if let minutes = item.recipe.cooking_time_minutes {
                        Text("\(minutes) dk")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                    }
                }

                Spacer()
            }

            // Personal note, in the handwritten/italic style
            if let message = item.message, !message.isEmpty {
                Text("“\(message)”")
                    .font(.handwritten())
                    .foregroundStyle(DS.smoke)
            }

            // Actions
            if acceptedIds.contains(item.id) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.ember)
                    Text("Kitaplığına eklendi")
                        .font(.label())
                        .foregroundStyle(DS.ember)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Task {
                            if await APIService.acceptShare(id: item.id) {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                acceptedIds.insert(item.id)
                                onChange()
                                try? await Task.sleep(for: .seconds(1.2))
                                items.removeAll { $0.id == item.id }
                            }
                        }
                    } label: {
                        Text("Kitaplığıma Ekle")
                            .font(.buttonFont())
                            .foregroundStyle(DS.flour)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(DS.ember)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                    }
                    .accessibilityIdentifier("inbox.acceptButton")

                    Button {
                        Task {
                            if await APIService.dismissShare(id: item.id) {
                                items.removeAll { $0.id == item.id }
                                onChange()
                            }
                        }
                    } label: {
                        Text("Yoksay")
                            .font(.buttonFont())
                            .foregroundStyle(DS.smoke)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.radius)
                                    .stroke(DS.stone, lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("inbox.dismissButton")
                }
            }
        }
        .padding(14)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }
}
