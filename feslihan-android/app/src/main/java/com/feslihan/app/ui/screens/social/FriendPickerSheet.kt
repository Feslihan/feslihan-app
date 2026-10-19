package com.feslihan.app.ui.screens.social

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.feslihan.app.ui.components.UserAvatar
import com.feslihan.app.ui.theme.ds

/**
 * "Tarif Gönder" bottom sheet (iOS FriendPickerSheet). Lists the user's friends;
 * pick one, add an optional note, and send the given recipe. Reports the result
 * via [onResult] so the caller can toast it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendPickerSheet(
    recipeId: String,
    onDismiss: () -> Unit,
    onResult: (String) -> Unit,
    viewModel: SharePickerViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selected by remember { mutableStateOf<String?>(null) }
    var message by remember { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState, containerColor = MaterialTheme.ds.cream) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 22.dp).padding(bottom = 28.dp)) {
            Text("Tarif Gönder", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.ds.ink)
            Spacer(Modifier.height(14.dp))

            when {
                state.isLoading -> Box(Modifier.fillMaxWidth().height(120.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = MaterialTheme.ds.ember)
                }
                state.friends.isEmpty() -> Text(
                    "Önce arkadaş ekle. Arkadaşların burada görünür.",
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.smoke,
                    modifier = Modifier.padding(vertical = 18.dp),
                )
                else -> {
                    LazyColumn(Modifier.heightIn(max = 280.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        items(state.friends, key = { it.user.clerkId }) { friend ->
                            val isSel = selected == friend.user.clerkId
                            Row(
                                modifier = Modifier.fillMaxWidth()
                                    .background(if (isSel) MaterialTheme.ds.sand else Color.Transparent, RoundedCornerShape(8.dp))
                                    .clickable { selected = friend.user.clerkId }
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                UserAvatar(name = friend.user.name, size = 38)
                                Spacer(Modifier.size(12.dp))
                                Text(friend.user.name ?: "Feslihan kullanıcısı", style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.ds.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                                if (isSel) {
                                    Box(Modifier.size(24.dp).background(MaterialTheme.ds.ember, CircleShape), contentAlignment = Alignment.Center) {
                                        Icon(Icons.Default.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(15.dp))
                                    }
                                }
                            }
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    Box(
                        Modifier.fillMaxWidth().heightIn(min = 46.dp)
                            .border(1.dp, MaterialTheme.ds.stone, RoundedCornerShape(8.dp)).padding(horizontal = 14.dp, vertical = 12.dp),
                    ) {
                        if (message.isEmpty()) Text("Mesaj (isteğe bağlı)", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.ds.dust)
                        BasicTextField(
                            value = message, onValueChange = { if (it.length <= 500) message = it },
                            textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.ds.ink),
                            cursorBrush = SolidColor(MaterialTheme.ds.ember), modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    Spacer(Modifier.height(16.dp))
                    val enabled = selected != null && !state.sending
                    Box(
                        modifier = Modifier.fillMaxWidth().height(52.dp)
                            .background(if (enabled) MaterialTheme.ds.ember else MaterialTheme.ds.stone, RoundedCornerShape(8.dp))
                            .clickable(enabled = enabled) {
                                selected?.let { to -> viewModel.send(to, recipeId, message.trim().ifBlank { null }, onResult) }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (state.sending) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                        else Text("Gönder", color = Color.White, style = MaterialTheme.typography.labelMedium.copy(fontSize = 15.sp))
                    }
                }
            }
        }
    }
}
