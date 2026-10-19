package com.feslihan.app.ui.screens.social

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Friend
import com.feslihan.app.data.repository.SocialRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SharePickerUiState(
    val friends: List<Friend> = emptyList(),
    val isLoading: Boolean = true,
    val sending: Boolean = false,
)

@HiltViewModel
class SharePickerViewModel @Inject constructor(
    private val repository: SocialRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(SharePickerUiState())
    val state: StateFlow<SharePickerUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repository.friends()
                .onSuccess { _state.value = _state.value.copy(friends = it, isLoading = false) }
                .onFailure { _state.value = _state.value.copy(isLoading = false) }
        }
    }

    fun send(toUserId: String, recipeId: String, message: String?, onResult: (String) -> Unit) {
        if (_state.value.sending) return
        viewModelScope.launch {
            _state.value = _state.value.copy(sending = true)
            repository.shareRecipe(toUserId = toUserId, recipeId = recipeId, message = message)
                .onSuccess { onResult("Tarif gönderildi") }
                .onFailure { onResult("Gönderilemedi, tekrar dene") }
            _state.value = _state.value.copy(sending = false)
        }
    }
}
