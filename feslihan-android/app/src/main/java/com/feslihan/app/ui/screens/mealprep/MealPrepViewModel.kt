package com.feslihan.app.ui.screens.mealprep

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.MealPlanRequest
import com.feslihan.app.data.model.MealPlanResult
import com.feslihan.app.data.repository.MealPlanError
import com.feslihan.app.data.repository.MealPlanRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class MealPrepPhase { Wizard, Generating, Result, Error }

data class MealPrepState(
    val phase: MealPrepPhase = MealPrepPhase.Wizard,
    val step: Int = 1,
    val peopleCount: String? = null,
    val mealsPerDay: String? = null,
    val eatingStyles: Set<String> = emptySet(),
    val period: String? = null,
    val hasKids: Boolean? = null,
    val prepStyle: String? = null,
    val budget: String? = null,
    val result: MealPlanResult? = null,
    val error: String? = null,
    val premiumRequired: Boolean = false,
    val saved: Boolean = false,
) {
    val totalSteps = 7
    val canAdvance: Boolean = when (step) {
        1 -> peopleCount != null
        2 -> mealsPerDay != null
        3 -> eatingStyles.isNotEmpty()
        4 -> period != null
        5 -> hasKids != null
        6 -> prepStyle != null
        7 -> budget != null
        else -> false
    }
}

@HiltViewModel
class MealPrepViewModel @Inject constructor(
    private val repository: MealPlanRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(MealPrepState())
    val state: StateFlow<MealPrepState> = _state.asStateFlow()

    fun setPeople(v: String) { _state.value = _state.value.copy(peopleCount = v) }
    fun setMeals(v: String) { _state.value = _state.value.copy(mealsPerDay = v) }
    fun toggleStyle(v: String) {
        val cur = _state.value.eatingStyles
        _state.value = _state.value.copy(eatingStyles = if (v in cur) cur - v else cur + v)
    }
    fun setPeriod(v: String) { _state.value = _state.value.copy(period = v) }
    fun setKids(v: Boolean) { _state.value = _state.value.copy(hasKids = v) }
    fun setPrep(v: String) { _state.value = _state.value.copy(prepStyle = v) }
    fun setBudget(v: String) { _state.value = _state.value.copy(budget = v) }

    fun back() {
        val s = _state.value
        if (s.step > 1) _state.value = s.copy(step = s.step - 1)
    }

    /** Advance; on the last step kick off generation. Returns false if at step 1 (caller pops). */
    fun next(): Boolean {
        val s = _state.value
        if (!s.canAdvance) return true
        if (s.step < s.totalSteps) {
            _state.value = s.copy(step = s.step + 1)
        } else {
            generate()
        }
        return true
    }

    private fun generate() {
        val s = _state.value
        _state.value = s.copy(phase = MealPrepPhase.Generating, error = null, premiumRequired = false)
        viewModelScope.launch {
            val request = MealPlanRequest(
                peopleCount = s.peopleCount ?: "2",
                mealsPerDay = s.mealsPerDay ?: "3",
                eatingStyles = s.eatingStyles.toList(),
                period = s.period ?: "1 hafta",
                hasKids = s.hasKids ?: false,
                kidsCount = if (s.hasKids == true) 1 else 0,
                prepStyle = s.prepStyle ?: "günlük",
                budget = s.budget ?: "dengeli",
                userId = "", // filled by repository from the session
            )
            repository.generate(request)
                .onSuccess { _state.value = _state.value.copy(phase = MealPrepPhase.Result, result = it) }
                .onFailure { e ->
                    val premium = (e as? MealPlanError)?.code == 402
                    _state.value = _state.value.copy(
                        phase = MealPrepPhase.Error,
                        premiumRequired = premium,
                        error = if (premium) "Haftalık plan Feslihan+ gerektirir." else "Plan oluşturulamadı.",
                    )
                }
        }
    }

    fun save(name: String) {
        val result = _state.value.result ?: return
        viewModelScope.launch {
            repository.save(name, result).onSuccess { _state.value = _state.value.copy(saved = true) }
        }
    }

    fun restart() { _state.value = MealPrepState() }
}
