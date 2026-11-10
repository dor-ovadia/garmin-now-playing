package com.dor.nowplaying

/** Playback state as sent to the watch (the number is what travels over Bluetooth). */
enum class PlayState(val code: Int) {
    STOPPED(0),
    PLAYING(1),
    PAUSED(2),
}

/**
 * What is currently playing.
 *
 * [positionSec] is where the player was at [positionAtMs] (phone clock). While playing,
 * the current position is worked out from those two, so nothing has to be sent every second.
 */
data class TrackState(
    val title: String,
    val artist: String,
    val state: PlayState,
    val durationSec: Int = 0,
    val positionSec: Int = 0,
    val positionAtMs: Long = 0,
) {

    /** Where the player should be at [nowMs], assuming it kept playing normally. */
    fun expectedPositionSec(nowMs: Long): Int {
        val moved = if (state == PlayState.PLAYING && positionAtMs > 0) (nowMs - positionAtMs) / 1000 else 0
        val position = positionSec + moved.toInt()
        return if (durationSec > 0) position.coerceIn(0, durationSec) else position.coerceAtLeast(0)
    }

    /**
     * True when [other] describes the same moment of the same song, so there is nothing
     * new to send. A position that drifted by a few seconds is not news; a seek is.
     */
    fun isSameAs(other: TrackState?, nowMs: Long): Boolean =
        other != null &&
            title == other.title && artist == other.artist && state == other.state &&
            durationSec == other.durationSec &&
            kotlin.math.abs(expectedPositionSec(nowMs) - other.expectedPositionSec(nowMs)) <= POSITION_TOLERANCE_SEC

    /**
     * Message for the watch. Short keys and only String/Int values, because those are
     * types the Connect IQ message format supports and they keep the payload small.
     */
    fun toMessage(nowSeconds: Long): Map<String, Any> {
        val message = mutableMapOf<String, Any>(
            "t" to title.take(MAX_TEXT),
            "a" to artist.take(MAX_TEXT),
            "s" to state.code,
            "ts" to nowSeconds.toInt(),
        )
        // Song length and current position, for the progress bar. Skipped when unknown.
        if (durationSec > 0) {
            message["d"] = durationSec
            message["p"] = expectedPositionSec(nowSeconds * 1000)
        }
        return message
    }

    companion object {
        const val MAX_TEXT = 80
        const val POSITION_TOLERANCE_SEC = 3
        val NONE = TrackState("", "", PlayState.STOPPED)

        // Values of android.media.session.PlaybackState, copied here so this logic
        // can be unit-tested without Android.
        private const val ANDROID_STATE_PAUSED = 2
        private const val ANDROID_STATE_PLAYING = 3
        private const val ANDROID_STATE_BUFFERING = 6

        fun mapPlaybackState(androidState: Int?): PlayState = when (androidState) {
            ANDROID_STATE_PLAYING, ANDROID_STATE_BUFFERING -> PlayState.PLAYING
            ANDROID_STATE_PAUSED -> PlayState.PAUSED
            else -> PlayState.STOPPED
        }

        /** Builds a normalised state: a stopped player or a missing title always becomes [NONE]. */
        fun from(
            title: String?,
            artist: String?,
            androidState: Int?,
            durationMs: Long? = null,
            positionMs: Long? = null,
            positionAtMs: Long = 0,
        ): TrackState {
            val state = mapPlaybackState(androidState)
            val cleanTitle = title?.trim().orEmpty()
            if (state == PlayState.STOPPED || cleanTitle.isEmpty()) return NONE
            val duration = durationMs?.takeIf { it > 0 }?.let { (it / 1000).toInt() } ?: 0
            val position = positionMs?.takeIf { it >= 0 }?.let { (it / 1000).toInt() } ?: 0
            return TrackState(cleanTitle, artist?.trim().orEmpty(), state, duration, position, positionAtMs)
        }
    }
}
