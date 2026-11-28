package app.quietreading.feature.onboarding

import app.quietreading.data.BookSource
import app.quietreading.data.ReadingStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class LibraryCsvTest {
    private val q = "\""
    private val goodreads = listOf(
        "Book Id,Title,Author,ISBN,ISBN13,My Rating,Number of Pages,Date Read,Exclusive Shelf",
        "1,${q}Anne of Green Gables${q},L.M. Montgomery,${q}=${q}${q}0451528824${q}${q}${q},${q}=${q}${q}9780451528827${q}${q}${q},5,320,2026/10/02,read",
        "2,${q}Pride and Prejudice, Annotated${q},Jane Austen,${q}=${q}${q}0141439513${q}${q}${q},${q}=${q}${q}9780141439518${q}${q}${q},0,480,,currently-reading",
        "3,Klara and the Sun,Kazuo Ishiguro,,,0,,,to-read",
    ).joinToString("\r\n")

    @Test fun goodreads() {
        val books = LibraryCsv.parse(("﻿" + goodreads).toByteArray())
        assertEquals(3, books.size)
        assertEquals("9780451528827", books[0].isbn)
        assertEquals(ReadingStatus.Read, books[0].status)
        assertEquals(5, books[0].rating)
        assertEquals(320, books[0].pageCount)
        assertEquals("Pride and Prejudice, Annotated", books[1].title)
        assertEquals(ReadingStatus.Reading, books[1].status)
        assertNull(books[1].rating)
        assertNull(books[2].isbn)
        assertEquals(BookSource.Goodreads, books[2].source)
    }

    @Test fun storyGraph() {
        val csv = "Title,Authors,ISBN/UID,Read Status,Last Date Read,Star Rating\nCirce,Madeline Miller,9780316556347,read,2025/05/01,4.5\n"
        val b = LibraryCsv.parse(csv.toByteArray()).single()
        assertEquals("Madeline Miller", b.author)
        assertEquals(5, b.rating)
        assertEquals(BookSource.StoryGraph, b.source)
    }

    @Test fun notRecognised() {
        assertThrows(LibraryCsvException::class.java) { LibraryCsv.parse("a,b\n1,2\n".toByteArray()) }
    }
}
