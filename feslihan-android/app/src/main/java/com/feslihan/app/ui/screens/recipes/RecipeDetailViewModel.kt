package com.feslihan.app.ui.screens.recipes

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.IngredientMeasure
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.repository.RecipeRepository
import com.feslihan.app.data.repository.UserDataRepository
import com.feslihan.app.ui.components.Availability
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class IngredientLine(val measure: IngredientMeasure, val availability: Availability)

data class RecipeDetailUiState(
    val recipe: Recipe? = null,
    val ingredients: List<IngredientLine> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class RecipeDetailViewModel @Inject constructor(
    private val recipeRepository: RecipeRepository,
    private val userDataRepository: UserDataRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val recipeId: String = savedStateHandle["recipeId"] ?: ""

    private val _state = MutableStateFlow(RecipeDetailUiState())
    val state: StateFlow<RecipeDetailUiState> = _state.asStateFlow()

    init { load() }

    private fun load() {
        viewModelScope.launch {
            val recipe = recipeRepository.getRecipe(recipeId).getOrNull()
            if (recipe == null) {
                _state.value = RecipeDetailUiState(isLoading = false, error = "Tarif yüklenemedi")
                return@launch
            }
            // Cross-check ingredients against the pantry for the have/need dots.
            val pantryNames = userDataRepository.pantry().getOrNull()
                ?.map { it.ingredientName.lowercase() }?.toSet() ?: emptySet()
            val lines = recipe.ingredientsWithMeasures.map { m ->
                val key = (m.baseName ?: m.name).lowercase()
                val have = pantryNames.any { it == key || it.contains(key) || key.contains(it) }
                IngredientLine(m, if (have) Availability.Have else Availability.Need)
            }
            _state.value = RecipeDetailUiState(recipe = recipe, ingredients = lines, isLoading = false)
        }
    }
}
