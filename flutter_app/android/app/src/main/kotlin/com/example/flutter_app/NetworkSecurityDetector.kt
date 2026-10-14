package com.example.flutter_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import java.net.NetworkInterface
import java.util.Collections
import java.util.Locale

class NetworkSecurityDetector(private val context: Context) {

    data class NetworkSecurityResult(
        val isVpn: Boolean,
        val isProxy: Boolean,
        val vpnInterface: String?,
        val proxyDetails: String?
    )

    fun checkVpnAndProxy(): NetworkSecurityResult {
        val (isVpnCapabilities, vpnCapReason) = checkVpnCapabilities()
        val (isVpnInterface, vpnIfReason) = checkNetworkInterfaces()
        val (isProxy, proxyDetails) = checkSystemProxy()

        val isVpn = isVpnCapabilities || isVpnInterface
        val vpnReason = vpnCapReason ?: vpnIfReason

        return NetworkSecurityResult(
            isVpn = isVpn,
            isProxy = isProxy,
            vpnInterface = vpnReason,
            proxyDetails = proxyDetails
        )
    }

    private fun checkVpnCapabilities(): Pair<Boolean, String?> {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return Pair(false, null)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val activeNetwork = cm.activeNetwork ?: return Pair(false, null)
                val caps = cm.getNetworkCapabilities(activeNetwork) ?: return Pair(false, null)
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                    return Pair(true, "TRANSPORT_VPN")
                }
            }
        } catch (_: Exception) {
            // Permission or connectivity error
        }
        return Pair(false, null)
    }

    private fun checkNetworkInterfaces(): Pair<Boolean, String?> {
        try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (intf in interfaces) {
                if (!intf.isUp) continue
                val name = intf.name.lowercase(Locale.ROOT)
                if (name.startsWith("tun") || name.startsWith("ppp") ||
                    name.startsWith("p2p") || name.startsWith("tap") ||
                    name.startsWith("wg") || name.contains("vpn")) {
                    return Pair(true, intf.name)
                }
            }
        } catch (_: Exception) {
            // Ignore socket/interface inspection restrictions
        }
        return Pair(false, null)
    }

    private fun checkSystemProxy(): Pair<Boolean, String?> {
        try {
            val proxyHost = System.getProperty("http.proxyHost")
            val proxyPort = System.getProperty("http.proxyPort")
            if (!proxyHost.isNullOrEmpty() && !proxyPort.isNullOrEmpty() && proxyPort != "0") {
                return Pair(true, "$proxyHost:$proxyPort")
            }

            @Suppress("DEPRECATION")
            val defaultHost = android.net.Proxy.getDefaultHost()
            @Suppress("DEPRECATION")
            val defaultPort = android.net.Proxy.getDefaultPort()
            if (!defaultHost.isNullOrEmpty() && defaultPort > 0) {
                return Pair(true, "$defaultHost:$defaultPort")
            }
        } catch (_: Exception) {
            // Ignore system property access errors
        }
        return Pair(false, null)
    }
}
