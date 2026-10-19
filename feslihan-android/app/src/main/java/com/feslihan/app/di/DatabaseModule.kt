package com.feslihan.app.di

import android.content.Context
import androidx.room.Room
import com.feslihan.app.data.local.FeslihanDatabase
import com.feslihan.app.data.local.RecipeDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): FeslihanDatabase =
        Room.databaseBuilder(context, FeslihanDatabase::class.java, FeslihanDatabase.NAME)
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideRecipeDao(db: FeslihanDatabase): RecipeDao = db.recipeDao()
}
