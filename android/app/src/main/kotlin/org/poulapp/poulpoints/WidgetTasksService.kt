package org.poulapp.poulpoints

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
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
            .putExtra("operation", "complete")
        // Collection rows must fill in their task ID and revision. The target
        // receiver and operation are fixed; the receiver still verifies the key.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(c, widget, intent, flags)
    }
    fun row(c: Context, task: JSONObject): RemoteViews {
        val row = RemoteViews(c.packageName, R.layout.poulpoints_widget_row)
        row.setTextViewText(R.id.task_title, task.getString("title"))
        val due = if (task.isNull("due")) "" else " · " + java.text.DateFormat.getDateTimeInstance(
            java.text.DateFormat.SHORT, java.text.DateFormat.SHORT).format(java.util.Date(task.getLong("due")))
        row.setTextViewText(R.id.task_detail, task.getString("list") + due)
        row.setOnClickFillInIntent(R.id.task_done, Intent()
            .putExtra("id", task.getString("id"))
            .putExtra("revision", task.getString("revision")))
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
