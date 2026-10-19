package com.feslihan.app.ui.screens.recipes

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.repository.RecipeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RecipeListUiState(
    val isRefreshing: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class RecipeListViewModel @Inject constructor(
    private val repository: RecipeRepository,
) : ViewModel() {

    val recipes: StateFlow<List<Recipe>> = repository.library
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _uiState = MutableStateFlow(RecipeListUiState())
    val uiState: StateFlow<RecipeListUiState> = _uiState.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshing = true, error = null)
            val result = repository.refreshLibrary()
            _uiState.value = RecipeListUiState(
                isRefreshing = false,
                error = result.exceptionOrNull()?.let { "Tarifler yüklenemedi" },
            )
        }
    }

    fun toggleFavorite(recipe: Recipe) {
        val id = recipe.id ?: return
        viewModelScope.launch { repository.setFavorite(id, !(recipe.isFavorite ?: false)) }
    }
}
