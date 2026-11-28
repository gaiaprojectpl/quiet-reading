package app.quietreading.feature.book

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import app.quietreading.app.AppNav
import app.quietreading.app.Routes
import app.quietreading.data.Book
import app.quietreading.data.ReadingStatus
import app.quietreading.feature.progress.FinishedScreen
import app.quietreading.feature.progress.UpdatePageScreen
import app.quietreading.feature.progress.WhatNextScreen

/** Routes of book details and its flows (update page, Finished moment, What's next, note). */
object BookRoutes {
    const val UPDATE = "book/{id}/update"
    const val FINISH = "book/{id}/finish"
    const val NOTE = "book/{id}/note"
    const val WHAT_NEXT = "whatnext"
    fun update(id: Long) = "book/$id/update"
    fun finish(id: Long) = "book/$id/finish"
    fun note(id: Long) = "book/$id/note"
}

private val idArg = listOf(navArgument("id") { type = NavType.LongType })

fun NavGraphBuilder.bookGraph(nav: AppNav) {
    composable(Routes.BOOK, arguments = idArg) { e ->
        WithBook(e.arguments?.getLong("id"), nav) { BookDetailScreen(it, nav) }
    }
    composable(BookRoutes.UPDATE, arguments = idArg) { e ->
        WithBook(e.arguments?.getLong("id"), nav) { book ->
            UpdatePageScreen(book, onClose = nav::back, onFinish = {
                nav.controller.navigate(BookRoutes.finish(book.id)) { popUpTo(BookRoutes.UPDATE) { inclusive = true } }
            })
        }
    }
    composable(BookRoutes.FINISH, arguments = idArg) { e ->
        val books = rememberAllBooks()
        WithBook(e.arguments?.getLong("id"), nav) { book ->
            FinishedScreen(book, books.orEmpty().filter { it.status == ReadingStatus.ToRead }) { hasNext ->
                if (hasNext) nav.controller.navigate(BookRoutes.WHAT_NEXT) { popUpTo(BookRoutes.FINISH) { inclusive = true } }
                else nav.back()
            }
        }
    }
    composable(BookRoutes.NOTE, arguments = idArg) { e ->
        WithBook(e.arguments?.getLong("id"), nav) { NoteComposerScreen(it, onClose = nav::back) }
    }
    composable(BookRoutes.WHAT_NEXT) {
        val books = rememberAllBooks() ?: return@composable
        WhatNextScreen(books.filter { it.status == ReadingStatus.ToRead }, onDone = nav::back)
    }
}

/** Finds the book by id; if it was removed, goes back. */
@Composable
private fun WithBook(id: Long?, nav: AppNav, content: @Composable (Book) -> Unit) {
    val books = rememberAllBooks() ?: return
    val book = books.firstOrNull { it.id == id }
    if (book == null) {
        LaunchedEffect(Unit) { nav.back() }
        return
    }
    content(book)
}
