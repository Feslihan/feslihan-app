package com.feslihan.app.data.session

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Holds the current authenticated user. Populated by the auth layer (Clerk) on
 * sign-in; cleared on sign-out. Screens/repositories read [userId] to scope
 * `/users/:userId/...` calls. Null = signed out.
 */
@Singleton
class SessionManager @Inject constructor() {
    private val _userId = MutableStateFlow<String?>(null)
    val userId: StateFlow<String?> = _userId.asStateFlow()

    fun requireUserId(): String =
        _userId.value ?: error("No authenticated user — caller must gate on sign-in state")

    fun setUser(userId: String?) { _userId.value = userId }
}
