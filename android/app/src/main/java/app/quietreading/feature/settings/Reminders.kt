package app.quietreading.feature.settings

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.quietreading.MainActivity
import app.quietreading.QuietReadingApplication
import app.quietreading.R
import app.quietreading.data.AppEnvironment
import app.quietreading.data.Keys
import app.quietreading.data.ReadingStatus
import app.quietreading.data.current
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

/** Default reminder time: 20:30 (minutes after midnight). */
const val DefaultReminderMinutes = 20 * 60 + 30

/** Notification permission and channels shared by the reminder and the monthly recap. */
object Notifications {
    const val CHANNEL_REMINDER = "reminder"
    const val CHANNEL_RECAP = "recap"

    fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    /** Settings › Apps › Quiet Reading › Notifications. */
    fun openSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun ensureChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL_REMINDER, "Daily reminder", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "One gentle reminder a day, at the time you choose"
        })
        nm.createNotificationChannel(NotificationChannel(CHANNEL_RECAP, "Monthly recap", NotificationManager.IMPORTANCE_LOW).apply {
            description = "On the 1st, a short look back at your month"
        })
    }

    /** Opens the app with a link (the app routes it: quietreading://update-current, quietreading://year…). */
    fun openApp(context: Context, link: String, request: Int): PendingIntent =
        PendingIntent.getActivity(
            context, request,
            Intent(context, MainActivity::class.java).setData(Uri.parse(link)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    fun post(context: Context, id: Int, channel: String, title: String, body: String, link: String) {
        if (!allowed(context)) return
        ensureChannels(context)
        val n = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_qs_book)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(openApp(context, link, id))
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id, n) }
    }
}

/** "Still with Anne of Green Gables?" – one gentle reminder a day, never more. */
object ReminderScheduler {
    private const val REQUEST = 101
    const val NOTIFICATION_ID = 1

    private fun intent(context: Context) = PendingIntent.getBroadcast(
        context, REQUEST, Intent(context, ReminderReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** Daily at [minutes] after midnight (inexact, so the phone can batch it – calm, battery-friendly). */
    fun schedule(context: Context, minutes: Int) {
        val now = Calendar.getInstance()
        val first = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60); set(Calendar.MINUTE, minutes % 60); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (!after(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        val am = context.getSystemService(AlarmManager::class.java)
        am.setInexactRepeating(AlarmManager.RTC_WAKEUP, first.timeInMillis, AlarmManager.INTERVAL_DAY, intent(context))
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(intent(context))
    }

    /** The text always names the current book (most recently updated) and its latest page. */
    suspend fun post(context: Context, env: AppEnvironment) {
        if (!env.prefs.get(Keys.reminderOn, false)) return
        val book = env.library.books.first().current
        val (title, body, link) = if (book != null) Triple(
            "Still with ${book.title}?",
            if (book.currentPage > 0) "You were on page ${book.currentPage}. Tap to update." else "Tap to add your page.",
            "quietreading://update-current",
        ) else Triple("A quiet moment to read?", "Your shelf is here when you are.", "quietreading://add")
        Notifications.post(context, NOTIFICATION_ID, Notifications.CHANNEL_REMINDER, title, body, link)
    }
}

/**
 * Flow 8 › Monthly recap: on the 1st at 9:00, a short look back at the month that just ended.
 * Off by default (calm, no pushy notifications).
 */
object RecapScheduler {
    private const val REQUEST = 102
    const val NOTIFICATION_ID = 2

    private fun intent(context: Context) = PendingIntent.getBroadcast(
        context, REQUEST, Intent(context, RecapReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun schedule(context: Context) {
        val next = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_MONTH, 1); set(Calendar.HOUR_OF_DAY, 9); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.MONTH, 1)
        }
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent(context))
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(intent(context))
    }

    /** "Your November in books is ready · 2 books, 640 pages, and one 4.5-star favourite." */
    suspend fun post(context: Context, env: AppEnvironment) {
        if (!env.prefs.get(Keys.monthlyRecap, false)) return
        val books = env.library.books.first()
        val month = Calendar.getInstance().apply { add(Calendar.MONTH, -1) }
        fun inMonth(t: Long) = Calendar.getInstance().apply { timeInMillis = t }.let {
            it.get(Calendar.YEAR) == month.get(Calendar.YEAR) && it.get(Calendar.MONTH) == month.get(Calendar.MONTH)
        }
        val finished = books.filter { it.status == ReadingStatus.Read && it.dateFinished?.let(::inMonth) == true }
        val pagesRead = books.flatMap { it.sessions }.filter { inMonth(it.date) }.sumOf { maxOf(0, it.toPage - it.fromPage) }
        val pages = maxOf(pagesRead, finished.sumOf { it.pageCount ?: 0 })
        if (finished.isEmpty() && pages == 0) return
        val parts = mutableListOf<String>()
        if (finished.isNotEmpty()) parts += if (finished.size == 1) "1 book" else "${finished.size} books"
        if (pages > 0) parts += "${NumberFormat.getIntegerInstance().format(pages)} pages"
        val fav = finished.mapNotNull { it.stars ?: it.entity.rating?.toDouble() }.maxOrNull()
        if (fav != null && fav >= 4) parts += "one ${if (fav % 1.0 == 0.0) fav.toInt().toString() else fav.toString()}-star favourite"
        val body = when (parts.size) {
            1 -> parts[0]
            2 -> "${parts[0]} and ${parts[1]}"
            else -> parts.dropLast(1).joinToString(", ") + ", and " + parts.last()
        } + "."
        val name = month.getDisplayName(Calendar.MONTH, Calendar.LONG, Locale.getDefault())
        Notifications.post(context, NOTIFICATION_ID, Notifications.CHANNEL_RECAP, "Your $name in books is ready", body, "quietreading://year")
    }
}

private fun BroadcastReceiver.runAsync(context: Context, block: suspend (AppEnvironment) -> Unit) {
    val pending = goAsync()
    val env = (context.applicationContext as QuietReadingApplication).env
    CoroutineScope(Dispatchers.IO).launch {
        try { block(env) } finally { pending.finish() }
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = runAsync(context) { ReminderScheduler.post(context, it) }
}

class RecapReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = runAsync(context) { env ->
        RecapScheduler.post(context, env)
        if (env.prefs.get(Keys.monthlyRecap, false)) RecapScheduler.schedule(context)
    }
}

/** Alarms are cleared when the phone restarts or the app updates; set them again. */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = runAsync(context) { env ->
        if (env.prefs.get(Keys.reminderOn, false)) ReminderScheduler.schedule(context, env.prefs.get(Keys.reminderMinutes, DefaultReminderMinutes))
        if (env.prefs.get(Keys.monthlyRecap, false)) RecapScheduler.schedule(context)
    }
}
