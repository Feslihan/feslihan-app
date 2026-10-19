package com.feslihan.app.ui.screens.pantry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.PantryItem
import com.feslihan.app.data.repository.UserDataRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PantryUiState(
    val items: List<PantryItem> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class PantryViewModel @Inject constructor(
    private val repository: UserDataRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(PantryUiState())
    val state: StateFlow<PantryUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            repository.pantry()
                .onSuccess { _state.value = PantryUiState(items = it, isLoading = false) }
                .onFailure { _state.value = PantryUiState(isLoading = false, error = "Kiler yüklenemedi") }
        }
    }

    fun add(name: String) {
        if (name.isBlank()) return
        viewModelScope.launch { repository.addToPantry(listOf(name.trim())); load() }
    }

    fun remove(item: PantryItem) {
        _state.value = _state.value.copy(items = _state.value.items.filterNot { it.id == item.id })
        viewModelScope.launch { repository.removeFromPantry(item.ingredientId).onFailure { load() } }
    }
}
