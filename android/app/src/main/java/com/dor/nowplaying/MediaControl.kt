package com.dor.nowplaying

import android.content.Context
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.PlaybackState
import android.os.SystemClock
import android.view.KeyEvent

/** Carries out the commands that arrive from the remote control app on the watch. */
object MediaControl {

    /** The YouTube Music session, kept up to date by [MediaListenerService]; null when it is closed. */
    @Volatile var controller: MediaController? = null

    val COMMANDS = setOf("prev", "next", "toggle", "vol+", "vol-")

    fun handle(context: Context, command: String) {
        if (command !in COMMANDS) return
        val audio = context.getSystemService(AudioManager::class.java)
        when (command) {
            "vol+" -> audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0)
            "vol-" -> audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0)
            else -> {
                val controls = controller?.transportControls
                if (controls == null) {
                    // YouTube Music has no open session: send an ordinary media key instead,
                    // which Android gives to the last player that was used.
                    sendMediaKey(audio, keyFor(command))
                } else when (command) {
                    "prev" -> controls.skipToPrevious()
                    "next" -> controls.skipToNext()
                    else ->
                        if (controller?.playbackState?.state == PlaybackState.STATE_PLAYING) controls.pause()
                        else controls.play()
                }
            }
        }
    }

    fun keyFor(command: String): Int = when (command) {
        "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
        "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
        else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
    }

    private fun sendMediaKey(audio: AudioManager, key: Int) {
        val now = SystemClock.uptimeMillis()
        audio.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, key, 0))
        audio.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, key, 0))
    }
}
