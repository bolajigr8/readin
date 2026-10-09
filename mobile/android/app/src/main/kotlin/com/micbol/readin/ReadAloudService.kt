package com.micbol.readin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel

/** Lets the Dart side receive notification button presses ("play", "pause", …). */
object ReadAloudBridge {
    var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    fun emit(action: String) {
        main.post { sink?.success(action) }
    }
}

/**
 * Foreground service shown while ReadIn reads aloud: keeps the speech alive when
 * the screen is off and puts Previous / Play-Pause / Next / Stop buttons in the
 * notification (also visible on the lock screen).
 */
class ReadAloudService : Service() {
    companion object {
        const val ACTION_SHOW = "com.micbol.readin.readaloud.SHOW"
        const val ACTION_PLAY = "com.micbol.readin.readaloud.PLAY"
        const val ACTION_PAUSE = "com.micbol.readin.readaloud.PAUSE"
        const val ACTION_NEXT = "com.micbol.readin.readaloud.NEXT"
        const val ACTION_PREV = "com.micbol.readin.readaloud.PREV"
        const val ACTION_STOP = "com.micbol.readin.readaloud.STOP"
        private const val CHANNEL = "readin_readaloud"
        private const val NOTIFICATION_ID = 4711
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> show(
                intent.getStringExtra("title") ?: "ReadIn",
                intent.getStringExtra("text") ?: "",
                intent.getBooleanExtra("playing", false),
            )
            ACTION_PLAY -> ReadAloudBridge.emit("play")
            ACTION_PAUSE -> ReadAloudBridge.emit("pause")
            ACTION_NEXT -> ReadAloudBridge.emit("next")
            ACTION_PREV -> ReadAloudBridge.emit("prev")
            ACTION_STOP -> {
                ReadAloudBridge.emit("stop")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL) == null) {
                val ch = NotificationChannel(CHANNEL, "Read aloud", NotificationManager.IMPORTANCE_LOW)
                ch.description = "Controls while ReadIn reads a book aloud"
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun action(name: String, code: Int): PendingIntent {
        val i = Intent(this, ReadAloudService::class.java).setAction(name)
        return PendingIntent.getService(
            this, code, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun show(title: String, text: String, playing: Boolean) {
        ensureChannel()
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            PendingIntent.getActivity(
                this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(title)
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setOngoing(playing)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .addAction(android.R.drawable.ic_media_previous, "Previous", action(ACTION_PREV, 1))
            .addAction(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "Pause" else "Play",
                action(if (playing) ACTION_PAUSE else ACTION_PLAY, 2),
            )
            .addAction(android.R.drawable.ic_media_next, "Next", action(ACTION_NEXT, 3))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", action(ACTION_STOP, 4))
        if (open != null) builder.setContentIntent(open)
        val n: Notification = builder.build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }
}
