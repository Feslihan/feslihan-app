package com.feslihan.app.ui.screens.mealprep

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.SavedPlan
import com.feslihan.app.data.repository.MealPlanRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SavedPlansState(
    val plans: List<SavedPlan> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
)

@HiltViewModel
class SavedPlansViewModel @Inject constructor(
    private val repository: MealPlanRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(SavedPlansState())
    val state: StateFlow<SavedPlansState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            repository.saved()
                .onSuccess { _state.value = SavedPlansState(plans = it, isLoading = false) }
                .onFailure { _state.value = SavedPlansState(isLoading = false, error = "Planlar yüklenemedi") }
        }
    }

    fun delete(plan: SavedPlan) {
        _state.value = _state.value.copy(plans = _state.value.plans.filterNot { it.id == plan.id })
        viewModelScope.launch { repository.delete(plan.id).onFailure { load() } }
    }
}
