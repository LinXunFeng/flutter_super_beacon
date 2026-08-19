package com.lxf.super_beacon

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal data class NativeRegion(
    val uuid: String,
    val identifier: String,
    val major: Int?,
    val minor: Int?,
) {
    fun matches(beacon: ParsedBeacon): Boolean =
        uuid.equals(beacon.uuid, ignoreCase = true) &&
            (major == null || major == beacon.major) &&
            (minor == null || minor == beacon.minor)
}

internal data class NativeConfiguration(
    val regions: List<NativeRegion>,
    val exitTimeoutMillis: Long,
    val eventCooldownMillis: Long,
    val notifications: NativeNotificationConfiguration,
    val iosBluetoothScanningEnabled: Boolean,
    val maxStoredEvents: Int,
)

internal data class NativeNotificationConfiguration(
    val enabled: Boolean,
    val channelId: String,
    val channelName: String,
    val titleTemplate: String,
    val bodyTemplate: String,
)

internal object BeaconStorage {
    private const val preferencesName = "flutter_super_beacon"
    private const val configurationKey = "configuration"
    private const val eventsKey = "events"
    private const val monitoringKey = "monitoring"

    fun saveConfiguration(context: Context, arguments: Map<*, *>): Boolean {
        val regionsValue = arguments["regions"] as? List<*> ?: return false
        val regions = regionsValue.mapNotNull { value ->
            val map = value as? Map<*, *> ?: return@mapNotNull null
            val uuid = map["uuid"]?.toString() ?: return@mapNotNull null
            val identifier = map["identifier"]?.toString()
                ?: return@mapNotNull null
            JSONObject().apply {
                put("uuid", uuid)
                put("identifier", identifier)
                put("major", map["major"])
                put("minor", map["minor"])
            }
        }
        if (regions.isEmpty()) return false
        val json = JSONObject().apply {
            put("regions", JSONArray(regions))
            put(
                "exitTimeoutMillis",
                (arguments["androidExitTimeoutMillis"] as? Number)?.toLong()
                    ?: 30_000L,
            )
            put(
                "maxStoredEvents",
                (arguments["maxStoredEvents"] as? Number)?.toInt() ?: 500,
            )
            put(
                "eventCooldownMillis",
                (arguments["eventCooldownMillis"] as? Number)?.toLong()
                    ?: 10_000L,
            )
            put(
                "notifications",
                JSONObject(arguments["notifications"] as? Map<*, *> ?: emptyMap<Any, Any>()),
            )
            put(
                "iosBluetoothScanningEnabled",
                arguments["iosBluetoothScanningEnabled"] as? Boolean ?: false,
            )
        }
        preferences(context).edit().putString(configurationKey, json.toString()).apply()
        return true
    }

    fun configuration(context: Context): NativeConfiguration? {
        val raw = preferences(context).getString(configurationKey, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val values = json.getJSONArray("regions")
            val regions = buildList {
                for (index in 0 until values.length()) {
                    val value = values.getJSONObject(index)
                    add(
                        NativeRegion(
                            uuid = value.getString("uuid"),
                            identifier = value.getString("identifier"),
                            major = value.optIntOrNull("major"),
                            minor = value.optIntOrNull("minor"),
                        ),
                    )
                }
            }
            NativeConfiguration(
                regions = regions,
                exitTimeoutMillis = json.optLong("exitTimeoutMillis", 30_000L),
                eventCooldownMillis = json.optLong("eventCooldownMillis", 10_000L)
                    .coerceAtLeast(0L),
                notifications = json.optJSONObject("notifications")
                    .toNotificationConfiguration(),
                iosBluetoothScanningEnabled = json.optBoolean(
                    "iosBluetoothScanningEnabled",
                    false,
                ),
                maxStoredEvents = json.optInt("maxStoredEvents", 500),
            )
        } catch (_: Exception) {
            null
        }
    }

    fun setMonitoring(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(monitoringKey, value).apply()
    }

    fun isMonitoring(context: Context): Boolean =
        preferences(context).getBoolean(monitoringKey, false)

    fun appendEvent(context: Context, event: BeaconNativeEvent) {
        val current = eventMaps(context).toMutableList()
        current.add(0, event.toMap())
        val limit = configuration(context)?.maxStoredEvents ?: 500
        val retained = current.take(limit)
        val values = JSONArray()
        retained.forEach { values.put(JSONObject(it)) }
        preferences(context).edit().putString(eventsKey, values.toString()).apply()
    }

    fun eventMaps(context: Context): List<Map<String, Any?>> {
        val raw = preferences(context).getString(eventsKey, null) ?: return emptyList()
        return try {
            val values = JSONArray(raw)
            buildList {
                for (index in 0 until values.length()) {
                    add(values.getJSONObject(index).toMap())
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun clearEvents(context: Context) {
        preferences(context).edit().remove(eventsKey).apply()
    }

    @Synchronized
    fun shouldEmitCooledEvent(
        context: Context,
        event: BeaconNativeEvent,
        cooldownMillis: Long,
    ): Boolean {
        if (event.type != "regionEntered" || cooldownMillis <= 0L) return true
        // commit() is intentional: the timestamp must be visible before another
        // receiver invocation can evaluate the same region.
        val key = "cooldown_${event.type}_${event.regionIdentifier.orEmpty()}"
        val previous = preferences(context).getLong(key, 0L)
        if (isWithinCooldown(previous, event.timestamp, cooldownMillis)) return false
        preferences(context).edit().putLong(key, event.timestamp).commit()
        return true
    }

    fun lastSeen(context: Context, identifier: String): Long =
        preferences(context).getLong("last_seen_$identifier", 0L)

    fun setLastSeen(context: Context, identifier: String, timestamp: Long) {
        preferences(context).edit()
            .putLong("last_seen_$identifier", timestamp)
            .apply()
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
}

internal fun isWithinCooldown(
    previousTimestamp: Long,
    currentTimestamp: Long,
    cooldownMillis: Long,
): Boolean = previousTimestamp > 0L &&
    currentTimestamp >= previousTimestamp &&
    currentTimestamp - previousTimestamp < cooldownMillis

private fun JSONObject?.toNotificationConfiguration(): NativeNotificationConfiguration {
    return NativeNotificationConfiguration(
        enabled = this?.optBoolean("enabled", false) ?: false,
        channelId = this?.optString("channelId", "super_beacon_events") ?: "super_beacon_events",
        channelName = this?.optString("channelName", "Beacon events") ?: "Beacon events",
        titleTemplate = this?.optString("titleTemplate", "Beacon event") ?: "Beacon event",
        bodyTemplate = this?.optString(
            "bodyTemplate",
            "{eventType}: {regionIdentifier}",
        ) ?: "{eventType}: {regionIdentifier}",
    )
}

private fun JSONObject.optIntOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) getInt(key) else null

private fun JSONObject.toMap(): Map<String, Any?> = buildMap {
    keys().forEach { key ->
        put(key, get(key).toPlatformValue())
    }
}

private fun Any?.toPlatformValue(): Any? = when (this) {
    JSONObject.NULL -> null
    is JSONObject -> toMap()
    is JSONArray -> List(length()) { index -> get(index).toPlatformValue() }
    else -> this
}
