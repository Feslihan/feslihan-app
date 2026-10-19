package com.feslihan.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SocialMe(
    @SerialName("friend_code") val friendCode: String,
    @SerialName("incoming_request_count") val incomingRequestCount: Int = 0,
    @SerialName("pending_share_count") val pendingShareCount: Int = 0,
)

@Serializable
data class SocialUser(
    @SerialName("clerk_id") val clerkId: String,
    val name: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

/** relationship ∈ none | self | pending_outgoing | pending_incoming | friends */
@Serializable
data class SocialLookup(
    val user: SocialUser,
    val relationship: String,
)

@Serializable
data class FriendRequest(
    val id: String,
    val user: SocialUser,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class FriendRequests(
    val incoming: List<FriendRequest> = emptyList(),
    val outgoing: List<FriendRequest> = emptyList(),
)

@Serializable
data class Friend(
    val user: SocialUser,
    @SerialName("connected_at") val connectedAt: String? = null,
)

@Serializable
data class SharedRecipeSummary(
    val id: String,
    val title: String,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    @SerialName("cooking_time_minutes") val cookingTimeMinutes: Int? = null,
    val platform: String? = null,
)

@Serializable
data class ShareInboxItem(
    val id: String,
    val message: String? = null,
    val status: String,
    @SerialName("created_at") val createdAt: String,
    val sender: SocialUser,
    val recipe: SharedRecipeSummary,
)

// Request bodies
@Serializable
data class FollowRequest(@SerialName("to_user_id") val toUserId: String)

@Serializable
data class ShareRequest(
    @SerialName("to_user_id") val toUserId: String,
    @SerialName("recipe_id") val recipeId: String,
    val message: String? = null,
)
