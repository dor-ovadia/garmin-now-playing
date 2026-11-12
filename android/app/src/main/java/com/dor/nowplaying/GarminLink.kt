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
    /** Must match the application id in garmin-remote/manifest.xml. */
    private const val REMOTE_APP_ID = "4c20e4ef989e48b1b09c9a8486137440"
    private const val MAX_RETRIES = 3
    /** After its last message, the remote keeps receiving song updates for this long. */
    private const val REMOTE_ACTIVE_MS = 3 * 60 * 1000L

    private val handler = Handler(Looper.getMainLooper())
    private val watchApp = IQApp(WATCH_APP_ID)
    private val remoteApp = IQApp(REMOTE_APP_ID)
    private var remoteActiveUntil = 0L

    private var appContext: Context? = null
    private var connectIQ: ConnectIQ? = null
    private var ready = false

    /** Latest state that still has to reach the watch (null = nothing waiting). */
    private var pending: TrackState? = null
    /** Last state the watch confirmed, used to avoid duplicate transmissions. */
    private var lastDelivered: TrackState? = null
    private var attempt = 0
    /** Newest watch face design that still has to reach the watch. */
    private var pendingConfig: Map<String, Any>? = null
    private var configAttempt = 0
    private var initAttempt = 0

    /** Safe to call repeatedly; only the first call (or one after a failure) connects. */
    fun init(context: Context) {
        appContext = context.applicationContext
        if (connectIQ == null) connect()
    }

    private fun connect() {
        val context = appContext ?: return
        val ciq = ConnectIQ.getInstance(context, ConnectIQ.IQConnectType.WIRELESS)
        connectIQ = ciq
        Status.garmin = "מאתחל…"
        ciq.initialize(context, false, object : ConnectIQ.ConnectIQListener {
            override fun onSdkReady() {
                ready = true
                initAttempt = 0
                Status.garmin = "מחובר ל-Garmin Connect"
                registerDevices()
                flush()
            }

            override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus?) {
                ready = false
                connectIQ = null
                Status.garmin = "שגיאת אתחול: $status"
                // Typical after a phone restart, before Garmin Connect is up: try again
                // a few times, then wait for the next song change (see send()).
                if (initAttempt < MAX_RETRIES) {
                    initAttempt++
                    handler.postDelayed({ if (connectIQ == null) connect() }, 10_000L * initAttempt)
                }
            }

            override fun onSdkShutDown() {
                ready = false
                connectIQ = null
                Status.garmin = "החיבור נסגר"
            }
        })
    }

    /** Queues [state] for the watch. Identical states are skipped unless [force] is set. */
    fun send(state: TrackState, force: Boolean = false) {
        if (!force && pending == null && state.isSameAs(lastDelivered, System.currentTimeMillis())) return
        pending = state
        attempt = 0
        // While the remote is in use it shows the song too.
        if (System.currentTimeMillis() < remoteActiveUntil) {
            sendToRemote(state.toMessage(System.currentTimeMillis() / 1000))
        }
        if (connectIQ == null) {
            // The link to Garmin Connect was lost earlier: reconnect, then onSdkReady() sends.
            initAttempt = 0
            connect()
        } else {
            flush()
        }
    }

    private fun registerDevices() {
        val ciq = connectIQ ?: return
        try {
            for (device in ciq.knownDevices.orEmpty()) {
                // Commands from the remote control app on the watch.
                ciq.registerForAppEvents(device, remoteApp) { _, _, message, _ ->
                    onRemoteCommand(message?.firstOrNull() as? String ?: return@registerForAppEvents)
                }
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

    private fun onRemoteCommand(command: String) {
        val context = appContext ?: return
        remoteActiveUntil = System.currentTimeMillis() + REMOTE_ACTIVE_MS
        if (command == "hello") {
            // The remote was just opened: give it the colours and the current song.
            sendToRemote(DesignConfig.load(context).toMessage())
            sendToRemote(Status.track.toMessage(System.currentTimeMillis() / 1000))
        } else {
            MediaControl.handle(context, command)
        }
    }

    /** Best effort, no retry: the remote is on screen and the next change sends again. */
    private fun sendToRemote(payload: Map<String, Any>) {
        val ciq = connectIQ ?: return
        if (!ready) return
        try {
            val device = ciq.connectedDevices.orEmpty().firstOrNull() ?: return
            ciq.sendMessage(device, remoteApp, payload) { _, _, _ -> }
        } catch (e: Exception) {
            // Ignored on purpose; see above.
        }
    }

    /** Queues the watch face design. Only the newest design is kept if several are waiting. */
    fun sendConfig(config: Map<String, Any>) {
        pendingConfig = config
        configAttempt = 0
        if (connectIQ == null) {
            initAttempt = 0
            connect()
        } else {
            flushConfig()
        }
    }

    private fun flush() {
        flushConfig()
        flushTrack()
    }

    private fun flushConfig() {
        val ciq = connectIQ
        val config = pendingConfig
        if (!ready || ciq == null || config == null) return
        val device = try {
            ciq.connectedDevices.orEmpty().firstOrNull()
        } catch (e: Exception) {
            null
        }
        if (device == null) {
            Status.designResult = "אין שעון מחובר כרגע; העיצוב יישלח כשיתחבר"
            return
        }
        try {
            ciq.sendMessage(device, watchApp, config) { _, _, status ->
                if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                    if (pendingConfig === config) pendingConfig = null
                    Status.designResult = "העיצוב נשלח לשעון"
                } else {
                    Status.designResult = "שליחת העיצוב נכשלה: $status"
                    retryConfigLater()
                }
            }
        } catch (e: Exception) {
            Status.designResult = "שגיאה בשליחת העיצוב: ${e.message}"
            retryConfigLater()
        }
    }

    private fun retryConfigLater() {
        if (configAttempt >= MAX_RETRIES) return
        configAttempt++
        handler.postDelayed({ flushConfig() }, 2000L * configAttempt)
    }

    private fun flushTrack() {
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
