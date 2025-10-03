package com.example.imagingedge_next

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.ConnectivityManager.NetworkCallback
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val channelName = "imagingedge/wifi"

    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    private var connectivityManager: ConnectivityManager? = null
    private var wifiManager: WifiManager? = null

    private var pendingCallback: NetworkCallback? = null
    private var pendingResult: MethodChannel.Result? = null
    private val activeSuggestions = mutableListOf<WifiNetworkSuggestion>()
    private var suggestionReceiver: BroadcastReceiver? = null
    private var suggestionTargetSsid: String? = null
    private var suggestionCompletion: AtomicBoolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        connectivityManager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connectToWifi" -> {
                val ssid = call.argument<String>("ssid")
                val password = call.argument<String>("password") ?: ""
                val hidden = call.argument<Boolean>("hidden") ?: false
                if (ssid.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "SSID is required", null)
                    return
                }
                connectToWifi(ssid, password, hidden, result)
            }
            "getCurrentSsid" -> result.success(getCurrentSsid())
            "disconnectWifi" -> {
                disconnectFromRequestedNetwork()
                clearNetworkSuggestions()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun connectToWifi(
        ssid: String,
        password: String,
        hidden: Boolean,
        result: MethodChannel.Result,
    ) {
        cancelPendingResult(false)
        pendingResult = result

        disconnectFromRequestedNetwork()
        clearNetworkSuggestions()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectUsingSpecifier(ssid, password, hidden, allowFallback = true)
        } else {
            val success = connectLegacyInternal(ssid, password, hidden)
            resolveResult(success)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectLegacyInternal(ssid: String, password: String, hidden: Boolean): Boolean {
        val manager = wifiManager ?: return false

        if (!manager.isWifiEnabled) {
            manager.isWifiEnabled = true
        }

        val quotedSsid = quoteIfNeeded(ssid)
        var configuration = manager.configuredNetworks?.firstOrNull { it.SSID == quotedSsid }

        if (configuration == null) {
            configuration = WifiConfiguration().apply {
                SSID = quotedSsid
                hiddenSSID = hidden
                status = WifiConfiguration.Status.ENABLED
                priority = 40

                if (password.isEmpty()) {
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                    allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
                } else {
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                    allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
                    preSharedKey = quoteIfNeeded(password)
                }
            }

            val networkId = manager.addNetwork(configuration)
            if (networkId == -1) {
                return false
            }
            configuration.networkId = networkId
        } else {
            configuration.hiddenSSID = hidden
        }

        val networkId = configuration.networkId
        if (networkId == -1) {
            return false
        }

        val disconnected = manager.disconnect()
        val enabled = manager.enableNetwork(networkId, true)
        val reconnected = manager.reconnect()
        return disconnected && enabled && reconnected
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun connectUsingSpecifier(
        ssid: String,
        password: String,
        hidden: Boolean,
        allowFallback: Boolean,
    ) {
        val manager = connectivityManager ?: run {
            resolveResult(false)
            return
        }

        val specifierBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (hidden && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            specifierBuilder.setIsHiddenSsid(true)
        }
        if (password.isNotEmpty()) {
            specifierBuilder.setWpa2Passphrase(password)
        }

        val networkRequest = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .setNetworkSpecifier(specifierBuilder.build())
            .build()

        val completion = AtomicBoolean(false)

        val callback = object : NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (!completion.compareAndSet(false, true)) {
                    return
                }
                bindProcessToNetworkCompat(network)
                resolveResult(true, this)
            }

            override fun onUnavailable() {
                if (!completion.compareAndSet(false, true)) {
                    return
                }
                disconnectFromRequestedNetwork()
                if (allowFallback) {
                    mainHandler.post {
                        connectUsingSuggestion(ssid, password, hidden)
                    }
                } else {
                    resolveResult(false, this)
                }
            }

            override fun onLost(network: Network) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (connectivityManager?.boundNetworkForProcess == network) {
                        bindProcessToNetworkCompat(null)
                    }
                } else {
                    bindProcessToNetworkCompat(null)
                }

                if (completion.compareAndSet(false, true)) {
                    if (allowFallback) {
                        mainHandler.post {
                            connectUsingSuggestion(ssid, password, hidden)
                        }
                    } else {
                        resolveResult(false, this)
                    }
                }
            }
        }

        pendingCallback = callback
        try {
            manager.requestNetwork(networkRequest, callback)
        } catch (error: SecurityException) {
            disconnectFromRequestedNetwork()
            if (allowFallback) {
                connectUsingSuggestion(ssid, password, hidden)
            } else {
                resolveResult(false, callback)
            }
            return
        }

        mainHandler.postDelayed({
            if (completion.compareAndSet(false, true)) {
                disconnectFromRequestedNetwork()
                if (allowFallback) {
                    connectUsingSuggestion(ssid, password, hidden)
                } else {
                    resolveResult(false, callback)
                }
            }
        }, WIFI_REQUEST_TIMEOUT_MS)
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun connectUsingSuggestion(ssid: String, password: String, hidden: Boolean) {
        val manager = wifiManager ?: run {
            resolveResult(false)
            return
        }

        clearNetworkSuggestions(manager)

        val suggestionBuilder = WifiNetworkSuggestion.Builder().setSsid(ssid)
        if (hidden && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            suggestionBuilder.setIsHiddenSsid(true)
        }
        if (password.isNotEmpty()) {
            suggestionBuilder.setWpa2Passphrase(password)
        }

        val suggestion = suggestionBuilder.build()
        activeSuggestions.clear()
        activeSuggestions.add(suggestion)

        val status = manager.addNetworkSuggestions(activeSuggestions)
        if (status != WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS) {
            resolveResult(false)
            return
        }

        ensureSuggestionReceiverRegistered()
        suggestionTargetSsid = ssid

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val intent = Intent(Settings.Panel.ACTION_WIFI).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            runCatching { startActivity(intent) }
        }

        val completion = AtomicBoolean(false)
        suggestionCompletion = completion

        mainHandler.postDelayed({
            if (completion.compareAndSet(false, true)) {
                val connected = getCurrentSsid()?.let { normalizeSsid(it) } == normalizeSsid(ssid)
                clearNetworkSuggestions()
                resolveResult(connected)
            }
        }, WIFI_SUGGESTION_TIMEOUT_MS)
    }

    private fun ensureSuggestionReceiverRegistered() {
        if (suggestionReceiver != null) {
            return
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val target = suggestionTargetSsid ?: return
                val completion = suggestionCompletion ?: return
                if (!completion.compareAndSet(false, true)) {
                    return
                }

                val connected = getCurrentSsid()?.let { normalizeSsid(it) } == normalizeSsid(target)
                clearNetworkSuggestions()
                resolveResult(connected)
            }
        }

        val filter = IntentFilter(WifiManager.ACTION_WIFI_NETWORK_SUGGESTION_POST_CONNECTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        suggestionReceiver = receiver
    }

    private fun clearNetworkSuggestions(manager: WifiManager? = wifiManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (manager != null && activeSuggestions.isNotEmpty()) {
                runCatching { manager.removeNetworkSuggestions(activeSuggestions) }
            }
            activeSuggestions.clear()
        } else {
            activeSuggestions.clear()
        }
        suggestionTargetSsid = null
        suggestionCompletion = null
    }

    private fun resolveResult(success: Boolean, sourceCallback: NetworkCallback? = null) {
        if (sourceCallback != null && sourceCallback !== pendingCallback) {
            return
        }

        pendingResult?.let { result ->
            pendingResult = null
            suggestionCompletion = null
            mainHandler.post {
                result.success(success)
            }
        }
    }

    private fun cancelPendingResult(success: Boolean) {
        pendingResult?.let { result ->
            pendingResult = null
            suggestionCompletion = null
            mainHandler.post {
                result.success(success)
            }
        }
    }

    private fun disconnectFromRequestedNetwork() {
        val manager = connectivityManager ?: return
        pendingCallback?.let { callback ->
            runCatching { manager.unregisterNetworkCallback(callback) }
        }
        pendingCallback = null
        bindProcessToNetworkCompat(null)
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentSsid(): String? {
        val info = wifiManager?.connectionInfo ?: return null
        val ssid = info.ssid ?: return null
        if (ssid.equals("<unknown ssid>", ignoreCase = true)) {
            return null
        }
        return ssid.replace("\"", "")
    }

    private fun bindProcessToNetworkCompat(network: Network?) {
        val manager = connectivityManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.bindProcessToNetwork(network)
        } else {
            @Suppress("DEPRECATION")
            ConnectivityManager.setProcessDefaultNetwork(network)
        }
    }

    private fun quoteIfNeeded(value: String): String {
        return if (value.startsWith('"') && value.endsWith('"')) {
            value
        } else {
            "\"$value\""
        }
    }

    private fun normalizeSsid(value: String): String = value.trim().removePrefix("\"").removeSuffix("\"")

    override fun onDestroy() {
        super.onDestroy()
        disconnectFromRequestedNetwork()
        clearNetworkSuggestions()
        suggestionReceiver?.let {
            runCatching { unregisterReceiver(it) }
        }
        suggestionReceiver = null
        cancelPendingResult(false)
    }

    companion object {
        private const val WIFI_REQUEST_TIMEOUT_MS = 15_000L
        private const val WIFI_SUGGESTION_TIMEOUT_MS = 30_000L
    }
}
