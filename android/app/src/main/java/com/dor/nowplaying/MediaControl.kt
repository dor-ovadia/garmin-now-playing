package com.dor.nowplaying

import android.content.Context
import android.media.AudioManager
import android.os.SystemClock
import android.view.KeyEvent

/** Carries out the commands that arrive from the remote control app on the watch. */
object MediaControl {

    val COMMANDS = setOf("prev", "next", "toggle", "vol+", "vol-")

    /**
     * Playback commands are sent as ordinary media key presses through Android, the same
     * route a headset button takes, rather than by calling the player's session directly.
     * Android treats a media key as a user action and lets the player take the speaker
     * again; a direct call from another app in the background can leave it playing silently.
     */
    fun handle(context: Context, command: String) {
        if (command !in COMMANDS) return
        val audio = context.getSystemService(AudioManager::class.java)
        when (command) {
            "vol+" -> audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0)
            "vol-" -> audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0)
            else -> sendMediaKey(audio, keyFor(command))
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
