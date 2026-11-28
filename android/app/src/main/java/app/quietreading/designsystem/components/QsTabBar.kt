package app.quietreading.designsystem.components

import androidx.annotation.DrawableRes
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import app.quietreading.R
import app.quietreading.designsystem.QsMotion
import app.quietreading.designsystem.QsSize
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme
import app.quietreading.designsystem.QsType

enum class AppTab(val label: String, @param:DrawableRes val icon: Int) {
    Home("Home", R.drawable.ic_qs_home),
    Library("Library", R.drawable.ic_qs_library),
    Add("Add", R.drawable.ic_qs_add),
    Stats("Stats", R.drawable.ic_qs_stats),
    Settings("Settings", R.drawable.ic_qs_settings),
}

/**
 * 🧱 Components › Nav bar (Figma 47:216). One navigation everywhere: Home · Library · Add · Stats · Settings.
 * Active = soft pill + semibold label, pressed = soft2 (tintStrong when active).
 * Add = accent circle that opens the Add sheet – never active.
 */
@Composable
fun QsTabBar(selection: AppTab, onSelect: (AppTab) -> Unit, onAdd: () -> Unit) {
    val c = QsTheme.colors
    Column(Modifier.fillMaxWidth().background(c.surface)) {
        HorizontalDivider(thickness = QsSize.stroke, color = c.line)
        Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = QsSpace.s12).padding(top = QsSpace.s8, bottom = QsSpace.s4)) {
            AppTab.entries.forEach { tab ->
                NavItem(tab, active = tab != AppTab.Add && tab == selection, Modifier.weight(1f)) {
                    if (tab == AppTab.Add) onAdd() else onSelect(tab)
                }
            }
        }
    }
}

/** The same navigation as a vertical rail, for unfolded foldables and tablets (iPhone Duo open = side rail). */
@Composable
fun QsTabRail(selection: AppTab, onSelect: (AppTab) -> Unit, onAdd: () -> Unit, top: @Composable () -> Unit = {}) {
    val c = QsTheme.colors
    Row(Modifier.fillMaxHeight()) {
        Column(
            Modifier.fillMaxHeight().width(QsSpace.s80 + QsSpace.s8).background(c.surface).navigationBarsPadding().padding(vertical = QsSpace.s24),
            verticalArrangement = Arrangement.spacedBy(QsSpace.s8, Alignment.Bottom),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            top()
            AppTab.entries.forEach { tab ->
                NavItem(tab, active = tab != AppTab.Add && tab == selection, Modifier.fillMaxWidth()) {
                    if (tab == AppTab.Add) onAdd() else onSelect(tab)
                }
            }
        }
        VerticalDivider(thickness = QsSize.stroke, color = c.line)
    }
}

@Composable
private fun NavItem(tab: AppTab, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = QsTheme.colors
    val haptics = LocalHapticFeedback.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pill by animateColorAsState(
        when { active && pressed -> c.tintStrong; active -> c.soft; pressed -> c.soft2; else -> Color.Transparent },
        tween(QsMotion.fast), label = "pill",
    )
    Column(
        modifier
            .heightIn(min = QsSize.touchAndroid)
            .selectable(active, interaction, indication = null, role = Role.Tab) {
                haptics.performHapticFeedback(HapticFeedbackType.SegmentTick); onClick()
            }
            .padding(QsSpace.s4),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(QsSpace.s4),
    ) {
        if (tab == AppTab.Add) {
            Box(Modifier.size(QsSpace.s48, QsSpace.s40).background(if (pressed) c.accentPressed else c.accent, CircleShape), contentAlignment = Alignment.Center) {
                QsIcon(tab.icon, tint = c.onAccent, size = QsSize.iconL)
            }
        } else {
            Box(Modifier.size(QsSpace.s64, QsSpace.s32).background(pill, CircleShape), contentAlignment = Alignment.Center) {
                QsIcon(tab.icon, tint = if (active) c.ink else c.ink2, size = QsSize.iconL)
            }
        }
        Text(
            tab.label, style = QsType.caption.copy(fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium),
            color = if (active || tab == AppTab.Add) c.ink else c.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
    }
}
