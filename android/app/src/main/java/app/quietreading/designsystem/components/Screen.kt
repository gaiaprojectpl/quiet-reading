package app.quietreading.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme

/** Shared screen shell: 16 dp side margins, serif title, scrollable column. */
@Composable
fun Screen(title: String, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = QsSpace.s16).padding(top = QsSpace.s16, bottom = QsSpace.s40),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        Text(
            title, color = QsTheme.colors.ink, fontFamily = QsTheme.headFamily,
            fontWeight = FontWeight.Medium, fontSize = 28.sp,
            modifier = Modifier.semantics { heading() },
        )
        content()
    }
}
