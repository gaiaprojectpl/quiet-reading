package app.quietreading.feature.plus

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.quietreading.QuietReadingApplication
import app.quietreading.data.Keys
import app.quietreading.designsystem.ThemeId
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/** Flow 5 › Live preview: a Plus theme the reader is trying on across the app. Not saved. */
object PlusPreview {
    var theme by mutableStateOf<ThemeId?>(null)
}

/**
 * Quiet Reading Plus: one payment through Google Play (product "plus", no subscription).
 * The price always comes from Play. Unlock is kept in [Keys.plusUnlocked] so widgets and themes follow.
 */
class PlusAccess private constructor(private val context: Context) {
    sealed interface StoreState {
        data object Loading : StoreState
        data class Ready(val price: String) : StoreState
        data object Unavailable : StoreState
    }
    enum class PurchaseResult { Unlocked, Cancelled, Pending, Failed }
    enum class RestoreResult { Restored, Nothing, Failed }

    var store by mutableStateOf<StoreState>(StoreState.Loading)
        private set
    var isBusy by mutableStateOf(false)
        private set

    private val prefs = (context.applicationContext as QuietReadingApplication).env.prefs
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var product: ProductDetails? = null
    private var pendingPurchase: CompletableDeferred<PurchaseResult>? = null

    private val client: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases -> onPurchasesUpdated(result, purchases) }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    private suspend fun setUnlocked(on: Boolean) = prefs.set(Keys.plusUnlocked, on)

    private suspend fun connect(): Boolean {
        if (client.isReady) return true
        return withTimeoutOrNull(8_000) {
            suspendCancellableCoroutine { c ->
                client.startConnection(object : BillingClientStateListener {
                    override fun onBillingSetupFinished(result: BillingResult) {
                        if (c.isActive) c.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                    }
                    override fun onBillingServiceDisconnected() { if (c.isActive) c.resume(false) }
                })
            }
        } ?: false
    }

    /** Loads the price. Gives Play 8 seconds, then offers a way out ("The store isn’t answering"). */
    suspend fun loadProduct() {
        if (store is StoreState.Ready && (product != null || stub != null)) return
        store = StoreState.Loading
        stub?.let {
            delay(400)
            store = if (it == "none") StoreState.Unavailable else StoreState.Ready("$4.99")
            return
        }
        val details = withTimeoutOrNull(8_000) {
            if (!connect()) return@withTimeoutOrNull null
            val params = QueryProductDetailsParams.newBuilder().setProductList(listOf(
                QueryProductDetailsParams.Product.newBuilder().setProductId(PRODUCT_ID).setProductType(BillingClient.ProductType.INAPP).build(),
            )).build()
            suspendCancellableCoroutine<ProductDetails?> { c ->
                client.queryProductDetailsAsync(params) { _, result -> if (c.isActive) c.resume(result.productDetailsList.firstOrNull()) }
            }
        }
        product = details
        val price = details?.oneTimePurchaseOfferDetails?.formattedPrice
        store = if (price != null) StoreState.Ready(price) else StoreState.Unavailable
    }

    suspend fun purchase(activity: Activity): PurchaseResult {
        isBusy = true
        try {
            stub?.let {
                delay(1_000)
                return when (it) {
                    "fail" -> PurchaseResult.Failed
                    "pending" -> PurchaseResult.Pending
                    else -> { setUnlocked(true); PurchaseResult.Unlocked }
                }
            }
            val details = product ?: return PurchaseResult.Failed
            val offer = details.oneTimePurchaseOfferDetails ?: return PurchaseResult.Failed
            val params = BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(
                BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details).apply {
                    offer.offerToken?.let { setOfferToken(it) }
                }.build(),
            )).build()
            val waiting = CompletableDeferred<PurchaseResult>().also { pendingPurchase = it }
            val launch = client.launchBillingFlow(activity, params)
            if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
                pendingPurchase = null
                return if (launch.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) PurchaseResult.Cancelled else PurchaseResult.Failed
            }
            return waiting.await()
        } finally {
            isBusy = false
        }
    }

    suspend fun restore(): RestoreResult {
        isBusy = true
        try {
            stub?.let {
                delay(1_000)
                return if (it == "restore") { setUnlocked(true); RestoreResult.Restored } else RestoreResult.Nothing
            }
            if (!connect()) return RestoreResult.Failed
            val owned = queryOwned() ?: return RestoreResult.Failed
            return if (owned) RestoreResult.Restored else RestoreResult.Nothing
        } finally {
            isBusy = false
        }
    }

    /** True/false when Play answered, null when it didn't. Also acknowledges and saves the unlock. */
    private suspend fun queryOwned(): Boolean? {
        val purchases = suspendCancellableCoroutine<List<Purchase>?> { c ->
            client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { result, list ->
                if (c.isActive) c.resume(if (result.responseCode == BillingClient.BillingResponseCode.OK) list else null)
            }
        } ?: return null
        val plus = purchases.filter { PRODUCT_ID in it.products && it.purchaseState == Purchase.PurchaseState.PURCHASED }
        plus.forEach { acknowledge(it) }
        if (plus.isNotEmpty()) setUnlocked(true)
        return plus.isNotEmpty()
    }

    /** At launch: purchases approved later, bought on another device, or refunded. Quiet when Play isn't there. */
    fun refreshEntitlement() {
        if (stub != null) return
        scope.launch { if (connect()) queryOwned() }
    }

    private fun acknowledge(p: Purchase) {
        if (p.isAcknowledged) return
        client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()) {}
    }

    private fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        val waiting = pendingPurchase
        pendingPurchase = null
        val plus = purchases.orEmpty().filter { PRODUCT_ID in it.products }
        val outcome = when {
            result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED -> PurchaseResult.Cancelled
            result.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> PurchaseResult.Unlocked
            result.responseCode != BillingClient.BillingResponseCode.OK -> PurchaseResult.Failed
            plus.any { it.purchaseState == Purchase.PurchaseState.PURCHASED } -> PurchaseResult.Unlocked
            plus.any { it.purchaseState == Purchase.PurchaseState.PENDING } -> PurchaseResult.Pending
            else -> PurchaseResult.Failed
        }
        scope.launch {
            plus.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.forEach { acknowledge(it) }
            if (outcome == PurchaseResult.Unlocked) setUnlocked(true)
            waiting?.complete(outcome)
        }
    }

    companion object {
        const val PRODUCT_ID = "plus"

        @Volatile private var instance: PlusAccess? = null
        fun get(context: Context): PlusAccess = instance ?: synchronized(this) {
            instance ?: PlusAccess(context.applicationContext).also { instance = it }
        }

        /** Test builds only: `--es qsStore ready|none|fail|pending|restore` fakes Google Play. */
        var stub: String? = null
            private set

        /**
         * Test builds only (debuggable): `--ez qsPlus true|false` sets Plus and keeps it,
         * `--es qsStore …` fakes the store. Ignored in release builds.
         */
        suspend fun applyDebugExtras(context: Context, extras: android.os.Bundle?) {
            if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0 || extras == null) return
            extras.getString("qsStore")?.let { stub = it }
            if (extras.containsKey("qsPlus")) {
                (context.applicationContext as QuietReadingApplication).env.prefs.set(Keys.plusUnlocked, extras.getBoolean("qsPlus"))
            }
        }
    }
}
