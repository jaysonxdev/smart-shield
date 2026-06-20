package com.example.smartshield

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val permChannel = "com.smartshield/permissions"
    private val btChannelName = "com.smartshield/bluetooth"
    private var btMethodChannel: MethodChannel? = null

    companion object {
        private const val BT_NOTIF_CHANNEL_ID = "bt_connections"
    }

    // Receives ACTION_ACL_CONNECTED whenever any Bluetooth device connects.
    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != BluetoothDevice.ACTION_ACL_CONNECTED) return

            val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
            }

            // BLUETOOTH_CONNECT is required to read the device name on API 31+.
            // Fall back to "Unknown device" when the permission is absent.
            val deviceName: String = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    device?.name ?: "Unknown device"
                } else {
                    "Unknown device"
                }
            } else {
                device?.name ?: "Unknown device"
            }

            showBluetoothNotification(deviceName)

            // Forward to Flutter so the app can react while foregrounded.
            runOnUiThread { btMethodChannel?.invokeMethod("bluetoothDeviceConnected", deviceName) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        registerBluetoothReceiver()
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(bluetoothReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was never registered (edge-case defensive cleanup).
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                BT_NOTIF_CHANNEL_ID,
                "Bluetooth Connections",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Alerts when a Bluetooth device connects to your phone"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun registerBluetoothReceiver() {
        val filter = IntentFilter(BluetoothDevice.ACTION_ACL_CONNECTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(bluetoothReceiver, filter)
        }
    }

    private fun showBluetoothNotification(deviceName: String) {
        val notification = NotificationCompat.Builder(this, BT_NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Bluetooth device connected")
            .setContentText("$deviceName — make sure you recognize this device.")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("$deviceName — make sure you recognize this device.")
            )
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(System.currentTimeMillis().toInt(), notification)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppPermissions" -> {
                        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                        Thread {
                            try {
                                val data = getAppPermissions()
                                mainHandler.post { result.success(data) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "getHiddenApps" -> result.success(getHiddenApps())
                    "getDeviceAdminApps" -> result.success(getDeviceAdminApps())
                    "getAccessibilityApps" -> result.success(getAccessibilityApps())
                    else -> result.notImplemented()
                }
            }

        // Separate channel used for native → Flutter Bluetooth events.
        btMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, btChannelName)
    }

    private fun wasUsedRecently(appOps: AppOpsManager, packageName: String, op: String): Boolean {
        return try {
            val uid = packageManager.getPackageInfo(packageName, 0).applicationInfo
            if (uid == null) return false
            val mode = appOps.checkOpNoThrow(op, uid.uid, packageName)
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun getAppPermissions(): List<Map<String, Any>> {
        val pm = packageManager
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps.mapNotNull { appInfo ->
            try {
                val appName = pm.getApplicationLabel(appInfo).toString()
                val packageName = appInfo.packageName

                val perms: List<String> = try {
                    pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
                        .requestedPermissions?.toList() ?: emptyList()
                } catch (e: Exception) { emptyList() }

                if (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0
                    && perms.isEmpty()) {
                    return@mapNotNull null
                }

                if (perms.isEmpty()) return@mapNotNull null

                val friendlyPerms: List<String> = perms.map {
                    it.removePrefix("android.permission.")
                        .replace("_", " ")
                        .lowercase()
                        .replaceFirstChar { c -> c.uppercase() }
                }

                mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "permissions" to friendlyPerms,
                    "isSystemApp" to ((appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0),
                    "usedCameraRecently" to wasUsedRecently(appOps, packageName, AppOpsManager.OPSTR_CAMERA),
                    "usedMicRecently" to wasUsedRecently(appOps, packageName, AppOpsManager.OPSTR_RECORD_AUDIO),
                    "usedLocationRecently" to wasUsedRecently(appOps, packageName, AppOpsManager.OPSTR_FINE_LOCATION),
                )
            } catch (e: Exception) { null }
        }
    }

    private fun getHiddenApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherApps = pm.queryIntentActivities(launcherIntent, 0)
            .map { it.activityInfo.packageName }
            .toSet()

        return apps.mapNotNull { appInfo ->
            try {
                if (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0)
                    return@mapNotNull null

                val packageName = appInfo.packageName
                val appName = pm.getApplicationLabel(appInfo).toString()

                if (packageName == this.packageName) return@mapNotNull null
                if (packageName in launcherApps) return@mapNotNull null

                val perms = try {
                    pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
                        .requestedPermissions?.toList() ?: emptyList()
                } catch (e: Exception) { emptyList() }

                val sensitivePerms = listOf(
                    "android.permission.CAMERA",
                    "android.permission.RECORD_AUDIO",
                    "android.permission.ACCESS_FINE_LOCATION",
                    "android.permission.READ_CONTACTS",
                    "android.permission.READ_SMS",
                    "android.permission.READ_CALL_LOG",
                    "android.permission.PROCESS_OUTGOING_CALLS",
                )

                val foundSensitive = perms.filter { it in sensitivePerms }
                if (foundSensitive.isEmpty()) return@mapNotNull null

                mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "sensitivePermissions" to foundSensitive.map {
                        it.removePrefix("android.permission.")
                            .replace("_", " ")
                            .lowercase()
                            .replaceFirstChar { c -> c.uppercase() }
                    },
                )
            } catch (e: Exception) { null }
        }
    }

    private fun getDeviceAdminApps(): List<Map<String, Any>> {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admins = dpm.activeAdmins ?: return emptyList()

        return admins.mapNotNull { admin ->
            try {
                val appInfo = packageManager.getApplicationInfo(admin.packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                mapOf(
                    "appName" to appName,
                    "packageName" to admin.packageName,
                )
            } catch (e: Exception) { null }
        }
    }

    private fun getAccessibilityApps(): List<Map<String, Any>> {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val services = am.getEnabledAccessibilityServiceList(
            android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )

        return services.mapNotNull { service ->
            try {
                val packageName = service.resolveInfo.serviceInfo.packageName
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()

                if (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0)
                    return@mapNotNull null

                mapOf(
                    "appName" to appName,
                    "packageName" to packageName,
                    "serviceName" to service.resolveInfo.serviceInfo.name,
                )
            } catch (e: Exception) { null }
        }
    }
}
