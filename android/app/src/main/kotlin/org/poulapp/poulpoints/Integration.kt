package org.poulapp.poulpoints

import android.app.*
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.*
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

object Integration {
    fun acceptAction(c: Context, intent: Intent) {
        if (intent.action != "org.poulapp.poulpoints.WIDGET") return
        if (intent.getStringExtra("authorization") != actionKey(c)) return
        val action = intent.getStringExtra("operation") ?: return
        if (action !in listOf("complete", "new", "snooze", "open-task")) return
        // Intent contents are untrusted; Flutter verifies ID and revision before applying.
        val id = intent.getStringExtra("id") ?: ""
        val revision = intent.getStringExtra("revision") ?: ""
        val token = if (action in listOf("complete", "snooze")) android.util.Base64.encodeToString("$action:$id:$revision".toByteArray(), android.util.Base64.NO_WRAP or android.util.Base64.URL_SAFE) else java.util.UUID.randomUUID().toString()
        val prefs = prefs(c)
        val commands = JSONObject(prefs.getString("commands", "{}")!!)
        commands.put(token, JSONObject().put("token",token).put("action",action).put("id",id).put("revision",revision))
        check(prefs.edit().putString("commands",commands.toString()).remove("widgetError").commit())
        intent.action = Intent.ACTION_MAIN
    }

    fun hasCompletions(c: Context): Boolean {
        val commands = JSONObject(prefs(c).getString("commands","{}")!!)
        return commands.keys().asSequence().any { commands.getJSONObject(it).optString("action") in listOf("complete", "snooze") }
    }
    fun prefs(c: Context) = c.getSharedPreferences("poulpoints_integration", Context.MODE_PRIVATE)
    fun actionKey(c: Context): String {
        val prefs = prefs(c)
        val existing = prefs.getString("actionKey",null)
        if (existing != null) return existing
        val key = java.util.UUID.randomUUID().toString()
        if (!prefs.edit().putString("actionKey",key).commit()) throw IllegalStateException("Storage failed")
        return key
    }
    fun snapshot(c: Context) = JSONObject(prefs(c).getString("snapshot", "{\"tasks\":[]}")!!)
    fun channel(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) c.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("tasks", "Rappels de tâches", NotificationManager.IMPORTANCE_HIGH))
    }
    fun status(c: Context): String {
        val enabled = c.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        val exact = Build.VERSION.SDK_INT < 31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        return if (!enabled) "Notifications désactivées dans Android." else if (exact) "Notifications actives ; horaires précis autorisés." else "Notifications actives ; horaires approximatifs (économie de batterie Android)."
    }
    private fun alarmIntent(c: Context, task: JSONObject): PendingIntent {
        val id = task.getString("id")
        val i = Intent(c, ReminderReceiver::class.java).setAction("REMIND").setData(Uri.Builder().scheme("poulpoints-reminder").authority("task").appendPath(id).build())
            .putExtra("id",id).putExtra("at",task.optLong("remindAt"))
        return PendingIntent.getBroadcast(c,0,i,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun publish(c: Context, data: JSONObject) {
        val alarms = c.getSystemService(AlarmManager::class.java)
        val old = snapshot(c).getJSONArray("tasks")
        val next = data.getJSONArray("tasks")
        val upcoming = mutableMapOf<String,JSONObject>()
        for (n in 0 until next.length()) upcoming[next.getJSONObject(n).getString("id")] = next.getJSONObject(n)
        for (n in 0 until old.length()) {
            val task = old.getJSONObject(n)
            if (!task.isNull("remindAt")) alarms.cancel(alarmIntent(c,task))
            val current = upcoming[task.getString("id")]
            if (current == null || times(current) != times(task))
                c.getSystemService(NotificationManager::class.java).cancel(task.getString("id"),0)
        }
        if (!prefs(c).edit().putString("snapshot",data.toString()).remove("widgetError").commit()) throw IllegalStateException("Storage failed")
        schedule(c)
        PoulpointsWidget.refresh(c)
    }
    fun times(task: JSONObject): List<Long> {
        val all = task.optJSONArray("remindAts")
        return if (all != null) (0 until all.length()).map { all.getLong(it) }.distinct().sorted()
        else if (!task.isNull("remindAt")) listOf(task.getLong("remindAt")) else emptyList()
    }
    fun schedule(c: Context) {
        channel(c)
        val alarms = c.getSystemService(AlarmManager::class.java)
        val tasks = snapshot(c).getJSONArray("tasks")
        val delivered = prefs(c).getStringSet("delivered",emptySet())!!
        val now = System.currentTimeMillis()
        for (n in 0 until tasks.length()) {
            val task = tasks.getJSONObject(n)
            val at = times(task).firstOrNull { it >= now - 86400000L && "${task.getString("id")}:$it" !in delivered } ?: continue
            val whenAt = maxOf(at,now+1000)
            val pending = alarmIntent(c,JSONObject(task.toString()).put("remindAt",at))
            if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
                try { alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,whenAt,pending) }
                catch (_: SecurityException) { alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,whenAt,pending) }
            } else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,whenAt,pending)
        }
    }
    fun open(c: Context, action: String = "open", task: JSONObject? = null): PendingIntent {
        val id = task?.optString("id") ?: ""
        val revision = task?.optString("revision") ?: ""
        val intent = Intent(c,if(action in listOf("complete", "snooze")) WidgetActionReceiver::class.java else MainActivity::class.java).setAction("org.poulapp.poulpoints.WIDGET")
            .setData(Uri.Builder().scheme("poulpoints-widget").authority(action).appendPath(id).appendPath(revision).build())
            .putExtra("authorization",actionKey(c)).putExtra("operation",action).putExtra("id",id).putExtra("revision",revision)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return if (action in listOf("complete", "snooze")) PendingIntent.getBroadcast(c,0,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        else PendingIntent.getActivity(c,0,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action != "REMIND") { Integration.schedule(c); PoulpointsWidget.refresh(c); return }
        val id = intent.getStringExtra("id") ?: return
        val at = intent.getLongExtra("at",-1)
        val tasks = Integration.snapshot(c).getJSONArray("tasks")
        val delivered = Integration.prefs(c).getStringSet("delivered",emptySet())!!.toMutableSet()
        val key = "$id:$at"
        if (key in delivered) return
        val manager = c.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        for (n in 0 until tasks.length()) {
            val task = tasks.getJSONObject(n)
            if (task.getString("id") != id || at !in Integration.times(task)) continue
            Integration.channel(c)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c,"tasks") else Notification.Builder(c)
            val notification = builder.setSmallIcon(R.drawable.ic_notification).setContentTitle(task.getString("title"))
                .setContentText("Poulpoints · ${task.getString("list")}").setAutoCancel(true)
                .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(Integration.open(c))
                .addAction(Notification.Action.Builder(null,"Terminer",Integration.open(c,"complete",task)).build())
                .addAction(Notification.Action.Builder(null,"Dans 10 minutes",Integration.open(c,"snooze",task)).build()).build()
            try { manager.notify(id,0,notification) } catch (_: SecurityException) { return }
            delivered.add(key)
            // Keep only reminders still present in the current snapshot.
            val active = mutableSetOf<String>()
            for (j in 0 until tasks.length()) { val t=tasks.getJSONObject(j);Integration.times(t).forEach { active.add("${t.getString("id")}:$it") } }
            delivered.retainAll(active)
            Integration.prefs(c).edit().putStringSet("delivered",delivered).commit()
            Integration.schedule(c)
            return
        }
    }
}

class PoulpointsWidget : AppWidgetProvider() {
    override fun onUpdate(c: Context, manager: AppWidgetManager, ids: IntArray) = refresh(c)
    override fun onAppWidgetOptionsChanged(c: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) = refresh(c)
    companion object {
        fun refresh(c: Context) {
            val manager = AppWidgetManager.getInstance(c)
            val ids = manager.getAppWidgetIds(ComponentName(c,PoulpointsWidget::class.java))
            for (widget in ids) {
                manager.updateAppWidget(widget, render(c, widget))
                if (Build.VERSION.SDK_INT < 31) manager.notifyAppWidgetViewDataChanged(widget, R.id.widget_tasks)
            }
        }
        fun render(c: Context, widget: Int): RemoteViews {
            val manager = AppWidgetManager.getInstance(c)
            val tasks = Integration.snapshot(c).getJSONArray("tasks")
                val filter = Integration.prefs(c).getString("widget-list-$widget", "")!!
                val selected = JSONArray()
                for (n in 0 until tasks.length()) { val task = tasks.getJSONObject(n); if (filter.isEmpty() || task.getString("list") == filter) selected.put(task) }

                val options = manager.getAppWidgetOptions(widget)
                val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
                val views = RemoteViews(c.packageName,R.layout.poulpoints_widget)
                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, if(width < 180) 12f else 17f)
                views.setOnClickPendingIntent(R.id.widget_title,Integration.open(c))
                views.setOnClickPendingIntent(R.id.widget_add,Integration.open(c,"new"))
                views.setTextViewText(R.id.widget_status,if(selected.length()==0) "Aucune tâche · ouvrir Poulpoints" else "${selected.length()} tâche(s) · ${if(filter.isEmpty()) "Toutes" else filter}")
                val error = Integration.prefs(c).getString("widgetError",null)
                if (error != null) views.setTextViewText(R.id.widget_status,error)
                else if (Integration.hasCompletions(c)) views.setTextViewText(R.id.widget_status,"Enregistrement…")
                views.setPendingIntentTemplate(R.id.widget_tasks, WidgetTasks.template(c, widget))
                if (Build.VERSION.SDK_INT >= 31) {
                    val items = RemoteViews.RemoteCollectionItems.Builder().setHasStableIds(false).setViewTypeCount(1)
                    for (n in 0 until selected.length()) items.addItem(n.toLong(), WidgetTasks.row(c, selected.getJSONObject(n)))
                    views.setRemoteAdapter(R.id.widget_tasks, items.build())
                } else {
                    val adapter = Intent(c, WidgetTasksService::class.java)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widget)
                        .setData(Uri.parse("poulpoints-list://widget/$widget"))
                    views.setRemoteAdapter(R.id.widget_tasks, adapter)
                }
            return views
        }
    }
}
