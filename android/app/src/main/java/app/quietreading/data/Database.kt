package app.quietreading.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine

@Dao
interface BookDao {
    @Query("SELECT * FROM books") fun books(): Flow<List<BookEntity>>
    @Query("SELECT * FROM sessions") fun sessions(): Flow<List<SessionEntity>>
    @Query("SELECT * FROM quotes") fun quotes(): Flow<List<QuoteEntity>>
    @Query("SELECT * FROM books WHERE id = :id") suspend fun book(id: Long): BookEntity?
    @Query("SELECT * FROM books") suspend fun allBooks(): List<BookEntity>

    @Insert suspend fun insert(book: BookEntity): Long
    @Insert suspend fun insertAll(books: List<BookEntity>): List<Long>
    @Update suspend fun update(book: BookEntity)
    @Delete suspend fun delete(book: BookEntity)
    @Query("DELETE FROM books") suspend fun deleteAllBooks()

    @Insert suspend fun insert(session: SessionEntity): Long
    @Update suspend fun update(session: SessionEntity)
    @Delete suspend fun delete(session: SessionEntity)

    @Insert suspend fun insert(quote: QuoteEntity): Long
    @Update suspend fun update(quote: QuoteEntity)
    @Delete suspend fun delete(quote: QuoteEntity)

    @Transaction
    suspend fun addSession(book: BookEntity, session: SessionEntity) {
        insert(session)
        update(book)
    }
}

@Database(entities = [BookEntity::class, SessionEntity::class, QuoteEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun books(): BookDao

    companion object {
        @Volatile private var instance: AppDatabase? = null
        fun get(context: Context): AppDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "quiet-reading.db")
                .build().also { instance = it }
        }
    }
}

/** Every book with its sessions and quotes, kept up to date. */
fun BookDao.library(): Flow<List<Book>> = combine(books(), sessions(), quotes()) { books, sessions, quotes ->
    val s = sessions.groupBy { it.bookId }
    val q = quotes.groupBy { it.bookId }
    books.map { Book(it, s[it.id].orEmpty().sortedBy { x -> x.date }, q[it.id].orEmpty().sortedByDescending { x -> x.date }) }
}
