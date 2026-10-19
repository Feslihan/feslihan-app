package com.feslihan.app.ui.screens.recipes

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.repository.RecipeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CookingUiState(
    val title: String = "",
    val steps: List<String> = emptyList(),
    val isLoading: Boolean = true,
)

@HiltViewModel
class CookingViewModel @Inject constructor(
    private val recipeRepository: RecipeRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val recipeId: String = savedStateHandle["recipeId"] ?: ""

    private val _state = MutableStateFlow(CookingUiState())
    val state: StateFlow<CookingUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            val recipe = recipeRepository.getRecipe(recipeId).getOrNull()
            // Instructions arrive as a block; split into numbered/newline steps.
            val steps = recipe?.description.orEmpty()
                .split(Regex("\\r?\\n+"))
                .map { it.trim().removePrefix("•").trim() }
                .map { it.replace(Regex("^\\d+[.)]\\s*"), "") }
                .filter { it.isNotBlank() }
            _state.value = CookingUiState(
                title = recipe?.title.orEmpty(),
                steps = steps.ifEmpty { listOf(recipe?.description.orEmpty()).filter { it.isNotBlank() } },
                isLoading = false,
            )
        }
    }
}
