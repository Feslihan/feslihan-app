import SwiftUI

/// Friends management: my friend code, adding friends by code or email,
/// pending requests, and the friends list. Pushed from the account sheet.
struct FriendsView: View {
    @State private var friendCode: String?
    @State private var friends: [FriendDTO] = []
    @State private var incoming: [FriendRequestDTO] = []
    @State private var outgoing: [FriendRequestDTO] = []

    @State private var query = ""
    @State private var lookupResult: SocialLookupDTO?
    @State private var lookupFailed = false
    @State private var isSearching = false

    @State private var copiedCode = false
    @State private var friendToRemove: FriendDTO?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                myCodeCard
                addFriendSection

                if !incoming.isEmpty {
                    requestSection(title: "Gelen İstekler", requests: incoming, isIncoming: true)
                }
                if !outgoing.isEmpty {
                    requestSection(title: "Gönderilen İstekler", requests: outgoing, isIncoming: false)
                }

                friendsSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(DS.cream)
        .navigationTitle("Arkadaşlar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .confirmationDialog(
            "\(friendToRemove?.user.displayName ?? "") arkadaş listenden çıkarılsın mı?",
            isPresented: Binding(
                get: { friendToRemove != nil },
                set: { if !$0 { friendToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Arkadaşı Çıkar", role: .destructive) {
                if let friend = friendToRemove {
                    Task {
                        _ = await APIService.removeFriend(userId: friend.user.clerk_id)
                        await refresh()
                    }
                }
                friendToRemove = nil
            }
            Button("Vazgeç", role: .cancel) { friendToRemove = nil }
        }
    }

    // MARK: - My friend code

    private var myCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ARKADAŞ KODUM")
                .font(.eyebrow())
                .foregroundStyle(DS.dust)

            HStack {
                Text(friendCode ?? "•••••••")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(DS.ink)
                    .accessibilityIdentifier("friends.codeLabel")

                Spacer()

                Button {
                    if let code = friendCode {
                        UIPasteboard.general.string = code
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        copiedCode = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copiedCode = false
                        }
                    }
                } label: {
                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(copiedCode ? DS.ember : DS.ink)
                        .frame(width: 38, height: 38)
                        .background(DS.flour)
                        .clipShape(Circle())
                }
                .accessibilityIdentifier("friends.copyCodeButton")
            }

            Text("Bu kodu annene veya arkadaşına gönder; kodu girerek seni ekleyebilir.")
                .font(.captionText())
                .foregroundStyle(DS.smoke)
        }
        .padding(16)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    // MARK: - Add friend

    private var addFriendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arkadaş Ekle")
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)

            HStack(spacing: 10) {
                TextField("Kod veya e-posta", text: $query)
                    .font(.label())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(DS.flour)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.radius)
                            .stroke(DS.stone, lineWidth: 1)
                    )
                    .accessibilityIdentifier("friends.searchField")
                    .onSubmit { Task { await lookup() } }

                Button {
                    Task { await lookup() }
                } label: {
                    if isSearching {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DS.flour)
                            .frame(width: 44, height: 44)
                            .background(DS.ink)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                .accessibilityIdentifier("friends.lookupButton")
            }

            if lookupFailed {
                Text("Kullanıcı bulunamadı.")
                    .font(.captionText())
                    .foregroundStyle(DS.tomato)
            }

            if let result = lookupResult {
                lookupResultRow(result)
            }
        }
    }

    private func lookupResultRow(_ result: SocialLookupDTO) -> some View {
        HStack(spacing: 12) {
            AvatarView(urlString: result.user.avatar_url, name: result.user.name, size: 40)

            Text(result.user.displayName)
                .font(.cardTitle())
                .foregroundStyle(DS.ink)

            Spacer()

            switch result.relationship {
            case "self":
                statusTag("Bu sensin")
            case "friends":
                statusTag("Zaten arkadaşsınız")
            case "pending_outgoing":
                statusTag("Bekliyor")
            default:
                // "none" and "pending_incoming" — sending a request is valid for
                // both; the backend auto-accepts when they already requested us.
                Button {
                    Task {
                        if await APIService.sendFriendRequest(to: result.user.clerk_id) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            lookupResult = nil
                            query = ""
                            await refresh()
                        }
                    }
                } label: {
                    Text("İstek Gönder")
                        .font(.buttonFont())
                        .foregroundStyle(DS.flour)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(DS.ember)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                }
                .accessibilityIdentifier("friends.sendRequestButton")
            }
        }
        .padding(12)
        .background(DS.sand)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private func statusTag(_ text: String) -> some View {
        Text(text)
            .font(.captionText())
            .foregroundStyle(DS.smoke)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DS.stone, lineWidth: 1)
            )
    }

    // MARK: - Requests

    private func requestSection(title: String, requests: [FriendRequestDTO], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)

            VStack(spacing: 2) {
                ForEach(requests) { request in
                    HStack(spacing: 12) {
                        AvatarView(urlString: request.user.avatar_url, name: request.user.name, size: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.user.displayName)
                                .font(.cardTitle())
                                .foregroundStyle(DS.ink)
                            if let when = SocialFormat.relativeDate(request.created_at) {
                                Text(when)
                                    .font(.captionText())
                                    .foregroundStyle(DS.dust)
                            }
                        }

                        Spacer()

                        if isIncoming {
                            Button {
                                Task {
                                    _ = await APIService.acceptFriendRequest(id: request.id)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    await refresh()
                                }
                            } label: {
                                Text("Kabul Et")
                                    .font(.buttonFont())
                                    .foregroundStyle(DS.flour)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .background(DS.ember)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                            }
                            .accessibilityIdentifier("friends.acceptButton")

                            Button {
                                Task {
                                    _ = await APIService.deleteFriendRequest(id: request.id)
                                    await refresh()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.smoke)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.radius)
                                            .stroke(DS.stone, lineWidth: 1)
                                    )
                            }
                            .accessibilityIdentifier("friends.declineButton")
                        } else {
                            Button {
                                Task {
                                    _ = await APIService.deleteFriendRequest(id: request.id)
                                    await refresh()
                                }
                            } label: {
                                Text("İptal")
                                    .font(.buttonFont())
                                    .foregroundStyle(DS.smoke)
                                    .padding(.horizontal, 12)
                                    .frame(height: 34)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.radius)
                                            .stroke(DS.stone, lineWidth: 1)
                                    )
                            }
                            .accessibilityIdentifier("friends.cancelButton")
                        }
                    }
                    .padding(12)
                    .background(DS.sand)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                }
            }
        }
    }

    // MARK: - Friends list

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arkadaşlarım")
                .font(.sectionHeader())
                .foregroundStyle(DS.ink)

            if friends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(DS.dust)
                    Text("Henüz arkadaşın yok")
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                    Text("Kodunu paylaş veya yukarıdan arkadaş ekle.")
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 2) {
                    ForEach(friends) { friend in
                        NavigationLink {
                            FriendRecipesView(friend: friend.user)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(urlString: friend.user.avatar_url, name: friend.user.name, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.user.displayName)
                                        .font(.cardTitle())
                                        .foregroundStyle(DS.ink)
                                    Text("Tariflerine göz at")
                                        .font(.captionText())
                                        .foregroundStyle(DS.smoke)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DS.dust)
                            }
                            .padding(12)
                            .background(DS.sand)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                friendToRemove = friend
                            } label: {
                                Label("Arkadaşı Çıkar", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
                .accessibilityIdentifier("friends.list")
            }
        }
    }

    // MARK: - Data

    private func refresh() async {
        async let meTask = APIService.fetchSocialMe()
        async let friendsTask = APIService.fetchFriends()
        async let requestsTask = APIService.fetchFriendRequests()

        let (me, friendList, requests) = await (meTask, friendsTask, requestsTask)
        friendCode = me?.friend_code
        friends = friendList
        incoming = requests?.incoming ?? []
        outgoing = requests?.outgoing ?? []
    }

    private func lookup() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        lookupFailed = false
        lookupResult = nil

        let result: SocialLookupDTO?
        if trimmed.contains("@") {
            result = await APIService.lookupFriend(email: trimmed.lowercased())
        } else {
            result = await APIService.lookupFriend(code: trimmed.uppercased())
        }

        lookupResult = result
        lookupFailed = result == nil
        isSearching = false
    }
}
