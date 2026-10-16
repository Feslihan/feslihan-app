import SwiftUI

/// Friend picker presented from the recipe detail's send button: choose a
/// friend, add an optional note, and send the recipe to their inbox.
struct FriendPickerSheet: View {
    let recipeId: String
    let recipeTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendDTO] = []
    @State private var isLoading = true
    @State private var selectedFriend: FriendDTO?
    @State private var message = ""
    @State private var isSending = false
    @State private var sendFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if friends.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(DS.dust)
                        Text("Henüz arkadaşın yok")
                            .font(.label())
                            .foregroundStyle(DS.smoke)
                        Text("Tarif gönderebilmek için önce Hesabım → Arkadaşlar'dan arkadaş ekle.")
                            .font(.captionText())
                            .foregroundStyle(DS.dust)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(recipeTitle)
                                .font(.cardTitle())
                                .foregroundStyle(DS.smoke)
                                .lineLimit(1)

                            VStack(spacing: 2) {
                                ForEach(friends) { friend in
                                    Button {
                                        selectedFriend = selectedFriend?.id == friend.id ? nil : friend
                                    } label: {
                                        HStack(spacing: 12) {
                                            AvatarView(urlString: friend.user.avatar_url, name: friend.user.name, size: 40)

                                            Text(friend.user.displayName)
                                                .font(.cardTitle())
                                                .foregroundStyle(DS.ink)

                                            Spacer()

                                            Image(systemName: selectedFriend?.id == friend.id ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundStyle(selectedFriend?.id == friend.id ? DS.ember : DS.stone)
                                        }
                                        .padding(12)
                                        .background(DS.sand)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .accessibilityIdentifier("detail.sendSheet.friendList")

                            TextField("Mesaj (isteğe bağlı)", text: $message, axis: .vertical)
                                .font(.label())
                                .lineLimit(2...4)
                                .padding(12)
                                .background(DS.flour)
                                .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.radius)
                                        .stroke(DS.stone, lineWidth: 1)
                                )

                            if sendFailed {
                                Text("Gönderilemedi, tekrar dene.")
                                    .font(.captionText())
                                    .foregroundStyle(DS.tomato)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                    }

                    // Sticky send button
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(DS.flour)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Gönder")
                                    .font(.buttonFont())
                            }
                        }
                        .foregroundStyle(DS.flour)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(selectedFriend == nil ? DS.dust : DS.ember)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                    }
                    .disabled(selectedFriend == nil || isSending)
                    .accessibilityIdentifier("detail.sendSheet.sendButton")
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                }
            }
            .background(DS.cream)
            .navigationTitle("Tarif Gönder")
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
                friends = await APIService.fetchFriends()
                isLoading = false
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send() async {
        guard let friend = selectedFriend else { return }
        isSending = true
        sendFailed = false

        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let sent = await APIService.sendRecipe(
            recipeId: recipeId,
            to: friend.user.clerk_id,
            message: trimmed.isEmpty ? nil : trimmed
        )

        isSending = false
        if sent {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } else {
            sendFailed = true
        }
    }
}
