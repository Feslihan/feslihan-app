import SwiftUI
import ClerkKit

/// Reusable ingredient list component.
/// Shows pantry status (green dot = have, red dot = need) and add-to-shopping-list button.
/// Groups ingredients by section when sections are present.
struct IngredientsView: View {
    let ingredients: [Ingredient]
    @State private var pantryNames: Set<String> = []
    @State private var shoppingListNames: Set<String> = []
    @State private var isLoaded = false

    init(ingredients: [Ingredient]) {
        self.ingredients = ingredients
    }

    /// Convenience init for plain string lists (e.g. shopping list / meal prep).
    init(items: [String]) {
        self.ingredients = items.map { Ingredient(name: $0, amount: "") }
    }

    private var hasSections: Bool {
        ingredients.contains { $0.section != nil }
    }

    private var groupedIngredients: [(section: String?, items: [Ingredient])] {
        var groups: [(section: String?, items: [Ingredient])] = []
        var currentSection: String? = nil
        var currentItems: [Ingredient] = []

        for ingredient in ingredients {
            let sec = ingredient.section
            if sec != currentSection {
                if !currentItems.isEmpty {
                    groups.append((section: currentSection, items: currentItems))
                }
                currentSection = sec
                currentItems = [ingredient]
            } else {
                currentItems.append(ingredient)
            }
        }
        if !currentItems.isEmpty {
            groups.append((section: currentSection, items: currentItems))
        }
        return groups
    }

    var body: some View {
        VStack(spacing: 0) {
            // Legend
            if isLoaded {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.ember).frame(width: 8, height: 8)
                        Text("Var").font(.captionText()).foregroundStyle(DS.dust)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(DS.tomato).frame(width: 8, height: 8)
                        Text("Almalı").font(.captionText()).foregroundStyle(DS.dust)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }

            if hasSections {
                sectionsView
            } else {
                flatListView(ingredients)
            }
        }
        .task {
            await loadPantry()
        }
    }

    // MARK: - Sections View

    private var sectionsView: some View {
        VStack(spacing: 16) {
            ForEach(Array(groupedIngredients.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 0) {
                    if let section = group.section {
                        Text(section)
                            .font(.eyebrow())
                            .tracking(1.2)
                            .foregroundStyle(DS.dust)
                            .textCase(.uppercase)
                            .padding(.bottom, 8)
                    }
                    flatListView(group.items)
                }
            }
        }
    }

    // MARK: - Flat List

    private func flatListView(_ items: [Ingredient]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, ingredient in
                let raw = ingredient.baseName ?? ingredient.name
                let key = raw.replacingOccurrences(of: "\\s*\\(.*?\\)\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces).lowercased()
                let inPantry = pantryNames.contains(key)
                let inCart = shoppingListNames.contains(key)

                HStack(spacing: 12) {
                    // Pantry status dot
                    if isLoaded {
                        Circle()
                            .fill(inPantry ? DS.ember : DS.tomato)
                            .frame(width: 8, height: 8)
                    }

                    Text(ingredient.name)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.ink)

                    Spacer()

                    if !ingredient.amount.isEmpty {
                        Text(ingredient.amount)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.smoke)
                    }

                    // Shopping list status
                    if isLoaded && !inPantry {
                        if inCart {
                            Image(systemName: "cart.badge.checkmark")
                                .font(.system(size: 15))
                                .foregroundStyle(DS.ember)
                        } else {
                            Button {
                                Task { await addToShoppingList(ingredient.baseName ?? ingredient.name) }
                            } label: {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.ember)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 12)

                if index < items.count - 1 {
                    Rectangle().fill(DS.stone).frame(height: 1)
                }
            }
        }
    }

    private func loadPantry() async {
        guard let userId = Clerk.shared.user?.id else { return }
        async let pantryTask = APIService.fetchPantry(userId: userId)
        async let shoppingTask = APIService.fetchShoppingList(userId: userId)
        let pantryItems = await pantryTask
        let shoppingItems = await shoppingTask
        pantryNames = Set(pantryItems.map { $0.ingredient_name.lowercased() })
        shoppingListNames = Set(shoppingItems.map { $0.ingredient_name.lowercased() })
        isLoaded = true
    }

    private func addToShoppingList(_ name: String) async {
        guard let userId = Clerk.shared.user?.id else { return }
        let success = await APIService.addToShoppingList(userId: userId, ingredientNames: [name])
        if success {
            shoppingListNames.insert(name.lowercased())
        }
    }
}
