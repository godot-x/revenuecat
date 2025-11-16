package com.godotx.revenuecat

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import com.revenuecat.purchases.Offerings
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesError
import com.revenuecat.purchases.interfaces.ReceiveOfferingsCallback
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallActivityLauncher
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallResult
import com.revenuecat.purchases.ui.revenuecatui.activity.PaywallResultHandler

class RCProxyActivity : ComponentActivity(), PaywallResultHandler {

    private lateinit var launcher: PaywallActivityLauncher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        launcher = PaywallActivityLauncher(
            resultCaller = this,
            resultHandler = this
        )

        val offeringId = intent.getStringExtra("offering_id") ?: ""

        Purchases.sharedInstance.getOfferings(
            object : ReceiveOfferingsCallback {
                override fun onError(error: PurchasesError) {
                    emitBroadcast("error", error.message)
                    finish()
                }

                override fun onReceived(offerings: Offerings) {
                    val offering =
                        if (offeringId.isNotEmpty()) offerings.all[offeringId]
                        else offerings.current

                    if (offering == null) {
                        emitBroadcast("error", "offering_not_found")
                        finish()
                        return
                    }

                    runOnUiThread {
                        launcher.launch(
                            offering,
                            null,
                            true,
                            true
                        )
                    }
                }
            }
        )
    }

    override fun onActivityResult(result: PaywallResult) {
        when (result) {
            is PaywallResult.Purchased -> emitBroadcast("purchased")
            is PaywallResult.Restored -> emitBroadcast("restored")
            is PaywallResult.Cancelled -> emitBroadcast("cancelled")
            is PaywallResult.Error -> emitBroadcast("error", result.error.message ?: "")
        }
        finish()
    }

    private fun emitBroadcast(status: String, reason: String = "") {
        val i = Intent("RC_PAYWALL_RESULT")
        i.putExtra("status", status)
        if (reason.isNotEmpty()) i.putExtra("reason", reason)
        sendBroadcast(i)
    }

}
