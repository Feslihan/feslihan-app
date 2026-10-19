package com.feslihan.app.ui.screens.social

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.repository.SocialRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FriendRecipesUiState(
    val friendName: String = "Arkadaş",
    val recipes: List<Recipe> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class FriendRecipesViewModel @Inject constructor(
    private val repository: SocialRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val userId: String = savedStateHandle["userId"] ?: ""
    private val name: String = savedStateHandle["name"] ?: "Arkadaş"

    private val _state = MutableStateFlow(FriendRecipesUiState(friendName = name))
    val state: StateFlow<FriendRecipesUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            repository.friendRecipes(userId)
                .onSuccess { _state.value = _state.value.copy(recipes = it, isLoading = false) }
                .onFailure { _state.value = _state.value.copy(isLoading = false, error = "Tarifler yüklenemedi") }
        }
    }
}
