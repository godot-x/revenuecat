####################################
# RevenueCat Core SDK
####################################
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

####################################
# RevenueCat UI SDK
####################################
-keep class com.revenuecat.purchases.ui.** { *; }
-dontwarn com.revenuecat.purchases.ui.**

####################################
# RevenueCat uses reflection + serialization
####################################
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*

####################################
# Kotlin / Coroutines (required)
####################################
-keep class kotlin.Metadata { *; }
-keep class kotlin.** { *; }
-dontwarn kotlin.**

-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

####################################
# Google Billing (required by RevenueCat)
####################################
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

####################################
# AndroidX / AppCompat (UI SDK)
####################################
-keep class androidx.appcompat.** { *; }
-dontwarn androidx.appcompat.**

####################################
# Lifecycle / ViewModel (used by purchases-ui)
####################################
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

####################################
# Gson / JSON (used internally)
####################################
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
