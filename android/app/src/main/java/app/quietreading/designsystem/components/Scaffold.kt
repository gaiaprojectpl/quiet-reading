package app.quietreading.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.quietreading.R
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType

/** Large screen title in the theme's serif heading font, marked as a heading. */
@Composable
fun ScreenTitle(title: String, modifier: Modifier = Modifier) {
    Text(title, style = QsTheme.headline(34), color = QsTheme.colors.ink, modifier = modifier.semantics { heading() })
}

/**
 * Large title with icon buttons (search, sort, share…) on the same line, so no row is wasted.
 * At very large font sizes the icons move under the title instead of squeezing it.
 */
@Composable
fun ScreenHeader(title: String, modifier: Modifier = Modifier, trailing: @Composable RowScope.() -> Unit = {}) {
    val large = LocalDensity.current.fontScale >= 1.6f
    if (large) {
        Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(QsSpace.s4)) {
            ScreenTitle(title)
            Row(content = trailing)
        }
    } else {
        Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(QsSpace.s8)) {
            ScreenTitle(title, Modifier.weight(1f))
            Row(content = trailing)
        }
    }
}

/**
 * Tab screen shell (Home, Library, Stats, Settings): themed background, 20 dp side margins,
 * scrolling column. Buttons stay inline in the content here (Kaja's rule for screens with the tab bar).
 */
@Composable
fun TabScreen(
    title: String,
    modifier: Modifier = Modifier,
    header: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier.fillMaxSize().background(QsTheme.colors.bg).statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(horizontal = QsSpace.s20).padding(top = QsSpace.s16, bottom = QsSpace.s40 + QsSize.button + QsSpace.s24),
        verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
    ) {
        if (header != null) header() else ScreenTitle(title, Modifier.padding(bottom = QsSpace.s8))
        content()
    }
}

/**
 * Full-screen flow shell (Add, Import, Update…): back/close at the top, scrolling content and
 * the buttons pinned to the bottom, 24 dp above the bottom line (screen edge, gesture bar or keyboard).
 */
@Composable
fun FlowScreen(
    title: String?,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    backLabel: String = "Back",
    closeInstead: Boolean = false,
    topTrailing: @Composable RowScope.() -> Unit = {},
    actions: (@Composable ColumnScope.() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val c = QsTheme.colors
    Column(modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = QsSize.touchAndroid).padding(horizontal = QsSpace.s4),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (onBack != null) {
                QsIconButton(if (closeInstead) R.drawable.ic_qs_close else R.drawable.ic_qs_arrow_left, backLabel, tint = c.ink, onClick = onBack)
            }
            Box(Modifier.weight(1f))
            topTrailing()
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(horizontal = QsSpace.s20).padding(top = QsSpace.s8, bottom = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s16),
        ) {
            if (title != null) ScreenTitle(title, Modifier.padding(bottom = QsSpace.s8))
            content()
        }
        if (actions != null) {
            Column(
                Modifier.fillMaxWidth().background(c.bg).navigationBarsPadding()
                    .padding(horizontal = QsSpace.s20).padding(top = QsSpace.s12, bottom = QsSpace.s24),
                verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
                content = actions,
            )
        } else {
            Box(Modifier.navigationBarsPadding())
        }
    }
}

/** Secondary text line used all over (author, "Page 120 of 320"). */
@Composable
fun Secondary(text: String, modifier: Modifier = Modifier) {
    Text(text, style = QsType.subheadline, color = QsTheme.colors.ink2, modifier = modifier)
}
