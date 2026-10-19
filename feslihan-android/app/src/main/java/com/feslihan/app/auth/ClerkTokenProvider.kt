package com.feslihan.app.auth

import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import com.feslihan.app.data.remote.TokenProvider
import kotlinx.coroutines.runBlocking
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supplies the current Clerk session JWT for the OkHttp [com.feslihan.app.data.remote.AuthInterceptor].
 * `getToken()` without a template returns the cached session token (fast), so the
 * blocking call inside the interceptor (already off the main thread) is cheap.
 */
@Singleton
class ClerkTokenProvider @Inject constructor() : TokenProvider {
    override fun currentToken(): String? = runBlocking {
        when (val result = Clerk.auth.getToken()) {
            is ClerkResult.Success -> result.value
            is ClerkResult.Failure -> null
        }
    }
}
