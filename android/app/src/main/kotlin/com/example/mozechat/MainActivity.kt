package com.example.mozechat

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val PROXIMITY_CHANNEL = "com.mozelabs.mozechat/proximity"
    private var powerManager: PowerManager? = null
    private var proximityWakeLock: PowerManager.WakeLock? = null
    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var isNear = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROXIMITY_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableProximity" -> {
                    enableProximity()
                    result.success(true)
                }
                "disableProximity" -> {
                    disableProximity()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableProximity() {
        try {
            // PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK = 32 (0x00000020)
            val fieldProximity = 32
            if (proximityWakeLock == null && powerManager != null) {
                if (powerManager?.isWakeLockLevelSupported(fieldProximity) == true) {
                    proximityWakeLock = powerManager?.newWakeLock(fieldProximity, "mozechat:proximity_screen_off")
                }
            }
            if (proximityWakeLock?.isHeld == false) {
                proximityWakeLock?.acquire()
            }

            proximitySensor?.let { sensor ->
                sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun disableProximity() {
        try {
            if (proximityWakeLock?.isHeld == true) {
                proximityWakeLock?.release()
            }
            proximityWakeLock = null
            sensorManager?.unregisterListener(this)
            if (isNear) {
                isNear = false
                runOnUiThread {
                    methodChannel?.invokeMethod("onProximityChanged", false)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_PROXIMITY) {
            val distance = event.values[0]
            val maxRange = proximitySensor?.maximumRange ?: 5f
            val near = distance < 5f && distance < maxRange
            if (near != isNear) {
                isNear = near
                runOnUiThread {
                    methodChannel?.invokeMethod("onProximityChanged", isNear)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        disableProximity()
        super.onDestroy()
    }
}
