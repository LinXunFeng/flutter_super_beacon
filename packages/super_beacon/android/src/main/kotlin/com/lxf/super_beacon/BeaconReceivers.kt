package com.lxf.super_beacon

import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Receives BLE results delivered by the system-owned scan PendingIntent. */
public class BeaconScanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BeaconMonitor.scanAction) return
        val errorCode = intent.getIntExtra(BluetoothLeScanner.EXTRA_ERROR_CODE, 0)
        if (errorCode != 0) {
            BeaconEventBus.emit(
                context,
                BeaconNativeEvent(
                    type = "error",
                    message = "BLE scan error: $errorCode",
                ),
            )
            return
        }
        scanResults(intent).forEach { result -> handleResult(context, result) }
    }

    private fun handleResult(context: Context, result: ScanResult) {
        val manufacturerId = 0x004C
        val data = result.scanRecord?.getManufacturerSpecificData(manufacturerId)
        val beacon = IBeaconParser.parseManufacturerData(data, manufacturerId) ?: return
        val configuration = BeaconStorage.configuration(context) ?: return
        val region = configuration.regions.firstOrNull { it.matches(beacon) }
            ?: return
        val timestamp = System.currentTimeMillis()
        val lastSeen = BeaconStorage.lastSeen(context, region.identifier)
        // Android has no native iBeacon exit callback. A scan after a completed
        // timeout starts a new inside interval and therefore emits enter again.
        val entered = lastSeen == 0L ||
            timestamp - lastSeen >= configuration.exitTimeoutMillis
        val location = if (entered) BeaconLocationProvider.recent(context) else null
        BeaconStorage.setLastSeen(context, region.identifier, timestamp)
        BeaconMonitor.scheduleExit(
            context = context,
            region = region,
            expectedLastSeen = timestamp,
            timeoutMillis = configuration.exitTimeoutMillis,
        )
        if (entered) {
            BeaconEventBus.emit(
                context,
                BeaconNativeEvent(
                    type = "regionEntered",
                    state = "inside",
                    source = "androidBle",
                    regionIdentifier = region.identifier,
                    manufacturerData = beacon.manufacturerMap(),
                    latitude = location?.latitude,
                    longitude = location?.longitude,
                    accuracy = location?.accuracy?.toDouble(),
                    locationTimestamp = location?.time,
                ),
            )
        }
        BeaconEventBus.emit(
            context,
            BeaconNativeEvent(
                type = "beaconRanged",
                state = "inside",
                source = "androidBle",
                regionIdentifier = region.identifier,
                manufacturerData = beacon.manufacturerMap(),
                reading = mapOf(
                    "uuid" to beacon.uuid,
                    "major" to beacon.major,
                    "minor" to beacon.minor,
                    "rssi" to result.rssi,
                    "txPower" to beacon.txPower,
                    "proximity" to "unknown",
                ),
            ),
        )
    }

    private fun ParsedBeacon.manufacturerMap(): Map<String, Any?> = mapOf(
        "manufacturerId" to manufacturerId,
        "bytes" to manufacturerBytes,
        "hex" to manufacturerHex,
    )

    private fun scanResults(intent: Intent): List<ScanResult> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(
                BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT,
                ScanResult::class.java,
            ).orEmpty()
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<ScanResult>(
                BluetoothLeScanner.EXTRA_LIST_SCAN_RESULT,
            ).orEmpty()
        }
    }
}

/** Emits an inferred exit when no newer scan has refreshed the region alarm. */
public class BeaconExitReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BeaconMonitor.exitAction) return
        val identifier = intent.getStringExtra("identifier") ?: return
        val expected = intent.getLongExtra("expectedLastSeen", 0L)
        if (BeaconStorage.lastSeen(context, identifier) != expected) return
        BeaconEventBus.emit(
            context,
            BeaconNativeEvent(
                type = "regionExited",
                state = "outside",
                regionIdentifier = identifier,
            ),
        )
    }
}

/** Restores monitoring after boot, package replacement, or Bluetooth restart. */
public class BeaconBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val shouldRestart = intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            (intent.action == BluetoothAdapter.ACTION_STATE_CHANGED &&
                intent.getIntExtra(
                    BluetoothAdapter.EXTRA_STATE,
                    BluetoothAdapter.ERROR,
                ) == BluetoothAdapter.STATE_ON)
        if (shouldRestart && BeaconStorage.isMonitoring(context)) {
            BeaconMonitor.start(context)
        }
    }
}
