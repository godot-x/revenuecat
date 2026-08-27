package com.godotx.revenuecat

import android.app.Activity
import android.util.Log
import androidx.core.content.ContextCompat
import com.revenuecat.purchases.CacheFetchPolicy
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Package
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
import com.revenuecat.purchases.restorePurchasesWith
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
    private var currentCustomerInfo: CustomerInfo? = null

    override fun getPluginName(): String {
        return "GodotxRevenueCat"
    }

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("customer_info_changed", Dictionary::class.java),
            SignalInfo("customer_info", Dictionary::class.java),
            SignalInfo("purchase_result", Dictionary::class.java),
            SignalInfo("offerings", Dictionary::class.java),
            SignalInfo("products", Dictionary::class.java),
            SignalInfo("login_finished", Dictionary::class.java),
            SignalInfo("logout_finished", Dictionary::class.java),
            SignalInfo("subscriber", Boolean::class.javaObjectType),
            SignalInfo("entitlement", String::class.java, Boolean::class.javaObjectType),
            SignalInfo("paywall_result", Dictionary::class.java),
            SignalInfo("restore_finished", Dictionary::class.java)
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
                    currentCustomerInfo = customerInfo
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
                        currentCustomerInfo = customerInfo
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

    private fun emitPurchaseResult(
        cancelled: Boolean,
        entitlements: Int,
        error: String,
        productId: String,
        transactionId: String
    ) {
        val d = Dictionary()
        d["cancelled"] = cancelled
        d["active_entitlements"] = entitlements
        d["error"] = error
        d["product_id"] = productId
        d["transaction_id"] = transactionId
        emitOnMain("purchase_result", d)
    }

    @UsedByGodot
    fun purchase_package(offering_id: String, package_id: String) {
        val a = act()
        if (a == null) {
            emitPurchaseResult(false, 0, "activity_null", "", "")
            return
        }

        Purchases.sharedInstance.getOfferings(object : ReceiveOfferingsCallback {
            override fun onError(error: PurchasesError) {
                emitPurchaseResult(false, 0, error.message, "", "")
            }

            override fun onReceived(offerings: Offerings) {
                val offering =
                    if (offering_id.isNotEmpty()) offerings.all[offering_id] else offerings.current

                if (offering == null) {
                    emitPurchaseResult(false, 0, "offering_not_found", "", "")
                    return
                }

                val pkg = offering.availablePackages.firstOrNull { it.identifier == package_id }

                if (pkg == null) {
                    emitPurchaseResult(false, 0, "package_not_found", "", "")
                    return
                }

                // Purchasing the Package (not a re-resolved product id) is what carries the
                // Google Play base plan / subscriptionOption that purchase(String) cannot express.
                val params = PurchaseParams.Builder(a, pkg).build()

                Purchases.sharedInstance.purchase(params, object : PurchaseCallback {
                    override fun onError(error: PurchasesError, userCancelled: Boolean) {
                        emitPurchaseResult(userCancelled, 0, error.message, pkg.product.id, "")
                    }

                    override fun onCompleted(
                        storeTransaction: StoreTransaction,
                        customerInfo: CustomerInfo
                    ) {
                        currentCustomerInfo = customerInfo
                        emitPurchaseResult(
                            false,
                            customerInfo.entitlements.active.size,
                            "",
                            pkg.product.id,
                            storeTransaction.orderId ?: ""
                        )
                    }
                })
            }
        })
    }

    private fun emitRestoreFinished(success: Boolean, entitlements: Int, error: String) {
        emitOnMain(
            "restore_finished",
            dictOf(
                "success" to success,
                "restored" to (entitlements > 0),
                "active_entitlements" to entitlements,
                "error" to error
            )
        )
    }

    @UsedByGodot
    fun restore_purchases() {
        Purchases.sharedInstance.restorePurchasesWith(
            onError = { error ->
                emitRestoreFinished(false, 0, error.message)
            },
            onSuccess = { customerInfo ->
                currentCustomerInfo = customerInfo
                emitRestoreFinished(true, customerInfo.entitlements.active.size, "")
            }
        )
    }

    private fun productDict(product: StoreProduct): Dictionary {
        return Dictionary().apply {
            this["id"] = product.id
            this["title"] = product.title
            this["description"] = product.description
            this["price"] = product.price.formatted
            this["amount"] = product.price.amountMicros / 1_000_000.0
            this["currency"] = product.price.currencyCode
        }
    }

    private fun packageDict(pkg: Package): Dictionary {
        return Dictionary().apply {
            this["identifier"] = pkg.identifier
            this["package_type"] = pkg.packageType.name
            this["product"] = productDict(pkg.product)
        }
    }

    // Object[], never ArrayList and never Array<Dictionary>: Godot's JNI
    // (jni_utils.cpp _jobject_to_variant) matches exactly "[Ljava.lang.Object;" to build a
    // Godot Array, recursing into each element. Anything else reaches GDScript as an opaque
    // JavaObject. Same constraint fetch_products is written against.
    private fun packagesArray(packages: List<Package>): Array<Any> {
        return Array<Any>(packages.size) { index -> packageDict(packages[index]) }
    }

    private fun offeringsArray(offerings: List<Offering>): Array<Any> {
        return Array<Any>(offerings.size) { index ->
            Dictionary().apply {
                this["identifier"] = offerings[index].identifier
                this["packages"] = packagesArray(offerings[index].availablePackages)
            }
        }
    }

    @UsedByGodot
    fun fetch_offerings() {
        Purchases.sharedInstance.getOfferings(
            object : ReceiveOfferingsCallback {
                override fun onError(error: PurchasesError) {
                    val result = Dictionary()
                    result["error"] = error.message
                    result["identifier"] = ""
                    result["packages"] = emptyArray<Any>()
                    result["offerings"] = emptyArray<Any>()
                    emitOnMain("offerings", result)
                }

                override fun onReceived(offerings: Offerings) {
                    val current = offerings.current

                    val result = Dictionary()
                    result["error"] = ""
                    result["identifier"] = current?.identifier ?: ""
                    result["packages"] = packagesArray(current?.availablePackages ?: emptyList())
                    result["offerings"] = offeringsArray(offerings.all.values.toList())
                    emitOnMain("offerings", result)
                }
            }
        )
    }

    @UsedByGodot
    fun fetch_products(ids: Array<String>) {
        Purchases.sharedInstance.getProductsWith(
            productIds = ids.toList(),

            onError = { error ->
                val result = Dictionary()
                result["products"] = emptyArray<Any>()
                result["error"] = error.message ?: ""
                emitOnMain("products", result)
            },

            onGetStoreProducts = { products ->
                val arr = Array<Any>(products.size) { index ->
                    val p = products[index]

                    Dictionary().apply {
                        this["id"] = p.id
                        this["title"] = p.title
                        this["description"] = p.description
                        this["price"] = p.price.formatted
                        this["amount"] = p.price.amountMicros / 1_000_000.0
                    }
                }

                val result = Dictionary()
                result["products"] = arr
                result["error"] = ""
                emitOnMain("products", result)
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
                    currentCustomerInfo = customerInfo
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
                    currentCustomerInfo = customerInfo
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
                    currentCustomerInfo = customerInfo
                    val isSubscriber: Boolean = customerInfo.entitlements.active.isNotEmpty()
                    emitOnMain("subscriber", isSubscriber)
                }
            }
        )
    }

    @UsedByGodot
    fun check_entitlement(entitlement_id: String) {
        Purchases.sharedInstance.getCustomerInfo(
            CacheFetchPolicy.CACHED_OR_FETCHED,
            object : ReceiveCustomerInfoCallback {
                override fun onError(error: PurchasesError) {
                    emitOnMain("entitlement", entitlement_id, false)
                }

                override fun onReceived(customerInfo: CustomerInfo) {
                    currentCustomerInfo = customerInfo

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
    fun has_entitlement(entitlement_id: String): Boolean {
        val info = currentCustomerInfo ?: return false
        val ent = info.entitlements[entitlement_id]
        return ent?.isActive == true
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
