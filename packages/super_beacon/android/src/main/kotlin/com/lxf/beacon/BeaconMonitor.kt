package com.lxf.beacon

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.UUID

/** Starts and stops Android PendingIntent-based iBeacon monitoring. */
public object BeaconMonitor {
    internal const val scanAction = "com.lxf.beacon.SCAN"
    internal const val exitAction = "com.lxf.beacon.EXIT"
    private const val manufacturerId = 0x004C

    /**
     * Registers the BLE scan described by the persisted configuration.
     *
     * @return false when configuration, permission, Bluetooth, or scan
     * registration is unavailable.
     */
    @JvmStatic
    public fun start(context: Context): Boolean {
        val appContext = context.applicationContext
        val configuration = BeaconStorage.configuration(appContext) ?: return false
        if (!hasScanPermission(appContext)) return false
        val scanner = appContext.getSystemService(BluetoothManager::class.java)
            ?.adapter?.bluetoothLeScanner ?: return false
        return try {
            scanner.stopScan(scanPendingIntent(appContext))
            val filters = configuration.regions.map(::scanFilter)
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
                .setCallbackType(ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
                .build()
            val result = scanner.startScan(
                filters,
                settings,
                scanPendingIntent(appContext),
            )
            val started = result == 0
            BeaconStorage.setMonitoring(appContext, started)
            BeaconEventBus.emit(
                appContext,
                BeaconNativeEvent(
                    type = if (started) "monitoringStarted" else "error",
                    message = if (started) null else "BLE scan registration failed: $result",
                ),
            )
            started
        } catch (error: SecurityException) {
            BeaconStorage.setMonitoring(appContext, false)
            BeaconEventBus.emit(
                appContext,
                BeaconNativeEvent(type = "error", message = error.message),
            )
            false
        }
    }

    /** Stops the registered BLE scan while retaining configuration and events. */
    @JvmStatic
    public fun stop(context: Context) {
        val appContext = context.applicationContext
        try {
            appContext.getSystemService(BluetoothManager::class.java)
                ?.adapter?.bluetoothLeScanner
                ?.stopScan(scanPendingIntent(appContext))
        } catch (_: SecurityException) {
        }
        BeaconStorage.setMonitoring(appContext, false)
        BeaconEventBus.emit(
            appContext,
            BeaconNativeEvent(type = "monitoringStopped"),
        )
    }

    internal fun scheduleExit(
        context: Context,
        region: NativeRegion,
        expectedLastSeen: Long,
        timeoutMillis: Long,
    ) {
        // Each scan replaces the alarm for its region. The expected timestamp
        // lets the receiver discard an older alarm that races with a new scan.
        val intent = Intent(context, BeaconExitReceiver::class.java)
            .setAction(exitAction)
            .putExtra("identifier", region.identifier)
            .putExtra("expectedLastSeen", expectedLastSeen)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            region.identifier.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        context.getSystemService(AlarmManager::class.java)?.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            expectedLastSeen + timeoutMillis,
            pendingIntent,
        )
    }

    private fun scanFilter(region: NativeRegion): ScanFilter {
        val uuidBytes = uuidBytes(region.uuid)
        val dataLength = when {
            region.minor != null -> 22
            region.major != null -> 20
            else -> 18
        }
        val data = ByteArray(dataLength)
        // Apple's iBeacon manufacturer payload starts with the 0x02, 0x15 type
        // and length prefix, followed by UUID and optional major/minor fields.
        data[0] = 0x02
        data[1] = 0x15
        uuidBytes.copyInto(data, destinationOffset = 2)
        region.major?.let { value ->
            data[18] = (value shr 8).toByte()
            data[19] = value.toByte()
        }
        region.minor?.let { value ->
            data[20] = (value shr 8).toByte()
            data[21] = value.toByte()
        }
        return ScanFilter.Builder()
            .setManufacturerData(
                manufacturerId,
                data,
                ByteArray(data.size) { 0xFF.toByte() },
            )
            .build()
    }

    private fun scanPendingIntent(context: Context): PendingIntent {
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        val intent = Intent(context, BeaconScanReceiver::class.java)
            .setAction(scanAction)
        return PendingIntent.getBroadcast(
            context,
            41001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or mutable,
        )
    }

    private fun hasScanPermission(context: Context): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Manifest.permission.BLUETOOTH_SCAN
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
        return ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun uuidBytes(value: String): ByteArray {
        val uuid = UUID.fromString(value)
        val result = ByteArray(16)
        for (index in 0 until 8) {
            result[index] = (uuid.mostSignificantBits shr (56 - index * 8)).toByte()
            result[index + 8] =
                (uuid.leastSignificantBits shr (56 - index * 8)).toByte()
        }
        return result
    }
}
