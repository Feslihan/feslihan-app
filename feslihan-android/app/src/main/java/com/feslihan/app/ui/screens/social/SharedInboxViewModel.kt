package com.feslihan.app.ui.screens.social

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.ShareInboxItem
import com.feslihan.app.data.repository.SocialRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SharedInboxUiState(
    val items: List<ShareInboxItem> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val message: String? = null,
)

@HiltViewModel
class SharedInboxViewModel @Inject constructor(
    private val repository: SocialRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(SharedInboxUiState())
    val state: StateFlow<SharedInboxUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            repository.shareInbox("pending")
                .onSuccess { _state.value = SharedInboxUiState(items = it, isLoading = false) }
                .onFailure { _state.value = SharedInboxUiState(isLoading = false, error = "Gelen tarifler yüklenemedi") }
        }
    }

    fun accept(item: ShareInboxItem) {
        viewModelScope.launch {
            repository.acceptShare(item.id)
                .onSuccess { alreadySaved ->
                    _state.value = _state.value.copy(
                        items = _state.value.items.filterNot { it.id == item.id },
                        message = if (alreadySaved) "Zaten kitaplığında" else "Kitaplığına eklendi",
                    )
                }
                .onFailure { _state.value = _state.value.copy(message = "Eklenemedi, tekrar dene") }
        }
    }

    fun dismiss(item: ShareInboxItem) {
        _state.value = _state.value.copy(items = _state.value.items.filterNot { it.id == item.id })
        viewModelScope.launch { repository.dismissShare(item.id).onFailure { load() } }
    }

    fun consumeMessage() { _state.value = _state.value.copy(message = null) }
}
