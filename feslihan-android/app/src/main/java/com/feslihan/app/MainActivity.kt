package com.feslihan.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.clerk.ui.auth.AuthView
import com.feslihan.app.auth.AuthState
import com.feslihan.app.auth.AuthViewModel
import com.feslihan.app.ui.navigation.FeslihanNavGraph
import com.feslihan.app.ui.theme.DisplayXLTextStyle
import com.feslihan.app.ui.theme.FeslihanTheme
import com.feslihan.app.ui.theme.ds
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { FeslihanRoot() }
    }
}

@Composable
private fun FeslihanRoot(authViewModel: AuthViewModel = hiltViewModel()) {
    val authState by authViewModel.state.collectAsStateWithLifecycle()
    FeslihanTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.ds.cream) {
            when (authState) {
                AuthState.Loading -> SplashGate()
                AuthState.SignedOut -> AuthView() // Clerk's prebuilt sign-in / sign-up UI
                AuthState.SignedIn -> FeslihanNavGraph()
            }
        }
    }
}

/** Minimal splash shown while Clerk initializes. */
@Composable
private fun SplashGate() {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("🌿", style = MaterialTheme.typography.headlineLarge)
        Text("Feslihan", style = DisplayXLTextStyle, color = MaterialTheme.ds.ink, modifier = Modifier.padding(top = 10.dp))
        CircularProgressIndicator(color = MaterialTheme.ds.ember, modifier = Modifier.padding(top = 24.dp))
    }
}
