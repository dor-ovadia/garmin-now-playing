package com.dor.nowplaying

/** Playback state as sent to the watch (the number is what travels over Bluetooth). */
enum class PlayState(val code: Int) {
    STOPPED(0),
    PLAYING(1),
    PAUSED(2),
}

/** What is currently playing. Two equal values mean "nothing new to send". */
data class TrackState(val title: String, val artist: String, val state: PlayState) {

    /**
     * Message for the watch. Short keys and only String/Int values, because those are
     * types the Connect IQ message format supports and they keep the payload small.
     */
    fun toMessage(nowSeconds: Long): Map<String, Any> = mapOf(
        "t" to title.take(MAX_TEXT),
        "a" to artist.take(MAX_TEXT),
        "s" to state.code,
        "ts" to nowSeconds.toInt(),
    )

    companion object {
        const val MAX_TEXT = 80
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
        fun from(title: String?, artist: String?, androidState: Int?): TrackState {
            val state = mapPlaybackState(androidState)
            val cleanTitle = title?.trim().orEmpty()
            if (state == PlayState.STOPPED || cleanTitle.isEmpty()) return NONE
            return TrackState(cleanTitle, artist?.trim().orEmpty(), state)
        }
    }
}
