package com.feslihan.app

import android.app.Application
import com.clerk.api.Clerk
import dagger.hilt.android.HiltAndroidApp

/**
 * Application entry point. Hilt generates the DI container here, and Clerk is
 * initialized with the (client-safe) publishable key.
 */
@HiltAndroidApp
class FeslihanApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Clerk.initialize(this, publishableKey = BuildConfig.CLERK_PUBLISHABLE_KEY)
        // TODO(subscriptions): Purchases.configure(this, REVENUECAT_PUBLIC_KEY)
    }
}
