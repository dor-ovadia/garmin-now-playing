package com.dor.nowplaying

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice

/**
 * Sends the current track to the watch face through Garmin Connect Mobile,
 * using the official Connect IQ Mobile SDK.
 */
object GarminLink {

    /** Must match the application id in garmin/manifest.xml. */
    private const val WATCH_APP_ID = "0fee28f3f11c4e23bf96253f2c3d7361"
    private const val MAX_RETRIES = 3

    private val handler = Handler(Looper.getMainLooper())
    private val watchApp = IQApp(WATCH_APP_ID)

    private var connectIQ: ConnectIQ? = null
    private var ready = false

    /** Latest state that still has to reach the watch (null = nothing waiting). */
    private var pending: TrackState? = null
    /** Last state the watch confirmed, used to avoid duplicate transmissions. */
    private var lastDelivered: TrackState? = null
    private var attempt = 0

    fun init(context: Context) {
        if (connectIQ != null) return
        val appContext = context.applicationContext
        val ciq = ConnectIQ.getInstance(appContext, ConnectIQ.IQConnectType.WIRELESS)
        connectIQ = ciq
        Status.garmin = "מאתחל…"
        ciq.initialize(appContext, false, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                ready = true
                Status.garmin = "מחובר ל-Garmin Connect"
                registerDevices()
                flush()
            }

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus?) {
                ready = false
                Status.garmin = "שגיאת אתחול: $status"
            }

            override fun onSdkShutDown() {
                ready = false
                Status.garmin = "החיבור נסגר"
            }
        })
    }

    /** Queues [state] for the watch. Identical states are skipped unless [force] is set. */
    fun send(state: TrackState, force: Boolean = false) {
        if (!force && pending == null && state == lastDelivered) return
        pending = state
        attempt = 0
        flush()
    }

    private fun registerDevices() {
        val ciq = connectIQ ?: return
        try {
            for (device in ciq.knownDevices.orEmpty()) {
                ciq.registerForDeviceEvents(device) { d, status ->
                    Status.garmin = "${d?.friendlyName ?: "שעון"}: $status"
                    // The watch came back in range: deliver whatever is waiting.
                    if (status == IQDevice.IQDeviceStatus.CONNECTED) flush()
                }
            }
        } catch (e: Exception) {
            Status.garmin = "שגיאה באיתור השעון: ${e.message}"
        }
    }

    private fun flush() {
        val ciq = connectIQ
        val state = pending
        if (!ready || ciq == null || state == null) return

        val device = try {
            ciq.connectedDevices.orEmpty().firstOrNull()
        } catch (e: Exception) {
            null
        }
        if (device == null) {
            // Stays pending; registerDevices() calls flush() again when the watch reconnects.
            Status.lastSendResult = "אין שעון מחובר כרגע"
            return
        }

        try {
            ciq.sendMessage(device, watchApp, state.toMessage(System.currentTimeMillis() / 1000)) { _, _, status ->
                if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                    lastDelivered = state
                    if (pending == state) pending = null
                    Status.sentCount++
                    Status.lastSuccessMillis = System.currentTimeMillis()
                    Status.lastSendResult = "נשלח בהצלחה"
                } else {
                    Status.lastSendResult = "השליחה נכשלה: $status"
                    retryLater()
                }
            }
        } catch (e: Exception) {
            Status.lastSendResult = "שגיאת שליחה: ${e.message}"
            retryLater()
        }
    }

    private fun retryLater() {
        if (attempt >= MAX_RETRIES) return
        attempt++
        handler.postDelayed({ flush() }, 2000L * attempt)
    }
}
