package com.feslihan.app.ui.screens.social

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.model.Friend
import com.feslihan.app.data.model.FriendRequest
import com.feslihan.app.data.repository.LookupResult
import com.feslihan.app.data.repository.RequestOutcome
import com.feslihan.app.data.repository.SocialRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FriendsUiState(
    val friendCode: String? = null,
    val pendingShareCount: Int = 0,
    val incoming: List<FriendRequest> = emptyList(),
    val outgoing: List<FriendRequest> = emptyList(),
    val friends: List<Friend> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    // Lookup sub-state
    val lookupLoading: Boolean = false,
    val lookupResult: LookupResult? = null,
    // One-shot banner message (cleared by the screen after showing)
    val message: String? = null,
)

@HiltViewModel
class FriendsViewModel @Inject constructor(
    private val repository: SocialRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(FriendsUiState())
    val state: StateFlow<FriendsUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            val me = repository.me()
            val reqs = repository.requests()
            val friends = repository.friends()
            if (me.isFailure && reqs.isFailure && friends.isFailure) {
                _state.value = _state.value.copy(isLoading = false, error = "Yüklenemedi")
                return@launch
            }
            _state.value = _state.value.copy(
                friendCode = me.getOrNull()?.friendCode,
                pendingShareCount = me.getOrNull()?.pendingShareCount ?: 0,
                incoming = reqs.getOrNull()?.incoming ?: emptyList(),
                outgoing = reqs.getOrNull()?.outgoing ?: emptyList(),
                friends = friends.getOrNull() ?: emptyList(),
                isLoading = false,
                error = null,
            )
        }
    }

    /** Lookup by friend code or e-mail. "@" routes to the e-mail param, else code. */
    fun lookup(query: String) {
        val q = query.trim()
        if (q.isBlank()) return
        viewModelScope.launch {
            _state.value = _state.value.copy(lookupLoading = true, lookupResult = null)
            val result = if (q.contains("@")) repository.lookup(email = q) else repository.lookup(code = q.uppercase())
            _state.value = _state.value.copy(
                lookupLoading = false,
                lookupResult = result.getOrNull() ?: LookupResult.NotFound,
            )
        }
    }

    fun clearLookup() { _state.value = _state.value.copy(lookupResult = null) }

    fun sendRequest(toUserId: String) {
        viewModelScope.launch {
            val outcome = repository.sendRequest(toUserId).getOrDefault(RequestOutcome.Failed)
            val msg = when (outcome) {
                RequestOutcome.Sent -> "İstek gönderildi"
                RequestOutcome.AlreadyFriends -> "Zaten arkadaşsınız"
                RequestOutcome.Pending -> "İstek zaten gönderilmiş"
                RequestOutcome.Failed -> "İstek gönderilemedi"
            }
            _state.value = _state.value.copy(message = msg, lookupResult = null)
            load()
        }
    }

    fun accept(request: FriendRequest) {
        viewModelScope.launch {
            repository.acceptRequest(request.id)
                .onSuccess { _state.value = _state.value.copy(message = "Arkadaş eklendi") }
            load()
        }
    }

    fun decline(request: FriendRequest) {
        viewModelScope.launch { repository.declineRequest(request.id); load() }
    }

    fun cancelOutgoing(request: FriendRequest) {
        viewModelScope.launch { repository.declineRequest(request.id); load() }
    }

    fun unfriend(friend: Friend) {
        _state.value = _state.value.copy(friends = _state.value.friends.filterNot { it.user.clerkId == friend.user.clerkId })
        viewModelScope.launch { repository.unfriend(friend.user.clerkId).onFailure { load() } }
    }

    fun consumeMessage() { _state.value = _state.value.copy(message = null) }
}
