package com.feslihan.app.data.repository

import com.feslihan.app.data.model.Friend
import com.feslihan.app.data.model.FriendRequests
import com.feslihan.app.data.model.FollowRequest
import com.feslihan.app.data.model.Recipe
import com.feslihan.app.data.model.ShareInboxItem
import com.feslihan.app.data.model.ShareRequest
import com.feslihan.app.data.model.SocialLookup
import com.feslihan.app.data.model.SocialMe
import com.feslihan.app.data.remote.FeslihanApi
import javax.inject.Inject
import javax.inject.Singleton

/** Outcome of a friend-code / e-mail lookup, so the UI can tell 404 apart from errors. */
sealed interface LookupResult {
    data class Found(val lookup: SocialLookup) : LookupResult
    object NotFound : LookupResult
    object BadQuery : LookupResult
}

/** Outcome of sending a friend request — 409 carries a reason the UI surfaces. */
enum class RequestOutcome { Sent, AlreadyFriends, Pending, Failed }

/**
 * Friends, requests, and recipe shares. Thin wrappers over the social API, which
 * trusts the Clerk token's identity (no `:userId` for the current user) and gates
 * cross-user reads on an accepted connection. Result-wrapped so screens can show
 * error states; the few status-sensitive endpoints map codes to typed outcomes.
 */
@Singleton
class SocialRepository @Inject constructor(
    private val api: FeslihanApi,
) {
    suspend fun me(): Result<SocialMe> = runCatching { api.socialMe() }

    /** Lookup by friend code OR e-mail. 404 → NotFound, 400 → BadQuery (not errors). */
    suspend fun lookup(code: String? = null, email: String? = null): Result<LookupResult> = runCatching {
        val res = api.socialLookup(code = code, email = email)
        when {
            res.isSuccessful -> res.body()?.let { LookupResult.Found(it) } ?: LookupResult.NotFound
            res.code() == 404 -> LookupResult.NotFound
            res.code() == 400 -> LookupResult.BadQuery
            else -> error("lookup failed: ${res.code()}")
        }
    }

    suspend fun sendRequest(toUserId: String): Result<RequestOutcome> = runCatching {
        val res = api.sendFriendRequest(FollowRequest(toUserId))
        when {
            res.isSuccessful -> RequestOutcome.Sent
            res.code() == 409 -> {
                val body = res.errorBody()?.string().orEmpty()
                when {
                    body.contains("already_friends") -> RequestOutcome.AlreadyFriends
                    body.contains("request_pending") -> RequestOutcome.Pending
                    else -> RequestOutcome.Failed
                }
            }
            else -> RequestOutcome.Failed
        }
    }

    suspend fun requests(): Result<FriendRequests> = runCatching { api.friendRequests() }

    suspend fun acceptRequest(id: String): Result<Unit> = runCatching {
        val res = api.acceptFriendRequest(id)
        if (!res.isSuccessful) error("accept failed: ${res.code()}")
    }

    suspend fun declineRequest(id: String): Result<Unit> = runCatching {
        val res = api.declineFriendRequest(id)
        if (!res.isSuccessful) error("decline failed: ${res.code()}")
    }

    suspend fun friends(): Result<List<Friend>> = runCatching { api.friends() }

    suspend fun unfriend(userId: String): Result<Unit> = runCatching {
        val res = api.unfriend(userId)
        if (!res.isSuccessful) error("unfriend failed: ${res.code()}")
    }

    /** A friend's saved recipes. 403 (not connected) surfaces as a failure. */
    suspend fun friendRecipes(userId: String): Result<List<Recipe>> = runCatching {
        val res = api.friendRecipes(userId)
        if (!res.isSuccessful) error("friend recipes failed: ${res.code()}")
        res.body().orEmpty()
    }

    suspend fun shareRecipe(toUserId: String, recipeId: String, message: String? = null): Result<Unit> = runCatching {
        val res = api.shareRecipe(ShareRequest(toUserId = toUserId, recipeId = recipeId, message = message))
        if (!res.isSuccessful) error("share failed: ${res.code()}")
    }

    suspend fun shareInbox(status: String = "pending"): Result<List<ShareInboxItem>> =
        runCatching { api.shareInbox(status) }

    /** Accept a shared recipe into the library. Returns whether it was already saved. */
    suspend fun acceptShare(id: String): Result<Boolean> = runCatching { api.acceptShare(id).alreadySaved }

    suspend fun dismissShare(id: String): Result<Unit> = runCatching { api.dismissShare(id); Unit }
}
