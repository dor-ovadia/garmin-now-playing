package com.dor.nowplaying

import org.junit.Assert.assertEquals
import org.junit.Test

class TrackStateTest {

    @Test
    fun mapsAndroidPlaybackStates() {
        assertEquals(PlayState.PLAYING, TrackState.mapPlaybackState(3))
        assertEquals(PlayState.PLAYING, TrackState.mapPlaybackState(6))
        assertEquals(PlayState.PAUSED, TrackState.mapPlaybackState(2))
        assertEquals(PlayState.STOPPED, TrackState.mapPlaybackState(1))
        assertEquals(PlayState.STOPPED, TrackState.mapPlaybackState(null))
    }

    @Test
    fun stoppedOrUntitledBecomesNone() {
        assertEquals(TrackState.NONE, TrackState.from("Song", "Artist", 1))
        assertEquals(TrackState.NONE, TrackState.from("  ", "Artist", 3))
        assertEquals(TrackState.NONE, TrackState.from(null, null, 3))
    }

    @Test
    fun trimsAndKeepsHebrew() {
        assertEquals(
            TrackState("שיר", "אמן", PlayState.PAUSED),
            TrackState.from(" שיר ", " אמן ", 2),
        )
    }

    @Test
    fun messageUsesSupportedTypesAndLimitsLength() {
        val message = TrackState("x".repeat(200), "a", PlayState.PLAYING).toMessage(1794300000L)
        assertEquals(TrackState.MAX_TEXT, (message["t"] as String).length)
        assertEquals(1, message["s"])
        assertEquals(1794300000, message["ts"])
    }
}
