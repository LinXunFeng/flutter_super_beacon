package com.lxf.super_beacon_example

import android.app.Application
import android.util.Log
import com.lxf.super_beacon.BeaconEventHandler
import com.lxf.super_beacon.BeaconEventHandlers

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BeaconEventHandlers.handler = BeaconEventHandler { _, event ->
            Log.d("SuperBeaconExample", event.toString())
            // The host can enqueue its own API request here.
        }
    }
}
