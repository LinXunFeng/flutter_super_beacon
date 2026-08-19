package com.lxf.super_beacon

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal object BeaconLocationProvider {
    fun recent(context: Context): Location? {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) return null
        return try {
            val manager = context.getSystemService(LocationManager::class.java)
                ?: return null
            manager.getProviders(true)
                .mapNotNull(manager::getLastKnownLocation)
                .maxByOrNull(Location::getTime)
        } catch (_: SecurityException) {
            null
        }
    }
}

internal object BeaconNotificationManager {
    fun show(
        context: Context,
        event: BeaconNativeEvent,
        configuration: NativeNotificationConfiguration,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager?.createNotificationChannel(
                NotificationChannel(
                    configuration.channelId,
                    configuration.channelName,
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launchIntent?.let { intent ->
            PendingIntent.getActivity(
                context,
                0,
                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val icon = context.applicationInfo.icon.takeIf { it != 0 }
            ?: android.R.drawable.ic_dialog_info
        val body = render(configuration.bodyTemplate, event)
        val notification = NotificationCompat.Builder(context, configuration.channelId)
            .setSmallIcon(icon)
            .setContentTitle(render(configuration.titleTemplate, event))
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        NotificationManagerCompat.from(context).notify(
            (event.regionIdentifier ?: event.type).hashCode(),
            notification,
        )
    }

    private fun render(template: String, event: BeaconNativeEvent): String {
        val date = SimpleDateFormat("yyyy/MM/dd", Locale.getDefault())
            .format(Date(event.timestamp))
        return template
            .replace("{eventType}", event.type)
            .replace("{regionIdentifier}", event.regionIdentifier.orEmpty())
            .replace("{timestamp}", event.timestamp.toString())
            .replace("{date}", date)
            .replace("{latitude}", event.latitude?.toString().orEmpty())
            .replace("{longitude}", event.longitude?.toString().orEmpty())
    }
}
