package com.micbol.readin

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Reading-habit reminders. The schedule (a JSON list sent by Dart) is stored in
 * SharedPreferences; every alarm is one-shot and re-arms itself, so reminders
 * keep firing with the app closed, and [HabitReceiver] re-arms them after a reboot.
 *
 *  kind 0 = reminder at the chosen time · kind 1 = evening nudge (9 pm)
 *  kind 2 = snoozed reminder (+15 min)
 */
object HabitAlarms {
    const val ACTION_ALARM = "com.micbol.readin.habit.ALARM"
    const val ACTION_SNOOZE = "com.micbol.readin.habit.SNOOZE"
    private const val PREFS = "readin_habits"
    private const val KEY = "alarms"
    private const val CHANNEL = "readin_habits"
    private const val KIND_REMINDER = 0
    private const val KIND_NUDGE = 1
    private const val KIND_SNOOZE = 2
    private const val NUDGE_MINUTES = 21 * 60
    private const val SNOOZE_MS = 15 * 60 * 1000L

    fun save(ctx: Context, json: String) {
        cancelAll(ctx) // cancels what the OLD stored list scheduled
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        scheduleAll(ctx)
    }

    private fun load(ctx: Context): JSONArray {
        return try {
            JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun code(id: String, kind: Int): Int = (id.hashCode() and 0x1FFFFFFF) * 4 + kind

    private fun pending(ctx: Context, id: String, kind: Int, flags: Int): PendingIntent? {
        val i = Intent(ctx, HabitReceiver::class.java)
            .setAction(ACTION_ALARM)
            .putExtra("id", id)
            .putExtra("kind", kind)
        return PendingIntent.getBroadcast(ctx, code(id, kind), i, flags or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun alarmManager(ctx: Context) = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun cancelAll(ctx: Context) {
        val am = alarmManager(ctx)
        val list = load(ctx)
        for (n in 0 until list.length()) {
            val id = list.getJSONObject(n).optString("id")
            for (kind in 0..2) {
                val pi = pending(ctx, id, kind, PendingIntent.FLAG_NO_CREATE)
                if (pi != null) {
                    am.cancel(pi)
                    pi.cancel()
                }
            }
        }
    }

    fun scheduleAll(ctx: Context) {
        val list = load(ctx)
        for (n in 0 until list.length()) {
            val h = list.getJSONObject(n)
            val id = h.optString("id")
            val reminder = h.optInt("reminder", -1)
            if (reminder >= 0) scheduleNext(ctx, h, KIND_REMINDER, reminder)
            if (h.optBoolean("nudge", false)) scheduleNext(ctx, h, KIND_NUDGE, NUDGE_MINUTES)
        }
    }

    private fun daysOf(h: JSONObject): Set<Int> {
        val a = h.optJSONArray("days") ?: return setOf(1, 2, 3, 4, 5)
        val out = HashSet<Int>()
        for (i in 0 until a.length()) out.add(a.optInt(i))
        return out
    }

    private fun isoDay(c: Calendar): Int {
        val dow = c.get(Calendar.DAY_OF_WEEK) // Sunday = 1
        return if (dow == Calendar.SUNDAY) 7 else dow - 1
    }

    private fun nextTrigger(minutes: Int, days: Set<Int>): Long? {
        val now = System.currentTimeMillis()
        for (offset in 0..7) {
            val c = Calendar.getInstance()
            c.add(Calendar.DAY_OF_YEAR, offset)
            c.set(Calendar.HOUR_OF_DAY, minutes / 60)
            c.set(Calendar.MINUTE, minutes % 60)
            c.set(Calendar.SECOND, 0)
            c.set(Calendar.MILLISECOND, 0)
            if (c.timeInMillis > now + 1000 && days.contains(isoDay(c))) return c.timeInMillis
        }
        return null
    }

    private fun scheduleNext(ctx: Context, h: JSONObject, kind: Int, minutes: Int) {
        val at = nextTrigger(minutes, daysOf(h)) ?: return
        val pi = pending(ctx, h.optString("id"), kind, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        alarmManager(ctx).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    }

    private fun find(ctx: Context, id: String): JSONObject? {
        val list = load(ctx)
        for (n in 0 until list.length()) {
            val h = list.getJSONObject(n)
            if (h.optString("id") == id) return h
        }
        return null
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** An alarm fired. */
    fun fire(ctx: Context, id: String, kind: Int) {
        val h = find(ctx, id) ?: return
        // Re-arm the repeating kinds first so a crash below never stops the chain.
        if (kind == KIND_REMINDER) scheduleNext(ctx, h, KIND_REMINDER, h.optInt("reminder", -1))
        if (kind == KIND_NUDGE) scheduleNext(ctx, h, KIND_NUDGE, NUDGE_MINUTES)

        if (h.optString("doneDate") == today()) return // already finished today
        val name = h.optString("name", "Reading")
        val goal = h.optInt("goal", 10)
        val unit = if (h.optString("unit") == "minutes") "min" else "pages"
        val streak = h.optInt("streak", 0)

        val title: String
        val text: String
        if (kind == KIND_NUDGE) {
            title = if (streak > 0) "Don't break your $streak-day streak 🔥" else "Still time to read today 📖"
            text = "$name · $goal $unit to go"
        } else {
            title = "Time to read 📖"
            text = "$name · goal $goal $unit"
        }
        notify(ctx, id, kind, title, text)
    }

    private fun notify(ctx: Context, id: String, kind: Int, title: String, text: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            val ch = NotificationChannel(CHANNEL, "Reading habits", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "Reminders to read and keep your streak"
            nm.createNotificationChannel(ch)
        }
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let {
            PendingIntent.getActivity(
                ctx, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val snooze = PendingIntent.getBroadcast(
            ctx,
            code(id, KIND_SNOOZE) + 1,
            Intent(ctx, HabitReceiver::class.java).setAction(ACTION_SNOOZE).putExtra("id", id),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_agenda)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .addAction(android.R.drawable.ic_lock_idle_alarm, "Snooze 15 min", snooze)
        if (open != null) b.setContentIntent(open)
        try {
            nm.notify(code(id, kind), b.build())
        } catch (e: SecurityException) {
            // notification permission not granted
        }
    }

    /** "Snooze" button: remind again in 15 minutes. */
    fun snooze(ctx: Context, id: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(code(id, KIND_REMINDER))
        nm.cancel(code(id, KIND_NUDGE))
        val pi = pending(ctx, id, KIND_SNOOZE, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        alarmManager(ctx).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + SNOOZE_MS, pi,
        )
    }
}

class HabitReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            HabitAlarms.ACTION_ALARM ->
                HabitAlarms.fire(context, intent.getStringExtra("id") ?: return, intent.getIntExtra("kind", 0))
            HabitAlarms.ACTION_SNOOZE ->
                HabitAlarms.snooze(context, intent.getStringExtra("id") ?: return)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                HabitAlarms.scheduleAll(context)
        }
    }
}
