package com.godotx.revenuecat

import android.app.Activity
import android.util.Log
import androidx.activity.result.ActivityResultCaller
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.ProductType
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
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallActivityLauncher
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallResult
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallResultHandler
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot


class RevenueCatPlugin(godot: Godot) : GodotPlugin(godot), PaywallResultHandler {

    companion object {
        private val TAG = RevenueCatPlugin::class.java.simpleName
    }

    private var paywallActivityLauncher: PaywallActivityLauncher? = null

    override fun getPluginName(): String = "GodotxRevenueCat"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("customer_info_changed", Dictionary::class.java),
        SignalInfo("customer_info", Dictionary::class.java),
        SignalInfo("purchase_result", Dictionary::class.java),
        SignalInfo("offerings", Dictionary::class.java),
        SignalInfo("products", Array<Dictionary>::class.java),
        SignalInfo("login_finished", Dictionary::class.java),
        SignalInfo("logout_finished", Dictionary::class.java),
        SignalInfo("subscriber", Boolean::class.java),
        SignalInfo("entitlement", String::class.java, Boolean::class.java),
        SignalInfo("paywall_result", String::class.java, String::class.java)
    )

    private fun act(): Activity? {
        val a = activity
        if (a == null) Log.e(TAG, "Activity is null")
        return a
    }

    private fun initPaywallLauncher(activity: Activity) {
        val caller = activity as? ActivityResultCaller
        if (caller == null) {
            Log.e(TAG, "Paywall not available: host does not implement ActivityResultCaller")
            return
        }
        paywallActivityLauncher = PaywallActivityLauncher(
            resultCaller = caller,
            resultHandler = this
        )
    }

    // safe dictionary creation for Godot
    private fun dictOf(vararg pairs: Pair<String, Any?>): Dictionary {
        val d = Dictionary()
        for ((k, v) in pairs) {
            d[k] = v ?: ""   // never return Any()
        }
        return d
    }

    @UsedByGodot
    fun initialize(api_key: String, user_id: String, debug: Boolean) {
        val a = act() ?: return

        Purchases.logLevel = if (debug) LogLevel.DEBUG else LogLevel.ERROR

        val builder = PurchasesConfiguration.Builder(a, api_key)
        if (user_id.isNotEmpty()) builder.appUserID(user_id)
        Purchases.configure(builder.build())

        get_customer_info()
        initPaywallLauncher(a)
    }

    @UsedByGodot
    fun get_customer_info() {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitSignal("customer_info", dictOf("error" to error.message))
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    emitSignal(
                        "customer_info",
                        dictOf("active_entitlements" to customerInfo.entitlements.active.size)
                    )
                }
            }
        )
    }

    private fun purchaseEmit(
        info: CustomerInfo?,
        tx: StoreTransaction?,
        error: PurchasesError?,
        userCancelled: Boolean?
    ) {
        val d = Dictionary()

        if (error != null) d["error"] = error.message
        if (userCancelled != null) d["cancelled"] = userCancelled
        if (info != null) d["active_entitlements"] = info.entitlements.active.size

        if (tx != null) {
            d["productId"] = tx.productIds.firstOrNull() ?: ""
            d["storeTransactionId"] = tx.orderId ?: ""
        }

        emitSignal("purchase_result", d)
    }

    @UsedByGodot
    fun purchase(product_id: String) {
        val a = act()
        if (a == null) {
            emitSignal("purchase_result", dictOf("error" to "activity_null"))
            return
        }

        fun doPurchase(product: StoreProduct) {
            val params = PurchaseParams.Builder(a, product).build()
            Purchases.sharedInstance.purchase(
                params,
                object : PurchaseCallback {
                    override fun onError(error: PurchasesError, userCancelled: Boolean) {
                        purchaseEmit(null, null, error, userCancelled)
                    }

                    override fun onCompleted(
                        storeTransaction: StoreTransaction,
                        customerInfo: CustomerInfo
                    ) {
                        purchaseEmit(customerInfo, storeTransaction, null, false)
                    }
                }
            )
        }

        fun fetchAndBuy(type: ProductType, onEmpty: () -> Unit) {
            Purchases.sharedInstance.getProducts(
                listOf(product_id),
                type,
                object : GetStoreProductsCallback {
                    override fun onError(error: PurchasesError) {
                        emitSignal("purchase_result", dictOf("error" to error.message))
                    }

                    override fun onReceived(storeProducts: List<StoreProduct>) {
                        if (storeProducts.isEmpty()) onEmpty()
                        else doPurchase(storeProducts.first())
                    }
                }
            )
        }

        fetchAndBuy(ProductType.SUBS) {
            fetchAndBuy(ProductType.INAPP) {
                emitSignal("purchase_result", dictOf("error" to "not_found"))
            }
        }
    }

    @UsedByGodot
    fun fetch_offerings() {
        Purchases.sharedInstance.getOfferings(object : ReceiveOfferingsCallback {
            override fun onError(error: PurchasesError) {
                emitSignal("offerings", dictOf("error" to error.message))
            }

            override fun onReceived(offerings: Offerings) {
                val current = offerings.current

                emitSignal(
                    "offerings",
                    dictOf(
                        "identifier" to (current?.identifier ?: ""),
                        "available_packages" to (current?.availablePackages?.size ?: 0)
                    )
                )
            }
        })
    }

    @UsedByGodot
    fun fetch_products(ids: Array<String>) {
        Purchases.sharedInstance.getProductsWith(
            productIds = ids.toList(),
            onError = { error ->
                val d = Dictionary()
                d["error"] = error.message
                emitSignal("products", d)
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

                emitSignal("products", arr)
            }
        )
    }

    @UsedByGodot
    fun login(user_id: String) {
        Purchases.sharedInstance.logIn(user_id, object : LogInCallback {
            override fun onError(error: PurchasesError) {
                emitSignal(
                    "login_finished",
                    dictOf("success" to false, "error" to error.message)
                )
            }

            override fun onReceived(customerInfo: CustomerInfo, created: Boolean) {
                emitSignal(
                    "login_finished",
                    dictOf(
                        "success" to true,
                        "created" to created,
                        "active_entitlements" to customerInfo.entitlements.active.size
                    )
                )
            }
        })
    }

    @UsedByGodot
    fun logout() {
        Purchases.sharedInstance.logOut(object : ReceiveCustomerInfoCallback {
            override fun onError(error: PurchasesError) {
                emitSignal(
                    "logout_finished",
                    dictOf("success" to false, "error" to error.message)
                )
            }

            override fun onReceived(customerInfo: CustomerInfo) {
                emitSignal(
                    "logout_finished",
                    dictOf(
                        "success" to true,
                        "active_entitlements" to customerInfo.entitlements.active.size
                    )
                )
            }
        })
    }

    @UsedByGodot
    fun is_subscriber() {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitSignal("subscriber", false)
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    emitSignal("subscriber", customerInfo.entitlements.active.isNotEmpty())
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
                    emitSignal("entitlement", entitlement_id, false)
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    val ent = try {
                        customerInfo.entitlements[entitlement_id]
                    } catch (_: Throwable) {
                        null
                    }
                    emitSignal("entitlement", entitlement_id, ent?.isActive == true)
                }
            }
        )
    }

    @UsedByGodot
    fun present_paywall(offering_id: String) {
        val a = act()
        if (a == null) {
            emitSignal("paywall_result", "error", "activity_null")
            return
        }

        val launcher = paywallActivityLauncher
        if (launcher == null) {
            emitSignal("paywall_result", "error", "not_available")
            return
        }

        Purchases.sharedInstance.getOfferings(object : ReceiveOfferingsCallback {
            override fun onError(error: PurchasesError) {
                emitSignal("paywall_result", "error", error.message)
            }

            override fun onReceived(offerings: Offerings) {
                val offering =
                    if (offering_id.isNotEmpty()) offerings.all[offering_id]
                    else offerings.current

                if (offering == null) {
                    emitSignal("paywall_result", "error", "offering_not_found")
                    return
                }

                a.runOnUiThread {
                    launcher.launch(
                        offering = offering,
                        shouldDisplayDismissButton = true
                    )
                }
            }
        })
    }

    override fun onActivityResult(result: PaywallResult) {
        when (result) {
            is PaywallResult.Purchased ->
                emitSignal("paywall_result", "purchased", "")

            is PaywallResult.Restored ->
                emitSignal("paywall_result", "restored", "")

            is PaywallResult.Cancelled ->
                emitSignal("paywall_result", "cancelled", "")

            is PaywallResult.Error ->
                emitSignal("paywall_result", "error", result.error.message ?: "")
        }
    }
}
