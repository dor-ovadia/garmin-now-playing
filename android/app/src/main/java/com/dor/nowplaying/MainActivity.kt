package com.dor.nowplaying

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Diagnostic screen: shows what the app sees and whether it reaches the watch. */
class MainActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var statusView: TextView

    private val refresh = object : Runnable {
        override fun run() {
            statusView.text = buildStatus()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GarminLink.init(this)

        val pad = (16 * resources.displayMetrics.density).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 3, pad, pad)
        }

        statusView = TextView(this).apply {
            textSize = 17f
            setLineSpacing(0f, 1.3f)
        }
        column.addView(statusView)

        column.addView(Button(this).apply {
            text = "פתח הגדרות גישה להתראות"
            setOnClickListener { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }
        })

        column.addView(Button(this).apply {
            text = "שלח הודעת בדיקה לשעון"
            setOnClickListener {
                GarminLink.send(TrackState("שיר בדיקה Test", "Now Playing", PlayState.PLAYING), force = true)
            }
        })

        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresh)
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }

    private fun hasNotificationAccess(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return enabled?.contains(packageName) == true
    }

    private fun buildStatus(): String {
        val track = Status.track
        val access = when {
            !hasNotificationAccess() -> "לא מאושרת"
            Status.listenerConnected -> "מאושרת ופעילה"
            else -> "מאושרת, ממתין להפעלה"
        }
        val playback = when (track.state) {
            PlayState.PLAYING -> "מתנגן"
            PlayState.PAUSED -> "מושהה"
            PlayState.STOPPED -> "לא מתנגן"
        }
        val lastSuccess = if (Status.lastSuccessMillis == 0L) {
            "עדיין לא"
        } else {
            SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(Status.lastSuccessMillis))
        }
        return listOf(
            "גישה להתראות: $access",
            "שיר: ${track.title.ifEmpty { "—" }}",
            "אמן: ${track.artist.ifEmpty { "—" }}",
            "מצב ניגון: $playback",
            "חיבור Garmin: ${Status.garmin}",
            "שליחה אחרונה: ${Status.lastSendResult}",
            "שליחה מוצלחת אחרונה: $lastSuccess",
            "סה\"כ הודעות שנשלחו: ${Status.sentCount}",
        ).joinToString("\n")
    }
}
