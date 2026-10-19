package com.feslihan.app.data.local

import androidx.room.TypeConverter
import com.feslihan.app.data.model.IngredientMeasure
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Room type converters — store list/object fields as JSON strings. */
class Converters {
    private val json = Json { ignoreUnknownKeys = true }

    @TypeConverter
    fun fromStringList(value: List<String>?): String = json.encodeToString(value ?: emptyList())

    @TypeConverter
    fun toStringList(value: String?): List<String> =
        if (value.isNullOrBlank()) emptyList() else json.decodeFromString(value)

    @TypeConverter
    fun fromMeasures(value: List<IngredientMeasure>?): String = json.encodeToString(value ?: emptyList())

    @TypeConverter
    fun toMeasures(value: String?): List<IngredientMeasure> =
        if (value.isNullOrBlank()) emptyList() else json.decodeFromString(value)
}
