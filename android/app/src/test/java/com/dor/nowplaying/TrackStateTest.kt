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
        // No duration known: no progress fields.
        assertEquals(false, message.containsKey("d"))
    }

    @Test
    fun messageCarriesProgressBroughtForwardToSendTime() {
        // 200 s song, 50 s in at phone time 1,000,000 ms; sent 10 s later.
        val state = TrackState.from("Song", "Artist", 3, 200_000L, 50_000L, 1_000_000L)
        val message = state.toMessage(1_010L)
        assertEquals(200, message["d"])
        assertEquals(60, message["p"])
    }

    @Test
    fun pausedPositionDoesNotMove() {
        val state = TrackState.from("Song", "Artist", 2, 200_000L, 50_000L, 1_000_000L)
        assertEquals(50, state.expectedPositionSec(5_000_000L))
    }

    @Test
    fun driftIsNotNewsButSeekIs() {
        val sent = TrackState.from("Song", "Artist", 3, 200_000L, 50_000L, 1_000_000L)
        // 20 s later the player reports 71 s: one second of drift.
        val drifted = TrackState.from("Song", "Artist", 3, 200_000L, 71_000L, 1_020_000L)
        // 20 s later the player reports 150 s: the user jumped ahead.
        val seeked = TrackState.from("Song", "Artist", 3, 200_000L, 150_000L, 1_020_000L)
        assertEquals(true, drifted.isSameAs(sent, 1_020_000L))
        assertEquals(false, seeked.isSameAs(sent, 1_020_000L))
        assertEquals(false, sent.isSameAs(null, 1_020_000L))
    }
}
