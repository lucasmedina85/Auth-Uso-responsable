package com.example.flutter_app
 
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.authenticator/security"
    private val DEEPLINK_CHANNEL = "com.authenticator/deeplink"
    private var initialLink: String? = null
    private var deeplinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.dataString?.let {
            initialLink = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { link ->
            deeplinkChannel?.invokeMethod("onLink", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        deeplinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
        deeplinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = initialLink
                    initialLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecureMode" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecureMode" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "checkEmulator" -> {
                    val detector = EmulatorDetector(this)
                    val detection = detector.checkEmulator()
                    val resultMap = mapOf(
                        "isEmulator" to detection.isEmulator,
                        "score" to detection.score,
                        "reasons" to detection.reasons
                    )
                    result.success(resultMap)
                }
                "checkRoot" -> {
                    val detector = RootDetector(this)
                    val detection = detector.checkRoot()
                    val resultMap = mapOf(
                        "isRooted" to detection.isRooted,
                        "reasons" to detection.reasons
                    )
                    result.success(resultMap)
                }
                "checkVpnAndProxy" -> {
                    val detector = NetworkSecurityDetector(this)
                    val detection = detector.checkVpnAndProxy()
                    val resultMap = mapOf(
                        "isVpn" to detection.isVpn,
                        "isProxy" to detection.isProxy,
                        "vpnInterface" to detection.vpnInterface,
                        "proxyDetails" to detection.proxyDetails
                    )
                    result.success(resultMap)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.authenticator/device_integrity").setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDeviceIntegrity" -> {
                    val emuDetector = EmulatorDetector(this)
                    val emuDetection = emuDetector.checkEmulator()

                    val rootDetector = RootDetector(this)
                    val rootDetection = rootDetector.checkRoot()

                    val combinedReasons = mutableListOf<String>()
                    combinedReasons.addAll(emuDetection.reasons)
                    combinedReasons.addAll(rootDetection.reasons)

                    val isCompromised = emuDetection.isEmulator || rootDetection.isRooted

                    val resultMap = mapOf(
                        "isCompromised" to isCompromised,
                        "isEmulator" to emuDetection.isEmulator,
                        "isRooted" to rootDetection.isRooted,
                        "score" to emuDetection.score,
                        "reasons" to combinedReasons
                    )
                    result.success(resultMap)
                }
                else -> result.notImplemented()
            }
        }
    }
}
