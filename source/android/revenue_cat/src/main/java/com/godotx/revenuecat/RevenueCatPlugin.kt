package com.godotx.revenuecat

import android.app.Activity
import android.util.Log
import androidx.core.content.ContextCompat
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.getProductsWith
import com.revenuecat.purchases.interfaces.GetStoreProductsCallback
import com.revenuecat.purchases.interfaces.LogInCallback
import com.revenuecat.purchases.interfaces.PurchaseCallback
import com.revenuecat.purchases.interfaces.ReceiveCustomerInfoCallback
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback
import com.revenuecat.purchases.models.StoreProduct
import com.revenuecat.purchases.models.StoreTransaction
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class RevenueCatPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private val TAG = RevenueCatPlugin::class.java.simpleName
    }

    private var paywallReceiver: android.content.BroadcastReceiver? = null

    override fun getPluginName(): String {
        return "GodotxRevenueCat"
    }

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("customer_info_changed", Dictionary::class.java),
            SignalInfo("customer_info", Dictionary::class.java),
            SignalInfo("purchase_result", Dictionary::class.java),
            SignalInfo("offerings", Dictionary::class.java),
            SignalInfo("products", Array<Dictionary>::class.java),
            SignalInfo("login_finished", Dictionary::class.java),
            SignalInfo("logout_finished", Dictionary::class.java),
            SignalInfo("subscriber", Boolean::class.javaObjectType),
            SignalInfo("entitlement", String::class.java, Boolean::class.javaObjectType),
            SignalInfo("paywall_result", Dictionary::class.java)
        )
    }

    private fun act(): Activity? {
        val a = activity
        if (a == null) {
            Log.e(TAG, "Activity is null")
        }
        return a
    }

    private fun dictOf(vararg pairs: Pair<String, Any?>): Dictionary {
        val d = Dictionary()
        for ((k, v) in pairs) {
            d[k] = v ?: ""
        }
        return d
    }

    private fun emitOnMain(name: String, vararg args: Any?) {
        val a = act()
        if (a == null) {
            return
        }

        a.runOnUiThread {
            emitSignal(name, *args)
        }
    }

    @UsedByGodot
    fun initialize(api_key: String, user_id: String, debug: Boolean) {
        val a = act() ?: return

        if (paywallReceiver == null) {
            // create the receiver
            paywallReceiver = object : android.content.BroadcastReceiver() {
                override fun onReceive(
                    context: android.content.Context?,
                    intent: android.content.Intent?
                ) {
                    val status = intent?.getStringExtra("status") ?: "unknown"
                    val reason = intent?.getStringExtra("reason") ?: ""

                    val d = Dictionary()
                    d["status"] = status
                    if (reason.isNotEmpty()) {
                        d["reason"] = reason
                    }

                    emitOnMain("paywall_result", d)
                }
            }

            // register the receiver
            val filter = android.content.IntentFilter("RC_PAYWALL_RESULT")
            ContextCompat.registerReceiver(
                a,
                paywallReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
        }

        // initialize the sdk
        Purchases.logLevel = if (debug) LogLevel.DEBUG else LogLevel.ERROR

        val builder = PurchasesConfiguration.Builder(a, api_key)
        if (user_id.isNotEmpty()) {
            builder.appUserID(user_id)
        }

        Purchases.configure(builder.build())

        get_customer_info()
    }

    @UsedByGodot
    fun get_customer_info() {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitOnMain("customer_info", dictOf("error" to error.message))
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    emitOnMain(
                        "customer_info",
                        dictOf("active_entitlements" to customerInfo.entitlements.active.size)
                    )
                }
            }
        )
    }

    @UsedByGodot
    fun purchase(pid: String) {
        val a = act()
        if (a == null) {
            val d = Dictionary()
            d["cancelled"] = false
            d["active_entitlements"] = 0
            d["error"] = "activity_null"
            d["product_id"] = pid
            d["transaction_id"] = ""
            emitOnMain("purchase_result", d)
            return
        }

        Purchases.sharedInstance.getProducts(listOf(pid), object : GetStoreProductsCallback {
            override fun onError(error: PurchasesError) {
                val d = Dictionary()
                d["cancelled"] = false
                d["active_entitlements"] = 0
                d["error"] = error.message
                d["product_id"] = pid
                d["transaction_id"] = ""
                emitOnMain("purchase_result", d)
            }

            override fun onReceived(storeProducts: List<StoreProduct>) {
                if (storeProducts.isEmpty()) {
                    val d = Dictionary()
                    d["cancelled"] = false
                    d["active_entitlements"] = 0
                    d["error"] = "not_found"
                    d["product_id"] = pid
                    d["transaction_id"] = ""
                    emitOnMain("purchase_result", d)
                    return
                }

                val product = storeProducts.first()
                val params = PurchaseParams.Builder(a, product).build()

                Purchases.sharedInstance.purchase(params, object : PurchaseCallback {
                    override fun onError(error: PurchasesError, userCancelled: Boolean) {
                        val d = Dictionary()
                        d["cancelled"] = userCancelled
                        d["active_entitlements"] = 0
                        d["error"] = error.message
                        d["product_id"] = pid
                        d["transaction_id"] = ""
                        emitOnMain("purchase_result", d)
                    }

                    override fun onCompleted(
                        storeTransaction: StoreTransaction,
                        customerInfo: CustomerInfo
                    ) {
                        val d = Dictionary()

                        val transactionId = storeTransaction.orderId ?: ""
                        val entitlementsCount = customerInfo.entitlements.active.size

                        d["cancelled"] = false
                        d["active_entitlements"] = entitlementsCount
                        d["error"] = ""
                        d["product_id"] = pid
                        d["transaction_id"] = transactionId

                        emitOnMain("purchase_result", d)
                    }
                })
            }
        })
    }

    @UsedByGodot
    fun fetch_offerings() {
        Purchases.sharedInstance.getOfferings(
            object : ReceiveOfferingsCallback {

                override fun onError(error: PurchasesError) {
                    emitOnMain("offerings", dictOf("error" to error.message))
                }

                override fun onReceived(offerings: Offerings) {
                    val current = offerings.current
                    emitOnMain(
                        "offerings",
                        dictOf(
                            "identifier" to (current?.identifier ?: ""),
                            "available_packages" to (current?.availablePackages?.size ?: 0)
                        )
                    )
                }
            }
        )
    }

    @UsedByGodot
    fun fetch_products(ids: Array<String>) {
        Purchases.sharedInstance.getProductsWith(
            productIds = ids.toList(),
            onError = { error ->
                emitOnMain("products", dictOf("error" to error.message))
            },
            onGetStoreProducts = { products ->
                val arr = mutableListOf<Dictionary>()

                for (p in products) {
                    val d = Dictionary()
                    d["id"] = p.id
                    d["title"] = p.title
                    d["description"] = p.description
                    d["price"] = p.price.formatted
                    d["amount"] = p.price.amountMicros / 1_000_000.0
                    arr.add(d)
                }

                emitOnMain("products", arr.toTypedArray())
            }
        )
    }

    @UsedByGodot
    fun login(user_id: String) {
        Purchases.sharedInstance.logIn(
            user_id,
            object : LogInCallback {

                override fun onError(error: PurchasesError) {
                    emitOnMain(
                        "login_finished",
                        dictOf("success" to false, "error" to error.message)
                    )
                }

                override fun onReceived(customerInfo: CustomerInfo, created: Boolean) {
                    emitOnMain(
                        "login_finished",
                        dictOf(
                            "success" to true,
                            "created" to created,
                            "active_entitlements" to customerInfo.entitlements.active.size
                        )
                    )
                }
            }
        )
    }

    @UsedByGodot
    fun logout() {
        Purchases.sharedInstance.logOut(
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitOnMain(
                        "logout_finished",
                        dictOf("success" to false, "error" to error.message)
                    )
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    emitOnMain(
                        "logout_finished",
                        dictOf(
                            "success" to true,
                            "active_entitlements" to customerInfo.entitlements.active.size
                        )
                    )
                }
            }
        )
    }

    @UsedByGodot
    fun is_subscriber() {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitOnMain("subscriber", false)
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    val isSubscriber: Boolean = customerInfo.entitlements.active.isNotEmpty()
                    emitOnMain("subscriber", isSubscriber)
                }
            }
        )
    }

    @UsedByGodot
    fun has_entitlement(entitlement_id: String) {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitOnMain("entitlement", entitlement_id, false)
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    val ent = try {
                        customerInfo.entitlements[entitlement_id]
                    } catch (e: Throwable) {
                        null
                    }

                    emitOnMain("entitlement", entitlement_id, ent?.isActive == true)
                }
            }
        )
    }

    @UsedByGodot
    fun present_paywall(offering_id: String) {
        val a = act()

        if (a == null) {
            emitOnMain("paywall_result", dictOf("status" to "error", "reason" to "activity_null"))
            return
        }

        val intent = android.content.Intent(a, RCProxyActivity::class.java)
        intent.putExtra("offering_id", offering_id)

        a.startActivity(intent)
    }

    override fun onMainDestroy() {
        super.onMainDestroy()

        val a = act()
        if (a != null && paywallReceiver != null) {
            a.unregisterReceiver(paywallReceiver)
            paywallReceiver = null
        }
    }
}
