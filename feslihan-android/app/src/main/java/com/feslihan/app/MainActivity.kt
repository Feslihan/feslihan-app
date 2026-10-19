package com.feslihan.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.feslihan.app.ui.navigation.FeslihanNavGraph
import com.feslihan.app.ui.theme.FeslihanTheme
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
private fun FeslihanRoot() {
    FeslihanTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            FeslihanNavGraph()
        }
    }
}
