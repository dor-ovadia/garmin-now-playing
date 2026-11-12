package com.dor.nowplaying

/** In-memory status shown on the diagnostic screen. */
object Status {
    @Volatile var listenerConnected = false
    @Volatile var track: TrackState = TrackState.NONE
    @Volatile var garmin = "לא אותחל"
    @Volatile var lastSendResult = "—"
    @Volatile var lastSuccessMillis = 0L
    @Volatile var sentCount = 0
    @Volatile var designResult = ""
}
