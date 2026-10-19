package com.feslihan.app.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.feslihan.app.data.repository.UserDataRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val pantryCount: Int? = null,
    val shoppingCount: Int? = null, // unchecked items still to buy
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val repository: UserDataRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(HomeUiState())
    val state: StateFlow<HomeUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            val pantry = repository.pantry().getOrNull()?.size
            val shopping = repository.shoppingList().getOrNull()?.count { !it.isChecked }
            _state.value = HomeUiState(pantryCount = pantry, shoppingCount = shopping)
        }
    }
}
