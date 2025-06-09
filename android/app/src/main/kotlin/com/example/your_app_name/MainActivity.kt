package com.example.your_app_name // Replace with your actual package name

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// It's common to have a separate class for plugin logic, but for simplicity:
object YourAppFlutterPlugin {
    private var eventSink: EventChannel.EventSink? = null

    fun registerWith(flutterEngine: FlutterEngine, context: MainActivity) {
        val vpnControlChannel = "com.example.your_app_name/vpn_control"
        val vpnStatusChannel = "com.example.your_app_name/vpn_status"
        val VPN_REQUEST_CODE = 101


        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnControlChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    val intent = VpnService.prepare(context)
                    if (intent != null) {
                        context.setVpnPermissionResultCallback(result) // Store the result callback
                        context.startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        // Permission already granted
                        result.success(true)
                    }
                }
                "startVpn" -> {
                    val configJson = call.argument<String>("configJson")
                    // val enableForeground = call.argument<Boolean>("enableForeground") // TODO: Use this
                    if (configJson != null) {
                        val serviceIntent = Intent(context, MyVpnService::class.java).apply {
                            action = MyVpnService.ACTION_CONNECT
                            putExtra(MyVpnService.EXTRA_CONFIG_JSON, configJson)
                        }
                        context.startService(serviceIntent) // Use startForegroundService for API 26+ if needed
                        result.success(null) // Indicate method call was received
                    } else {
                        result.error("INVALID_ARG", "Config JSON is null", null)
                    }
                }
                "stopVpn" -> {
                    val serviceIntent = Intent(context, MyVpnService::class.java).apply {
                        action = MyVpnService.ACTION_DISCONNECT
                    }
                    context.startService(serviceIntent)
                    result.success(null) // Indicate method call was received
                }
                "getVpnStatus" -> {
                    // This is tricky, status is usually pushed.
                    // Could query a static variable in MyVpnService or use SharedPreferences
                    // For now, let's assume status is primarily pushed via EventChannel
                    result.notImplemented()
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, vpnStatusChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // Optionally send an initial "DISCONNECTED" or last known state
                    eventSink?.success("DISCONNECTED")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    // Called by MyVpnService or other native parts to send status to Flutter
    fun sendVpnState(state: String) {
        eventSink?.success(state)
    }

    fun onVpnPermissionResult(granted: Boolean, pendingResult: MethodChannel.Result?) {
        pendingResult?.success(granted)
    }
}


class MainActivity: FlutterActivity() {
    private val VPN_REQUEST_CODE = 101
    private var vpnPermissionResultCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        YourAppFlutterPlugin.registerWith(flutterEngine, this)
    }

    fun setVpnPermissionResultCallback(result: MethodChannel.Result) {
        this.vpnPermissionResultCallback = result
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            YourAppFlutterPlugin.onVpnPermissionResult(granted, vpnPermissionResultCallback)
            vpnPermissionResultCallback = null // Clear callback after use
        }
    }
}
