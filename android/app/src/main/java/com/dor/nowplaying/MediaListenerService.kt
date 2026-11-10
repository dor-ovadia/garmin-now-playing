package com.dor.nowplaying

import android.content.ComponentName
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Follows the YouTube Music media session. Holding notification access is what allows
 * an app to read other apps' media sessions, so this is a NotificationListenerService
 * even though the track details come from the media session rather than the notification.
 * Everything is event-driven: nothing is polled.
 */
class MediaListenerService : NotificationListenerService() {

    private val handler = Handler(Looper.getMainLooper())
    private var sessionManager: MediaSessionManager? = null
    private var controller: MediaController? = null

    private val sessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers -> attach(controllers) }

    private val controllerCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = schedulePublish()
        override fun onPlaybackStateChanged(state: PlaybackState?) = schedulePublish()
        override fun onSessionDestroyed() {
            detach()
            schedulePublish()
        }
    }

    /** Title and playback state arrive as separate events; wait briefly and send them once. */
    private val publish = Runnable {
        val c = controller
        val state = if (c == null) {
            TrackState.NONE
        } else {
            val metadata = c.metadata
            val playback = c.playbackState
            // The player reports a position together with the moment it was measured;
            // bring it forward to "now" so the watch gets an up-to-date value.
            val positionNow = playback?.let {
                val sinceUpdate = SystemClock.elapsedRealtime() - it.lastPositionUpdateTime
                val moving = it.state == PlaybackState.STATE_PLAYING && it.lastPositionUpdateTime > 0
                it.position + if (moving) (sinceUpdate * it.playbackSpeed).toLong() else 0L
            }
            TrackState.from(
                metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
                metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
                    ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST),
                playback?.state,
                metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION),
                positionNow,
                System.currentTimeMillis(),
            )
        }
        Status.track = state
        GarminLink.send(state)
    }

    override fun onListenerConnected() {
        Status.listenerConnected = true
        GarminLink.init(this)
        val manager = getSystemService(MediaSessionManager::class.java)
        sessionManager = manager
        val self = ComponentName(this, MediaListenerService::class.java)
        try {
            manager.addOnActiveSessionsChangedListener(sessionsListener, self)
            attach(manager.getActiveSessions(self))
        } catch (e: SecurityException) {
            Status.listenerConnected = false
        }
    }

    override fun onListenerDisconnected() {
        Status.listenerConnected = false
        sessionManager?.removeOnActiveSessionsChangedListener(sessionsListener)
        detach()
    }

    /** Backup trigger: when the YouTube Music notification disappears, re-check its session. */
    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn?.packageName != YOUTUBE_MUSIC) return
        val manager = sessionManager ?: return
        try {
            attach(manager.getActiveSessions(ComponentName(this, MediaListenerService::class.java)))
        } catch (e: SecurityException) {
            // Access was revoked; onListenerDisconnected handles the cleanup.
        }
    }

    private fun attach(controllers: List<MediaController>?) {
        val youtube = controllers?.firstOrNull { it.packageName == YOUTUBE_MUSIC }
        if (youtube?.sessionToken != controller?.sessionToken) {
            detach()
            controller = youtube
            youtube?.registerCallback(controllerCallback, handler)
        }
        schedulePublish()
    }

    private fun detach() {
        controller?.unregisterCallback(controllerCallback)
        controller = null
    }

    private fun schedulePublish() {
        handler.removeCallbacks(publish)
        handler.postDelayed(publish, 400)
    }

    private companion object {
        const val YOUTUBE_MUSIC = "com.google.android.apps.youtube.music"
    }
}
