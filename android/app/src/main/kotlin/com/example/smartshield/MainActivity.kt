package com.example.smartshield

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.smartshield/permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
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

            // skip system apps with no permissions
            if (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0
                && perms.isEmpty()) {
                return@mapNotNull null
            }

            // skip apps with no permissions at all
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

        // get all apps that have a launcher icon
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val launcherApps = pm.queryIntentActivities(launcherIntent, 0)
            .map { it.activityInfo.packageName }
            .toSet()

        return apps.mapNotNull { appInfo ->
            try {
                // skip system apps
                if (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM != 0)
                    return@mapNotNull null

                val packageName = appInfo.packageName
                val appName = pm.getApplicationLabel(appInfo).toString()

                // skip our own app
                if (packageName == this.packageName) return@mapNotNull null

                // if not in launcher = hidden
                if (packageName in launcherApps) return@mapNotNull null

                val perms = try {
                    pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
                        .requestedPermissions?.toList() ?: emptyList()
                } catch (e: Exception) { emptyList() }

                // only flag if it has sensitive permissions
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

            // skip system accessibility services
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