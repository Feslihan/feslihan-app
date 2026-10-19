package com.feslihan.app.data.remote

import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supplies the current Clerk session JWT. Implemented by the auth layer once the
 * Clerk Android SDK is wired (see README "Auth"). Returns null when signed out.
 */
fun interface TokenProvider {
    /** Blocking fetch of a fresh session token (called off the main thread by OkHttp). */
    fun currentToken(): String?
}

/**
 * Attaches `Authorization: Bearer <jwt>` to every request. Public routes
 * (images, legal) still work without it; the server ignores the header there.
 */
@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenProvider: TokenProvider,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = tokenProvider.currentToken()
        val request = if (token != null) {
            chain.request().newBuilder()
                .addHeader("Authorization", "Bearer $token")
                .build()
        } else {
            chain.request()
        }
        return chain.proceed(request)
    }
}
