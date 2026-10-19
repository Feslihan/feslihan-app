package com.feslihan.app.ui.screens.shopping

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.ShoppingItem
import com.feslihan.app.data.repository.UserDataRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ShoppingUiState(
    val items: List<ShoppingItem> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class ShoppingListViewModel @Inject constructor(
    private val repository: UserDataRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(ShoppingUiState())
    val state: StateFlow<ShoppingUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            repository.shoppingList()
                .onSuccess { _state.value = ShoppingUiState(items = it, isLoading = false) }
                .onFailure { _state.value = ShoppingUiState(isLoading = false, error = "Liste yüklenemedi") }
        }
    }

    fun toggle(item: ShoppingItem) {
        // Optimistic flip, then persist.
        val flipped = _state.value.items.map {
            if (it.id == item.id) it.copy(isChecked = !it.isChecked) else it
        }
        _state.value = _state.value.copy(items = flipped)
        viewModelScope.launch {
            repository.setChecked(item.id, !item.isChecked).onFailure { load() }
        }
    }

    fun remove(item: ShoppingItem) {
        _state.value = _state.value.copy(items = _state.value.items.filterNot { it.id == item.id })
        viewModelScope.launch { repository.removeFromShopping(item.id).onFailure { load() } }
    }

    fun add(name: String) {
        if (name.isBlank()) return
        viewModelScope.launch { repository.addToShopping(listOf(name.trim())); load() }
    }

    fun clearChecked() {
        val checked = _state.value.items.filter { it.isChecked }
        if (checked.isEmpty()) return
        _state.value = _state.value.copy(items = _state.value.items.filterNot { it.isChecked })
        viewModelScope.launch {
            checked.forEach { repository.removeFromShopping(it.id) }
            load()
        }
    }
}
