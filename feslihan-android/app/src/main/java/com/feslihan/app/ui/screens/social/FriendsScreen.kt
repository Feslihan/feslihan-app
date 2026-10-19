package com.feslihan.app.ui.screens.social

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.MoveToInbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.data.model.Friend
import com.feslihan.app.data.model.FriendRequest
import com.feslihan.app.data.repository.LookupResult
import com.feslihan.app.ui.components.BackButton
import com.feslihan.app.ui.components.Eyebrow
import com.feslihan.app.ui.components.UserAvatar
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.ds

/**
 * Arkadaşlar (iOS FriendsView). Friend code to share, lookup-by-code/email to add,
 * incoming/outgoing request queues, and the friends list. Editorial styling: serif
 * title, hairline cards, basil accents. The inbox action badges pending shares.
 */
@Composable
fun FriendsScreen(
    onBack: () -> Unit,
    onOpenFriend: (userId: String, name: String) -> Unit,
    onOpenInbox: () -> Unit,
    viewModel: FriendsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var query by remember { mutableStateOf("") }

    LaunchedEffect(state.message) {
        state.message?.let { Toast.makeText(context, it, Toast.LENGTH_SHORT).show(); viewModel.consumeMessage() }
    }

    Scaffold(containerColor = MaterialTheme.ds.cream) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                BackButton(onClick = onBack)
                Spacer(Modifier.size(4.dp))
                Text("Arkadaşlar", style = DisplayXLTextStyle.copy(fontSize = 28.sp), color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
                InboxAction(badge = state.pendingShareCount, onClick = onOpenInbox)
            }

            if (state.isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.ds.ember)
                }
                return@Column
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 22.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item { Spacer(Modifier.height(8.dp)) }

                // Friend code
                item {
                    Eyebrow("Arkadaş Kodum")
                    Spacer(Modifier.height(8.dp))
                    FriendCodeCard(code = state.friendCode)
                }
                item { Spacer(Modifier.height(10.dp)) }

                // Add friend
                item {
                    Eyebrow("Arkadaş Ekle")
                    Spacer(Modifier.height(8.dp))
                    LookupField(
                        query = query,
                        onChange = { query = it },
                        loading = state.lookupLoading,
                        onSubmit = { viewModel.lookup(query) },
                    )
                    state.lookupResult?.let { result ->
                        Spacer(Modifier.height(8.dp))
                        LookupResultRow(result = result, onSend = { viewModel.sendRequest(it) })
                    }
                }

                // Incoming requests
                if (state.incoming.isNotEmpty()) {
                    item { Spacer(Modifier.height(14.dp)); Eyebrow("Gelen İstekler") }
                    items(state.incoming, key = { it.id }) { req ->
                        RequestRow(
                            request = req,
                            primaryLabel = "Kabul Et",
                            onPrimary = { viewModel.accept(req) },
                            onSecondary = { viewModel.decline(req) },
                        )
                    }
                }

                // Outgoing requests
                if (state.outgoing.isNotEmpty()) {
                    item { Spacer(Modifier.height(14.dp)); Eyebrow("Gönderilen İstekler") }
                    items(state.outgoing, key = { it.id }) { req ->
                        RequestRow(
                            request = req,
                            primaryLabel = null,
                            onPrimary = {},
                            onSecondary = { viewModel.cancelOutgoing(req) },
                            secondaryLabel = "İptal",
                        )
                    }
                }

                // Friends
                item { Spacer(Modifier.height(14.dp)); Eyebrow("Arkadaşlarım") }
                if (state.friends.isEmpty()) {
                    item {
                        Text(
                            "Henüz arkadaşın yok. Kodunu paylaş ya da arkadaşının kodunu gir.",
                            style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke,
                            modifier = Modifier.padding(vertical = 8.dp),
                        )
                    }
                } else {
                    items(state.friends, key = { it.user.clerkId }) { friend ->
                        FriendRow(
                            friend = friend,
                            onOpen = { onOpenFriend(friend.user.clerkId, friend.user.name ?: "Arkadaş") },
                            onRemove = { viewModel.unfriend(friend) },
                        )
                    }
                }
                item { Spacer(Modifier.height(30.dp)) }
            }
        }
    }
}

@Composable
private fun InboxAction(badge: Int, onClick: () -> Unit) {
    Box {
        androidx.compose.material3.IconButton(onClick = onClick) {
            Icon(Icons.Default.MoveToInbox, contentDescription = "Gelen tarifler", tint = MaterialTheme.ds.ink)
        }
        if (badge > 0) {
            Box(
                modifier = Modifier.align(Alignment.TopEnd).padding(6.dp).size(16.dp)
                    .background(MaterialTheme.ds.tomato, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text("$badge", color = Color.White, style = MaterialTheme.typography.bodySmall.copy(fontSize = 9.sp))
            }
        }
    }
}

@Composable
private fun FriendCodeCard(code: String?) {
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    Row(
        modifier = Modifier.fillMaxWidth()
            .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
            .background(MaterialTheme.ds.sand, RoundedCornerShape(8.dp))
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            code ?: "—",
            style = DisplayXLTextStyle.copy(fontSize = 24.sp, letterSpacing = 2.sp),
            color = MaterialTheme.ds.ink,
            modifier = Modifier.weight(1f),
        )
        if (code != null) {
            Box(
                modifier = Modifier.size(40.dp).background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
                    .clickable {
                        clipboard.setText(AnnotatedString(code))
                        Toast.makeText(context, "Kod kopyalandı", Toast.LENGTH_SHORT).show()
                    },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Default.ContentCopy, contentDescription = "Kopyala", tint = Color.White, modifier = Modifier.size(18.dp)) }
        }
    }
}

@Composable
private fun LookupField(query: String, onChange: (String) -> Unit, loading: Boolean, onSubmit: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Row(
            modifier = Modifier.weight(1f).height(48.dp)
                .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.fillMaxWidth()) {
                if (query.isEmpty()) Text("Kod veya e-posta", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
                BasicTextField(
                    value = query, onValueChange = onChange, singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
                    cursorBrush = SolidColor(MaterialTheme.ds.ember),
                )
            }
        }
        Spacer(Modifier.size(10.dp))
        Box(
            modifier = Modifier.height(48.dp).background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
                .clickable(enabled = !loading, onClick = onSubmit).padding(horizontal = 20.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (loading) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
            else Text("Bul", color = Color.White, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun LookupResultRow(result: LookupResult, onSend: (userId: String) -> Unit) {
    when (result) {
        is LookupResult.NotFound -> InfoRow("Kullanıcı bulunamadı")
        is LookupResult.BadQuery -> InfoRow("Geçerli bir kod veya e-posta gir")
        is LookupResult.Found -> {
            val user = result.lookup.user
            Row(
                modifier = Modifier.fillMaxWidth().border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                UserAvatar(name = user.name, size = 38)
                Spacer(Modifier.size(12.dp))
                Text(user.name ?: "Feslihan kullanıcısı", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink, modifier = Modifier.weight(1f))
                when (result.lookup.relationship) {
                    "none" -> SmallActionButton("İstek Gönder") { onSend(user.clerkId) }
                    "self" -> TagLabel("Bu sensin")
                    "friends" -> TagLabel("Arkadaşsınız")
                    "pending_outgoing" -> TagLabel("İstek gönderildi")
                    "pending_incoming" -> TagLabel("Seni ekledi")
                    else -> {}
                }
            }
        }
    }
}

@Composable
private fun RequestRow(
    request: FriendRequest,
    primaryLabel: String?,
    onPrimary: () -> Unit,
    onSecondary: () -> Unit,
    secondaryLabel: String = "Reddet",
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        UserAvatar(name = request.user.name, size = 40)
        Spacer(Modifier.size(12.dp))
        Text(request.user.name ?: "Feslihan kullanıcısı", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        if (primaryLabel != null) {
            SmallActionButton(primaryLabel, onClick = onPrimary)
            Spacer(Modifier.size(8.dp))
        }
        Text(secondaryLabel, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.ds.smoke,
            modifier = Modifier.clickable(onClick = onSecondary).padding(8.dp))
    }
}

@Composable
private fun FriendRow(friend: Friend, onOpen: () -> Unit, onRemove: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        UserAvatar(name = friend.user.name, size = 44)
        Spacer(Modifier.size(12.dp))
        Text(friend.user.name ?: "Feslihan kullanıcısı", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.ds.ink,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Text("Tarifleri", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.ds.ember)
        Spacer(Modifier.size(12.dp))
        Text("Çıkar", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.ds.smoke,
            modifier = Modifier.clickable(onClick = onRemove).padding(6.dp))
    }
}

@Composable
private fun SmallActionButton(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier.background(MaterialTheme.ds.ember, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    ) { Text(text, color = Color.White, style = MaterialTheme.typography.labelMedium) }
}

@Composable
private fun TagLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.ds.smoke)
}

@Composable
private fun InfoRow(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke, modifier = Modifier.padding(vertical = 6.dp))
}
