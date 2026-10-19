package com.feslihan.app.ui.screens.neyesem

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.repository.RecipeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class NeYesemPhase { Wizard, Loading, Swipe }

data class NeYesemState(
    val phase: NeYesemPhase = NeYesemPhase.Wizard,
    val timeChoice: String? = null, // "15", "45", "60"
    val deck: List<Recipe> = emptyList(),
    val index: Int = 0,
    val likedCount: Int = 0,
    val error: String? = null,
) {
    val current: Recipe? = deck.getOrNull(index)
    val finished: Boolean = deck.isNotEmpty() && index >= deck.size
}

@HiltViewModel
class NeYesemViewModel @Inject constructor(
    private val repository: RecipeRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(NeYesemState())
    val state: StateFlow<NeYesemState> = _state.asStateFlow()

    fun setTime(v: String) { _state.value = _state.value.copy(timeChoice = v) }

    fun start() {
        val max = _state.value.timeChoice?.toIntOrNull()
        _state.value = _state.value.copy(phase = NeYesemPhase.Loading, error = null)
        viewModelScope.launch {
            repository.catalog()
                .onSuccess { all ->
                    val deck = all.filter { max == null || (it.cookingTimeMinutes ?: 999) <= max }.shuffled()
                    _state.value = _state.value.copy(phase = NeYesemPhase.Swipe, deck = deck, index = 0)
                }
                .onFailure { _state.value = _state.value.copy(phase = NeYesemPhase.Swipe, error = "Öneriler yüklenemedi") }
        }
    }

    fun like() {
        val recipe = _state.value.current
        _state.value = _state.value.copy(index = _state.value.index + 1, likedCount = _state.value.likedCount + 1)
        recipe?.id?.let { id -> viewModelScope.launch { repository.setFavorite(id, true) } }
    }

    fun skip() { _state.value = _state.value.copy(index = _state.value.index + 1) }
}
