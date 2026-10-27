package org.poulapp.poulpoints

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.TimeUnit
import android.os.Build
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject

object WidgetTasks {
    fun template(c: Context, widget: Int): PendingIntent {
        val intent = Intent(c, WidgetActionReceiver::class.java)
            .setAction("org.poulapp.poulpoints.WIDGET")
            .setData(Uri.parse("poulpoints-completion://widget/$widget"))
            .putExtra("authorization", Integration.actionKey(c))
        // Collection rows must fill in their task ID and revision. The target
        // receiver is fixed; the receiver still verifies the key.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(c, widget, intent, flags)
    }
    /** Number of local calendar days overdue; resilient to 23/25-hour DST days. */
    internal fun overdueDays(dueMillis: Long, nowMillis: Long): Int? {
        if (dueMillis >= nowMillis) return null
        fun epochDay(millis: Long): Long {
            val local = Calendar.getInstance().apply { timeInMillis = millis }
            val utc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                clear()
                set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
            }
            return TimeUnit.MILLISECONDS.toDays(utc.timeInMillis)
        }
        return (epochDay(nowMillis) - epochDay(dueMillis)).toInt().coerceAtLeast(0)
    }
    fun row(c: Context, task: JSONObject): RemoteViews {
        val row = RemoteViews(c.packageName, R.layout.poulpoints_widget_row)
        row.setTextViewText(R.id.task_title, task.getString("title"))
        val due = if (task.isNull("due")) "" else " · " +
            (if (task.optBoolean("hasDueTime", true))
                java.text.DateFormat.getDateTimeInstance(java.text.DateFormat.SHORT, java.text.DateFormat.SHORT)
             else java.text.DateFormat.getDateInstance(java.text.DateFormat.SHORT))
                .format(java.util.Date(task.getLong("due")))
        row.setTextViewText(R.id.task_detail, task.getString("list") + due)
        val overdue = if (task.isNull("due")) null else overdueDays(task.getLong("due"), System.currentTimeMillis())
        if (overdue != null) {
            row.setViewVisibility(R.id.task_overdue_bar, View.VISIBLE)
            row.setViewVisibility(R.id.task_overdue_label, View.VISIBLE)
            row.setTextViewText(R.id.task_overdue_label, if (overdue == 0) "!" else "J+$overdue")
            row.setTextColor(R.id.task_detail, c.getColor(R.color.widget_overdue))
            row.setContentDescription(R.id.task_overdue_label, if (overdue == 0) "En retard" else "En retard de $overdue jour(s)")
        } else {
            // Android peut réutiliser une RemoteViews d'une tâche en retard.
            // Réinitialiser explicitement la couleur pour ne pas laisser la date
            // d'une tâche future affichée en rouge (bug constaté sur Pixel).
            row.setTextColor(R.id.task_detail, c.getColor(R.color.widget_secondary))
            row.setViewVisibility(R.id.task_overdue_bar, View.GONE)
            row.setViewVisibility(R.id.task_overdue_label, View.GONE)
            row.setTextViewText(R.id.task_overdue_label, "")
            row.setContentDescription(R.id.task_overdue_label, "")
        }
        row.setOnClickFillInIntent(R.id.task_done, Intent().putExtra("operation", "complete")
            .putExtra("id", task.getString("id"))
            .putExtra("revision", task.getString("revision")))
        row.setContentDescription(R.id.task_info, "Ouvrir " + task.getString("title"))
        row.setOnClickFillInIntent(R.id.task_info, Intent()
            .putExtra("operation", "open-task")
            .putExtra("id", task.getString("id")))
        return row
    }
}

/** Legacy collection host for Android 7–11; Android 12+ uses inline items. */
class WidgetTasksService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = TaskRows(
        applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1))
}

class TaskRows(private val context: Context, private val widget: Int) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = emptyList<JSONObject>()
    override fun onCreate() { onDataSetChanged() }
    override fun onDataSetChanged() {
        val filter = Integration.prefs(context).getString("widget-list-$widget", "")!!
        val data = Integration.snapshot(context).getJSONArray("tasks")
        tasks = (0 until data.length()).map { data.getJSONObject(it) }
            .filter { filter.isEmpty() || it.getString("list") == filter }
    }
    override fun onDestroy() { tasks = emptyList() }
    override fun getCount() = tasks.size
    override fun getViewAt(position: Int): RemoteViews? = tasks.getOrNull(position)?.let { WidgetTasks.row(context, it) }
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
}
