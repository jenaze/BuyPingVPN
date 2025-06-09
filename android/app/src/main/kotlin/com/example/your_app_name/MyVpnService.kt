package com.example.your_app_name // Replace with your actual package name

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat

// Ensure this class is within the correct package structure matching your Flutter app's android part
// e.g., com.yourdomain.yourappname

class MyVpnService : VpnService() {

    private val TAG = "MyVpnService"
    private val NOTIFICATION_ID = 1
    private val NOTIFICATION_CHANNEL_ID = "MyVpnServiceChannel"

    private var vpnInterface: ParcelFileDescriptor? = null
    private var v2rayProcess: Process? = null // Manages the V2Ray core process

    companion object {
        const val ACTION_CONNECT = "com.example.your_app_name.CONNECT"
        const val ACTION_DISCONNECT = "com.example.your_app_name.DISCONNECT"
        const val EXTRA_CONFIG_JSON = "com.example.your_app_name.CONFIG_JSON"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service Created")
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand received: ${intent?.action}")
        when (intent?.action) {
            ACTION_CONNECT -> {
                val configJson = intent.getStringExtra(EXTRA_CONFIG_JSON)
                if (configJson != null) {
                    startVpn(configJson)
                    return START_STICKY
                } else {
                    Log.e(TAG, "Config JSON is null, stopping service.")
                    stopSelf() // or handle error appropriately
                    return START_NOT_STICKY
                }
            }
            ACTION_DISCONNECT -> {
                stopVpn()
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn(configJson: String) {
        Log.d(TAG, "Starting VPN with config: $configJson")
        // 1. Start Foreground Service
        startForeground(NOTIFICATION_ID, createNotification("VPN Connecting..."))

        // 2. TODO: Start V2Ray Core Process
        //    - Copy V2Ray executable from assets to app's private files dir (if not already done).
        //    - Write configJson to a temporary file that V2Ray can read.
        //    - Use ProcessBuilder to start V2Ray.
        //    - Example: v2rayProcess = ProcessBuilder("path/to/v2ray", "-config", "path/to/config.json").start()
        //    - Manage its stdout/stderr for logs.
        //    - Ensure V2Ray is configured to listen on a local SOCKS5/HTTP port (e.g., 127.0.0.1:10808).
        //    - Crucially, V2Ray's own outbound connections MUST be protected by VpnService.protect().
        //      This is complex. If V2Ray is just an executable, it might need to be run as a specific user
        //      or use specific flags if it supports binding to an interface or using socket protection.
        //      Alternatively, if V2Ray is a library, it might provide an API to set a socket protector.

        // 3. Establish VPN Tunnel
        try {
            val builder = Builder()
            builder.setSession(applicationInfo.loadLabel(packageManager).toString()) // App name as session name
            builder.addAddress("10.0.0.2", 30) // Example VPN interface address
            builder.addRoute("0.0.0.0", 0)    // Route all traffic
            // TODO: Configure DNS servers, potentially from V2Ray config or system defaults
            builder.addDnsServer("8.8.8.8")
            builder.setMtu(1500) // Standard MTU

            // TODO: Configure V2Ray to listen on a local SOCKS5/HTTP port (e.g. 127.0.0.1:10808)
            // The VpnService needs to then forward traffic from the TUN interface (vpnInterface)
            // to this local V2Ray proxy. This is the most complex part.
            // For SOCKS5 proxy mode: builder.addAllowedApplication("com.example.your_app_name") might NOT be what you want.
            // You need to capture all traffic and forward it to V2Ray.
            // V2Ray itself should be the only one making direct outbound connections (which are protected).

            // This is where you'd typically set the underlying SOCKS5/HTTP proxy for the VPN if VpnService supports it directly,
            // or start your own TUN-to-proxy implementation.
            // For example, some VpnService implementations might have:
            // builder.setHttpProxy(ProxyInfo.buildDirectProxy("127.0.0.1", 10808)) // If using HTTP proxy
            // builder.setUnderlyingNetworks(null) // Use any available network

            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                Log.e(TAG, "VPN establish returned null. Revoked permission or other issue.")
                // Notify Flutter of error: "VPN_PERMISSION_REVOKED" or "VPN_SETUP_FAILED"
                stopVpn()
                return
            }
            Log.d(TAG, "VPN Interface established.")

            // TODO: Start your TUN packet processing logic here.
            // This involves reading from vpnInterface.fileDescriptor, parsing IP packets,
            // and forwarding TCP/UDP streams to the local V2Ray SOCKS5/HTTP proxy.
            // This is a very complex part, often requiring a C/C++ library or a sophisticated Java/Kotlin implementation.
            // For example, using something like Outline's "IPtProxy" or "tun2socks" concepts.

            // Notify Flutter: VPN is "CONNECTED"
            updateNotification("VPN Connected")
            sendStateToFlutter("CONNECTED")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting VPN: ${e.message}", e)
            // Notify Flutter of error
            sendStateToFlutter("ERROR: ${e.message}")
            stopVpn()
        }
    }

    private fun stopVpn() {
        Log.d(TAG, "Stopping VPN")
        // Notify Flutter: VPN is "DISCONNECTED"
        sendStateToFlutter("DISCONNECTED")

        // 1. Stop V2Ray Core Process
        v2rayProcess?.destroy()
        v2rayProcess = null

        // 2. Close VPN Interface
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface: ${e.message}", e)
        }
        vpnInterface = null

        // 3. Stop Foreground Service
        stopForeground(true)
        stopSelf()
    }

    private fun createNotification(text: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java) // Or your FlutterActivity
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("V2Ray VPN")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher) // Replace with your actual icon
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun sendStateToFlutter(state: String) {
        // This method needs to communicate back to Flutter, e.g., via EventChannel
        // This might involve LocalBroadcastManager to send to MainActivity/Plugin,
        // which then forwards to Flutter.
        Log.d(TAG, "Sending state to Flutter: $state")
        val intent = Intent("com.example.your_app_name.VPN_STATUS_UPDATE")
        intent.putExtra("status", state)
        // LocalBroadcastManager.getInstance(this).sendBroadcast(intent) // Example
        // Or if your EventChannel sink is managed here directly or via a bound service.
        YourAppFlutterPlugin.sendVpnState(state) // Assuming a static method in your plugin
    }


    override fun onRevoke() {
        Log.w(TAG, "VPN Revoked")
        stopVpn()
        super.onRevoke()
    }

    override fun onDestroy() {
        Log.d(TAG, "VPN Service Destroyed")
        stopVpn() // Ensure cleanup
        super.onDestroy()
    }
}
