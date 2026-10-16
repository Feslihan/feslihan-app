import SwiftUI

/// Read-only view of a friend's saved recipes (requires an accepted
/// connection — the backend enforces it). Tapping a recipe opens the detail
/// screen in browse mode with a "save to my library" action.
struct FriendRecipesView: View {
    let friend: SocialUserDTO

    @State private var recipes: [RecipeDTO] = []
    @State private var isLoading = true
    @State private var selectedRecipe: Recipe?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 80)
            } else if recipes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(DS.dust)
                    Text("Henüz kayıtlı tarif yok")
                        .font(.label())
                        .foregroundStyle(DS.smoke)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(Array(recipes.enumerated()), id: \.offset) { _, dto in
                        Button {
                            Task { await open(dto) }
                        } label: {
                            FriendRecipeCard(dto: dto)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 40)
                .accessibilityIdentifier("friendRecipes.grid")
            }
        }
        .background(DS.cream)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(friend.displayName)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(DS.ink)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe, context: .friendBrowse)
        }
        .task {
            recipes = await APIService.fetchFriendRecipes(userId: friend.clerk_id)
            isLoading = false
        }
    }

    /// Build an unattached local Recipe from the DTO (with its thumbnail) and
    /// push the detail screen. The recipe is NOT inserted into SwiftData —
    /// saving happens explicitly via the detail screen's save button.
    private func open(_ dto: RecipeDTO) async {
        var thumbnailData: Data?
        if let path = dto.thumbnail_url {
            let fullURL = path.hasPrefix("http") ? path : "\(APIService.baseURL)\(path)"
            thumbnailData = await CaptionService.downloadImage(from: fullURL)
        }
        selectedRecipe = dto.toRecipe(thumbnailData: thumbnailData)
    }
}

/// Grid card rendering a backend RecipeDTO (remote thumbnail, not SwiftData).
private struct FriendRecipeCard: View {
    let dto: RecipeDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let path = dto.thumbnail_url,
                   let url = URL(string: path.hasPrefix("http") ? path : "\(APIService.baseURL)\(path)") {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        thumbnailPlaceholder
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))

            VStack(alignment: .leading, spacing: 4) {
                Text(dto.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 38, alignment: .top)

                if let minutes = dto.cooking_time_minutes {
                    Text(minutes >= 60 ? "\(minutes / 60) sa \(minutes % 60 > 0 ? "\(minutes % 60) dk" : "")" : "\(minutes) dk")
                        .font(.captionText())
                        .foregroundStyle(DS.dust)
                }
            }
            .padding(.top, 9)
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            DS.stone.opacity(0.3)
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DS.dust)
        }
    }
}
