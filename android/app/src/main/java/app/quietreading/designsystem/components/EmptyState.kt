package app.quietreading.designsystem.components

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.quietreading.designsystem.QsSpace
import app.quietreading.designsystem.QsTheme

/** 🧱 Components › Empty state. Title = what is true now; message = one calm sentence. */
@Composable
fun EmptyState(@DrawableRes icon: Int, title: String, message: String, modifier: Modifier = Modifier) {
    val c = QsTheme.colors
    Column(
        modifier = modifier.fillMaxWidth().padding(vertical = QsSpace.s32).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(QsSpace.s12),
    ) {
        Box(Modifier.size(80.dp).background(c.soft2, CircleShape), contentAlignment = Alignment.Center) {
            Icon(painterResource(icon), contentDescription = null, tint = c.accentInk, modifier = Modifier.size(36.dp))
        }
        Text(title, color = c.ink, fontFamily = QsTheme.headFamily, fontWeight = FontWeight.Medium, fontSize = 22.sp, textAlign = TextAlign.Center)
        Text(message, color = c.ink2, fontSize = 15.sp, lineHeight = 21.sp, textAlign = TextAlign.Center)
    }
}
