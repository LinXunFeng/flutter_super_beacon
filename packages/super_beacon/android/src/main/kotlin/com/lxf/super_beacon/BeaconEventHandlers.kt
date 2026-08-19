package com.lxf.super_beacon

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Native event schema shared with Flutter and host application callbacks.
 *
 * Optional values remain null when the producing Android subsystem cannot
 * supply them. In particular, location fields are best-effort snapshots rather
 * than a fresh location guarantee.
 */
public data class BeaconNativeEvent(
    val type: String,
    val timestamp: Long = System.currentTimeMillis(),
    val source: String = "system",
    val state: String = "unknown",
    val regionIdentifier: String? = null,
    val reading: Map<String, Any?>? = null,
    val manufacturerData: Map<String, Any?>? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val accuracy: Double? = null,
    val locationTimestamp: Long? = null,
    val message: String? = null,
    val details: Map<String, Any?> = emptyMap(),
) {
    public fun toMap(): Map<String, Any?> = mapOf(
        "type" to type,
        "timestamp" to timestamp,
        "source" to source,
        "state" to state,
        "regionIdentifier" to regionIdentifier,
        "reading" to reading,
        "manufacturerData" to manufacturerData,
        "latitude" to latitude,
        "longitude" to longitude,
        "accuracy" to accuracy,
        "locationTimestamp" to locationTimestamp,
        "message" to message,
        "details" to details,
    )
}

/** Receives native events without requiring a running Flutter UI. */
public fun interface BeaconEventHandler {
    /**
     * Handles an event on the thread that produced it.
     *
     * Implementations should enqueue long-running work instead of blocking the
     * scan receiver or platform callback.
     */
    public fun onBeaconEvent(context: Context, event: BeaconNativeEvent)
}

/** Process-local registration point for the host application's event handler. */
public object BeaconEventHandlers {
    /**
     * Current host handler, or null when the host does not consume native events.
     *
     * Register this whenever the Android application process starts; the value
     * is not persisted across process death.
     */
    @Volatile
    @JvmStatic
    public var handler: BeaconEventHandler? = null
}

internal object BeaconEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var sink: EventChannel.EventSink? = null

    fun emit(context: Context, event: BeaconNativeEvent) {
        val configuration = BeaconStorage.configuration(context)
        if (!BeaconStorage.shouldEmitCooledEvent(
                context,
                event,
                configuration?.eventCooldownMillis ?: 10_000L,
            )
        ) {
            return
        }
        BeaconStorage.appendEvent(context, event)
        if (event.type == "regionEntered" && configuration?.notifications?.enabled == true) {
            BeaconNotificationManager.show(context, event, configuration.notifications)
        }
        try {
            BeaconEventHandlers.handler?.onBeaconEvent(context, event)
        } catch (_: Exception) {
            // Host callback failures must not prevent persistence or Flutter
            // delivery of the native event.
        }
        // EventChannel sinks are owned by Flutter's main thread.
        mainHandler.post { sink?.success(event.toMap()) }
    }
}
