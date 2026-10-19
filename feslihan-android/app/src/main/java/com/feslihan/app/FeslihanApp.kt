package com.feslihan.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * Application entry point. Hilt generates the DI container here.
 *
 * Third-party SDKs that need app-start initialization (RevenueCat, Clerk) are
 * wired in [onCreate] as those steps land — see the android README.
 */
@HiltAndroidApp
class FeslihanApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // TODO(subscriptions): Purchases.configure(this, REVENUECAT_PUBLIC_KEY)
        // TODO(auth): Clerk.initialize(this, CLERK_PUBLISHABLE_KEY)
    }
}
