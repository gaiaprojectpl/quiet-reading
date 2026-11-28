package app.quietreading.feature.settings

import android.Manifest
import android.app.Activity
import android.os.Build
import android.text.format.DateFormat
import android.text.format.DateUtils
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import app.quietreading.R
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Keys
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.data.rememberPref
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType
import app.quietreading.designsystem.ThemeId
import app.quietreading.designsystem.components.LocalNotifier
import app.quietreading.designsystem.components.QsIcon
import app.quietreading.designsystem.components.QsListRow
import app.quietreading.designsystem.components.TabScreen
import app.quietreading.designsystem.components.pressable
import app.quietreading.designsystem.medium
import kotlinx.coroutines.launch
import java.util.Calendar

object SettingsRoutes {
    const val PROFILE = "settings/profile"
    const val THEME = "settings/theme"
    const val SOURCES = "settings/sources"
    const val ABOUT = "settings/about"
}

/** Flow 4 · Settings & profile. */
fun NavGraphBuilder.settingsGraph(nav: AppNav) {
    composable(Routes.SETTINGS) { SettingsScreen(nav) }
    composable(SettingsRoutes.PROFILE) { ProfileEditScreen(onClose = nav::back) }
    composable(SettingsRoutes.THEME) { ThemePickerScreen(onBack = nav::back) }
    composable(SettingsRoutes.SOURCES) { SourcesScreen(onBack = nav::back, onImport = nav::openImport) }
    composable(SettingsRoutes.ABOUT) { LicencesScreen(onBack = nav::back) }
}

private fun thisYear() = Calendar.getInstance().get(Calendar.YEAR)
private fun yearOf(t: Long) = Calendar.getInstance().apply { timeInMillis = t }.get(Calendar.YEAR)

@Composable
fun SettingsScreen(nav: AppNav) {
    val c = QsTheme.colors
    val context = LocalContext.current
    val env = LocalApp.current
    val notifier = LocalNotifier.current
    val scope = rememberCoroutineScope()
    val books by env.library.books.collectAsState(initial = emptyList())

    val (themeRaw, _) = rememberPref(Keys.theme, ThemeId.PeachSage.name)
    val (name, _) = rememberPref(Keys.name, "")
    val (handle, _) = rememberPref(Keys.handle, "")
    val (goal, setGoal) = rememberPref(Keys.goal, 0)
    val (reminderOn, setReminderOn) = rememberPref(Keys.reminderOn, false)
    val (reminderMinutes, setReminderMinutes) = rememberPref(Keys.reminderMinutes, DefaultReminderMinutes)
    val (monthlyRecap, setMonthlyRecap) = rememberPref(Keys.monthlyRecap, false)
    val (lastImport, _) = rememberPref(Keys.lastImport, 0L)
    val (lastImportSource, _) = rememberPref(Keys.lastImportSource, "")

    var editingGoal by rememberSaveable { mutableStateOf(false) }
    var editingReminder by rememberSaveable { mutableStateOf(false) }
    var confirmDelete by rememberSaveable { mutableStateOf(false) }
    var notificationsOff by rememberSaveable { mutableStateOf(false) }
    /** What to switch on once notification permission is granted. */
    var pendingSwitch by rememberSaveable { mutableStateOf<String?>(null) }
    val avatar = remember(name) { Avatar.load(context) }

    val finishedThisYear = books.count { it.status == ReadingStatus.Read && it.dateFinished?.let(::yearOf) == thisYear() }
    val themeName = ThemeId.entries.firstOrNull { it.name == themeRaw }?.displayName ?: ThemeId.PeachSage.displayName

    fun turnOn(what: String) {
        when (what) {
            "reminder" -> { setReminderOn(true); ReminderScheduler.schedule(context, reminderMinutes) }
            "recap" -> { setMonthlyRecap(true); RecapScheduler.schedule(context) }
        }
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val what = pendingSwitch
        pendingSwitch = null
        if (granted && Notifications.allowed(context) && what != null) turnOn(what)
        else notificationsOff = true
    }
    /** Asks for notification permission first (Android 13+); declined = calm "Notifications are off". */
    fun requestOn(what: String) {
        when {
            Notifications.allowed(context) -> turnOn(what)
            Build.VERSION.SDK_INT >= 33 -> { pendingSwitch = what; permission.launch(Manifest.permission.POST_NOTIFICATIONS) }
            else -> notificationsOff = true
        }
    }

    TabScreen("Settings") {
        // Profile card
        val shape = RoundedCornerShape(QsTheme.shapes.card)
        Row(
            Modifier.fillMaxWidth().background(c.surface, shape).border(QsSize.stroke, c.line, shape)
                .pressable(label = "Edit profile") { nav.controller.navigate(SettingsRoutes.PROFILE) }
                .semantics(mergeDescendants = true) {}
                .padding(QsSpace.s16),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            AvatarView(avatar, name, QsSpace.s48 + QsSpace.s8)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(QsSpace.s2)) {
                Text(name.ifEmpty { "Add your name" }, style = QsTheme.headline(22), color = c.ink)
                if (handle.isNotEmpty()) Text("@$handle", style = QsType.footnote, color = c.ink2)
                Text("${if (finishedThisYear == 1) "1 book" else "$finishedThisYear books"} in ${thisYear()}", style = QsType.footnote, color = c.ink2)
            }
            QsIcon(R.drawable.ic_qs_chevron, tint = c.ink2, size = QsSize.iconS + QsSpace.s2)
        }

        SettingsSection("Appearance", listOf(
            { QsListRow(R.drawable.ic_qs_palette, "App theme", value = themeName) { nav.controller.navigate(SettingsRoutes.THEME) } },
            { QsListRow(R.drawable.ic_qs_target, "Reading goal", value = if (goal > 0) "$goal books" else "Not set") { editingGoal = true } },
        ))

        SettingsSection("Reading", listOf(
            {
                ReminderRow(reminderOn, timeText(context, reminderMinutes), onEditTime = { editingReminder = true }) { on ->
                    if (on) requestOn("reminder") else { setReminderOn(false); ReminderScheduler.cancel(context) }
                }
            },
            {
                ToggleRow(R.drawable.ic_qs_calendar, "Monthly recap", "On the 1st, a short look back at your month", monthlyRecap) { on ->
                    if (on) requestOn("recap") else { setMonthlyRecap(false); RecapScheduler.cancel(context) }
                }
            },
            {
                val line = if (lastImport > 0) "$lastImportSource · imported ${DateUtils.getRelativeTimeSpanString(lastImport).toString().lowercase()}"
                    else "Import from Goodreads or StoryGraph"
                QsListRow(R.drawable.ic_qs_link, "Sources", subtitle = line) { nav.controller.navigate(SettingsRoutes.SOURCES) }
            },
        ))

        SettingsSection("Your data", listOf(
            { ActionRow(R.drawable.ic_qs_file, "Export my data", "Books and quotes as CSV files") { DataExport.share(context, books) } },
            { ActionRow(R.drawable.ic_qs_trash, "Delete everything on this phone", destructive = true) { confirmDelete = true } },
        ))

        SettingsSection("About", listOf(
            { QsListRow(R.drawable.ic_qs_info, "Fonts and licences") { nav.controller.navigate(SettingsRoutes.ABOUT) } },
        ))

        Text(
            "Your books stay on this phone. Accounts and sync come later, and they’ll always be optional.",
            style = QsType.footnote, color = c.ink2,
        )
    }

    if (editingGoal) GoalSheet(goal, finishedThisYear, onDismiss = { editingGoal = false }) { new ->
        val changed = new != goal
        setGoal(new)
        editingGoal = false
        if (changed) {
            if (new == 0) notifier.show("Goal turned off", "Your stats keep counting quietly.")
            else {
                val left = maxOf(0, new - finishedThisYear)
                notifier.show("New goal: $new books", if (left == 0) "You've already reached it." else "$left to go this year. No rush.")
            }
        }
    }
    if (editingReminder) ReminderSheet(reminderMinutes, onDismiss = { editingReminder = false }) { minutes ->
        setReminderMinutes(minutes)
        editingReminder = false
        if (reminderOn) ReminderScheduler.schedule(context, minutes)
    }
    if (notificationsOff) QsDialog(
        "Notifications are off",
        "To get your reminder or monthly recap, allow notifications for Quiet Reading in your phone’s settings.",
        "Open settings", { notificationsOff = false; Notifications.openSettings(context) },
        "Not now", { notificationsOff = false },
    )
    if (confirmDelete) QsDialog(
        "Delete everything on this phone?",
        "Your books, progress, quotes and notes will be deleted. This can’t be undone.",
        "Delete", {
            confirmDelete = false
            scope.launch {
                env.library.dao.deleteAllBooks()
                env.covers.dir.listFiles()?.forEach { it.delete() }
                Avatar.save(context, null)
                listOf(Keys.name, Keys.handle, Keys.about, Keys.lastImportSource).forEach { env.prefs.set(it, null) }
                env.prefs.set(Keys.goal, null)
                env.prefs.set(Keys.lastImport, null)
                env.prefs.set(Keys.reminderOn, false)
                env.prefs.set(Keys.monthlyRecap, false)
                ReminderScheduler.cancel(context)
                RecapScheduler.cancel(context)
                env.prefs.set(Keys.onboardingDone, false)
                // Start again from the first-launch screens.
                (context as? Activity)?.recreate()
            }
        },
        "Cancel", { confirmDelete = false }, destructive = true,
    )
}

private fun timeText(context: android.content.Context, minutes: Int): String {
    val cal = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, minutes / 60); set(Calendar.MINUTE, minutes % 60) }
    return DateFormat.getTimeFormat(context).format(cal.time)
}

/** Daily reminder: tap the text to change the time, the switch turns it on or off. */
@Composable
private fun ReminderRow(on: Boolean, time: String, onEditTime: () -> Unit, onToggle: (Boolean) -> Unit) {
    val c = QsTheme.colors
    Row(
        Modifier.fillMaxWidth().padding(QsSpace.s16),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        IconTile(R.drawable.ic_qs_bell)
        Column(
            Modifier.weight(1f).heightIn(min = QsSize.touchAndroid).pressable(label = "Change the time", onClick = onEditTime)
                .semantics(mergeDescendants = true) { contentDescription = "Daily reminder, $time" },
            verticalArrangement = Arrangement.spacedBy(QsSpace.s2, Alignment.CenterVertically),
        ) {
            Text("Daily reminder", style = QsType.body.medium(), color = c.ink)
            Text(time, style = QsType.footnote, color = c.ink2)
        }
        Row(Modifier.toggleable(on, role = Role.Switch, onValueChange = onToggle).semantics { contentDescription = "Daily reminder" }) {
            QsSwitch(on, null)
        }
    }
}
