package com.feslihan.app.ui.screens.addrecipe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.model.ScrapeWebRequest
import com.feslihan.app.data.remote.FeslihanApi
import com.feslihan.app.data.repository.RecipeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class AddPhase { Idle, Processing, Done, Error }

/** Four pipeline steps shown as a checklist (mirrors the design). */
enum class Step { VideoInfo, Audio, Transcribe, Analyze }

data class AddRecipeState(
    val url: String = "",
    val phase: AddPhase = AddPhase.Idle,
    val activeStep: Step = Step.VideoInfo,
    val completedSteps: Set<Step> = emptySet(),
    val result: Recipe? = null,
    val saved: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class AddRecipeViewModel @Inject constructor(
    private val repository: RecipeRepository,
    private val api: FeslihanApi,
) : ViewModel() {

    private val _state = MutableStateFlow(AddRecipeState())
    val state: StateFlow<AddRecipeState> = _state.asStateFlow()

    fun setUrl(v: String) { _state.value = _state.value.copy(url = v) }

    fun process() {
        val url = _state.value.url.trim()
        if (url.isBlank()) return
        _state.value = _state.value.copy(phase = AddPhase.Processing, completedSteps = emptySet(), activeStep = Step.VideoInfo, error = null)
        viewModelScope.launch {
            // 1) Cache lookup — free, instant if the URL is already in the catalog.
            advance(Step.VideoInfo)
            val cached = repository.lookup(url)
            if (cached != null) {
                _state.value = _state.value.copy(
                    phase = AddPhase.Done,
                    completedSteps = Step.values().toSet(),
                    result = cached,
                )
                return@launch
            }
            // 2) Not cached → try the web-scrape path (works for recipe sites).
            advance(Step.Audio)
            advance(Step.Transcribe)
            val scraped = runCatching { api.scrapeWeb(ScrapeWebRequest(url)) }.getOrNull()
            advance(Step.Analyze)
            val recipe = scraped?.takeIf { it.isSuccessful }?.body()
            if (recipe != null && recipe.title.isNotBlank()) {
                _state.value = _state.value.copy(phase = AddPhase.Done, completedSteps = Step.values().toSet(), result = recipe)
            } else {
                _state.value = _state.value.copy(
                    phase = AddPhase.Error,
                    error = "Bu bağlantıdan tarif çıkarılamadı. Video bağlantıları (TikTok/Instagram) yakında desteklenecek.",
                )
            }
        }
    }

    private suspend fun advance(step: Step) {
        _state.value = _state.value.copy(activeStep = step)
        delay(450) // let the checklist animation read naturally
        _state.value = _state.value.copy(completedSteps = _state.value.completedSteps + step)
    }

    fun save() {
        val recipe = _state.value.result ?: return
        viewModelScope.launch {
            repository.save(recipe.copy(url = recipe.url.ifBlank { _state.value.url.trim() }))
                .onSuccess { _state.value = _state.value.copy(saved = true) }
                .onFailure { _state.value = _state.value.copy(error = "Kaydedilemedi") }
        }
    }

    fun reset() { _state.value = AddRecipeState() }
}
