package com.feslihan.app.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.clerk.api.Clerk
import com.clerk.api.user.User
import com.feslihan.app.data.model.UserSyncRequest
import com.feslihan.app.data.remote.FeslihanApi
import com.feslihan.app.data.session.SessionManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

enum class AuthState { Loading, SignedOut, SignedIn }

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val session: SessionManager,
    private val api: FeslihanApi,
) : ViewModel() {

    val state: StateFlow<AuthState> =
        combine(Clerk.isInitialized, Clerk.userFlow) { initialized, user ->
            when {
                !initialized -> AuthState.Loading
                user != null -> AuthState.SignedIn
                else -> AuthState.SignedOut
            }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AuthState.Loading)

    init {
        // Keep the API session scoped to the signed-in user, and create/refresh the
        // backend user row on sign-in (new users get the 30-day unlimited trial).
        viewModelScope.launch {
            Clerk.userFlow.collect { user ->
                if (user != null) {
                    session.setUser(user.id)
                    runCatching { api.syncUser(user.toSyncRequest()) }
                } else {
                    session.setUser(null)
                }
            }
        }
    }
}

private fun User.toSyncRequest(): UserSyncRequest {
    val fullName = listOfNotNull(firstName, lastName).joinToString(" ").ifBlank { username }
    return UserSyncRequest(
        email = primaryEmailAddress?.emailAddress,
        name = fullName,
        avatarUrl = imageUrl,
    )
}
