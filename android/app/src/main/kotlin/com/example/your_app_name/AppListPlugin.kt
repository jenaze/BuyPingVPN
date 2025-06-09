package com.example.your_app_name // Replace with your actual package name

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class AppListPlugin(private val context: Context, private val packageManager: PackageManager) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL_NAME = "com.example.your_app_name/app_list"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            val plugin = AppListPlugin(context.applicationContext, context.packageManager)
            channel.setMethodCallHandler(plugin)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getInstalledApplications") {
            try {
                val includeSystemApps = call.argument<Boolean>("includeSystemApps") ?: false
                val includeAppIcons = call.argument<Boolean>("includeAppIcons") ?: false
                val apps = getInstalledApplications(includeSystemApps, includeAppIcons)
                result.success(apps)
            } catch (e: Exception) {
                result.error("APP_LIST_ERROR", "Failed to get installed applications: ${e.message}", null)
            }
        } else {
            result.notImplemented()
        }
    }

    private fun getInstalledApplications(includeSystemApps: Boolean, includeAppIcons: Boolean): List<Map<String, Any?>> {
        val appsList = mutableListOf<Map<String, Any?>>()
        // Consider using getInstalledPackages for more control if needed.
        // For Android 11 (API 30) and above, QUERY_ALL_PACKAGES permission is needed in AndroidManifest.xml
        // to see all apps. Otherwise, the list will be filtered based on manifest queries.
        val packages = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in packages) {
            if (!includeSystemApps && (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                // Skip system apps if not requested
                continue
            }
            // Optional: Skip apps that don't have a launch intent
            // if (packageManager.getLaunchIntentForPackage(appInfo.packageName) == null && !includeSystemApps) {
            //    continue;
            // }

            val appName = appInfo.loadLabel(packageManager).toString()
            val packageName = appInfo.packageName
            var iconByteArray: String? = null // Base64 encoded string

            if (includeAppIcons) {
                try {
                    val iconDrawable: Drawable = appInfo.loadIcon(packageManager)
                    iconByteArray = drawableToBas64(iconDrawable)
                } catch (e: Exception) {
                    // Log error or handle missing icon
                }
            }

            val appMap = mapOf(
                "appName" to appName,
                "packageName" to packageName,
                "icon" to iconByteArray
            )
            appsList.add(appMap)
        }
        return appsList
    }

    private fun drawableToBas64(drawable: Drawable?): String? {
        if (drawable == null) return null
        try {
            val bitmap: Bitmap = if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
                // Single color bitmap will be created of 1x1 pixel
                Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            } else {
                Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            }

            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            // Log error
            return null
        }
    }
}
