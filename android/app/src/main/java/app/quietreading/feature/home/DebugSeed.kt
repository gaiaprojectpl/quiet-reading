package app.quietreading.feature.home

import android.app.Activity
import android.content.pm.ApplicationInfo
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import app.quietreading.data.BookEntity
import app.quietreading.data.LocalApp
import app.quietreading.data.ReadingStatus
import app.quietreading.data.SessionEntity

/**
 * Test builds only: `adb shell am start -n app.quietreading/.MainActivity --ez qsSeed true` fills an empty
 * library with real English books (no ISBNs, so nothing is invented) to check Home and book details.
 */
@Composable
fun DebugSeed() {
    val context = LocalContext.current
    val library = LocalApp.current.library
    LaunchedEffect(Unit) {
        val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val asked = (context as? Activity)?.intent?.getBooleanExtra("qsSeed", false) == true
        if (!debuggable || !asked || library.dao.allBooks().isNotEmpty()) return@LaunchedEffect
        val day = 86_400_000L
        val now = System.currentTimeMillis()
        val anne = library.add(BookEntity(title = "Anne of Green Gables", author = "L. M. Montgomery", pageCount = 320, currentPage = 142, status = ReadingStatus.Reading.raw))
        library.dao.insert(SessionEntity(bookId = anne, date = now - day, fromPage = 98, toPage = 142, minutes = 50, note = "Matthew and the puffed sleeves."))
        library.dao.insert(BookEntity(title = "Piranesi", author = "Susanna Clarke", pageCount = 272, currentPage = 40, status = ReadingStatus.Reading.raw, lastUpdated = now - 3 * day))
        library.dao.insert(BookEntity(title = "The Secret Garden", author = "Frances Hodgson Burnett", pageCount = 331, status = ReadingStatus.ToRead.raw))
        library.dao.insert(BookEntity(title = "Klara and the Sun", author = "Kazuo Ishiguro", pageCount = 303, status = ReadingStatus.ToRead.raw))
        library.dao.insert(BookEntity(title = "Small Things Like These", author = "Claire Keegan", pageCount = 116, status = ReadingStatus.Read.raw, dateFinished = now - 10 * day, stars = 4.5, moods = "Hopeful|Slow"))
    }
}
