package com.lxf.super_beacon

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

public class BeaconPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(
            binding.binaryMessenger,
            "com.lxf/super_beacon/methods",
        )
        eventChannel = EventChannel(
            binding.binaryMessenger,
            "com.lxf/super_beacon/events",
        )
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> configure(call, result)
            "requestPermissions" -> requestPermissions(result)
            "startMonitoring" -> result.success(BeaconMonitor.start(context))
            "stopMonitoring" -> {
                BeaconMonitor.stop(context)
                result.success(null)
            }
            "getSnapshot" -> result.success(snapshot())
            "clearEvents" -> {
                BeaconStorage.clearEvents(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        if (arguments == null || !BeaconStorage.saveConfiguration(context, arguments)) {
            result.error("invalid_configuration", "Invalid beacon configuration", null)
            return
        }
        result.success(null)
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("activity_unavailable", "An Activity is required", null)
            return
        }
        if (permissionResult != null) {
            result.error("permission_request_in_progress", "A permission request is already active", null)
            return
        }
        val permissions = requiredForegroundPermissions().filter { permission ->
            ContextCompat.checkSelfPermission(currentActivity, permission) !=
                PackageManager.PERMISSION_GRANTED
        }
        if (permissions.isEmpty()) {
            requestBackgroundLocation(currentActivity, result)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            currentActivity,
            permissions.toTypedArray(),
            foregroundPermissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != foregroundPermissionRequestCode &&
            requestCode != backgroundPermissionRequestCode
        ) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        val result = permissionResult
        if (requestCode == foregroundPermissionRequestCode && granted && result != null) {
            permissionResult = null
            val currentActivity = activity
            if (currentActivity == null) {
                result.error("activity_unavailable", "An Activity is required", null)
            } else {
                requestBackgroundLocation(currentActivity, result)
            }
        } else {
            result?.success(granted)
            permissionResult = null
        }
        return true
    }

    private fun requestBackgroundLocation(activity: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}"),
            )
            activity.startActivity(intent)
            result.success(false)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            backgroundPermissionRequestCode,
        )
    }

    private fun requiredForegroundPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            buildList {
                addAll(
                    listOf(
                        Manifest.permission.BLUETOOTH_SCAN,
                        Manifest.permission.BLUETOOTH_CONNECT,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                    ),
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    BeaconStorage.configuration(context)?.notifications?.enabled == true
                ) {
                    add(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        } else {
            listOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        }
    }

    private fun snapshot(): Map<String, Any?> {
        val adapter = context.getSystemService(BluetoothManager::class.java)?.adapter
        val bluetoothState = when (adapter?.state) {
            BluetoothAdapter.STATE_ON -> "poweredOn"
            BluetoothAdapter.STATE_OFF -> "poweredOff"
            else -> "unknown"
        }
        val locationGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val configuration = BeaconStorage.configuration(context)
        return mapOf(
            "monitoring" to BeaconStorage.isMonitoring(context),
            "bluetoothState" to bluetoothState,
            "locationPermission" to if (locationGranted) "granted" else "denied",
            "configuration" to mapOf(
                "notificationsEnabled" to (configuration?.notifications?.enabled ?: false),
                "eventCooldownMillis" to (configuration?.eventCooldownMillis ?: 10_000L),
                "iosBluetoothScanningEnabled" to false,
            ),
            "capabilities" to mapOf(
                "coreLocationRegionMonitoring" to false,
                "bluetoothAdvertisementScanning" to true,
                "backgroundAdvertisementScanning" to true,
                "continuousBackgroundScanningGuaranteed" to false,
                "relaunchAfterUserForceQuit" to false,
                "manufacturerDataOnRegionEvents" to true,
            ),
            "events" to BeaconStorage.eventMaps(context),
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        BeaconEventBus.sink = events
    }

    override fun onCancel(arguments: Any?) {
        BeaconEventBus.sink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        BeaconEventBus.sink = null
    }

    private companion object {
        const val foregroundPermissionRequestCode = 41002
        const val backgroundPermissionRequestCode = 41003
    }
}
