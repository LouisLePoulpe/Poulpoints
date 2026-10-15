package org.poulapp.poulpoints

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.widget.ListView
import android.widget.TextView
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class IntegrationTest {
    private lateinit var app: Application
    private fun data(at: Long = System.currentTimeMillis()+60000) = JSONObject("""{"version":1,"tasks":[{"id":"a","title":"Rappel A","list":"Personnel","revision":"42","due":$at,"remindAt":$at}]}""")
    @Before fun setup() { app=RuntimeEnvironment.getApplication(); Integration.prefs(app).edit().clear().commit() }
    @Test @Config(qualifiers = "night") fun widgetUsesReadableDarkPalette() {
        val root = PoulpointsWidget.render(app,99).apply(app,android.appwidget.AppWidgetHostView(app))
        assertEquals(android.graphics.Color.parseColor("#E6EDF5"),root.findViewById<TextView>(R.id.widget_title).currentTextColor)
        assertEquals(android.graphics.Color.parseColor("#17212B"),(root.background as android.graphics.drawable.GradientDrawable).color!!.defaultColor)
    }
    @Test @Config(qualifiers = "notnight") fun widgetRetainsLightPalette() {
        val root = PoulpointsWidget.render(app,99).apply(app,android.appwidget.AppWidgetHostView(app))
        assertEquals(android.graphics.Color.parseColor("#153550"),root.findViewById<TextView>(R.id.widget_title).currentTextColor)
    }
    @Test fun alarmsAreReplacedAndCancelled() {
        val alarms=shadowOf(app.getSystemService(AlarmManager::class.java))
        Integration.publish(app,data())
        assertEquals(1,alarms.scheduledAlarms.size)
        Integration.publish(app,data(System.currentTimeMillis()+120000))
        assertEquals(1,alarms.scheduledAlarms.size)
        Integration.publish(app,JSONObject("""{"version":1,"tasks":[]}"""))
        assertEquals(0,alarms.scheduledAlarms.size)
    }
    @Test fun multipleRemindersAdvanceWithoutDuplicatingAndCancelTogether() {
        val first=System.currentTimeMillis()
        val second=first+60000
        val snapshot=data(first)
        snapshot.getJSONArray("tasks").getJSONObject(0).put("remindAts",org.json.JSONArray().put(first).put(second))
        Integration.publish(app,snapshot)
        val alarms=shadowOf(app.getSystemService(AlarmManager::class.java))
        ReminderReceiver().onReceive(app,Intent("REMIND").putExtra("id","a").putExtra("at",first))
        assertEquals(second,shadowOf(alarms.scheduledAlarms.single().operation!!).savedIntent.getLongExtra("at",-1))
        val manager=app.getSystemService(NotificationManager::class.java)
        manager.cancelAll()
        ReminderReceiver().onReceive(app,Intent("REMIND").putExtra("id","a").putExtra("at",first))
        assertEquals(0,shadowOf(manager).size())
        Integration.publish(app,JSONObject("""{"version":1,"tasks":[]}"""))
        assertEquals(0,alarms.scheduledAlarms.size)
    }
    @Test fun notificationSnoozeQueuesAnAuthenticatedBackgroundCommand() {
        val pending=Integration.open(app,"snooze",data().getJSONArray("tasks").getJSONObject(0))
        assertTrue(pending.isBroadcast)
        Integration.acceptAction(app,shadowOf(pending).savedIntent)
        assertTrue(Integration.hasCompletions(app))
    }
    @Test fun notificationDeliveredOnceAndCancelledWhenTaskCompletes() {
        val at=System.currentTimeMillis()
        val manager=app.getSystemService(NotificationManager::class.java)
        Integration.publish(app,data(at))
        val intent=Intent("REMIND").putExtra("id","a").putExtra("at",at)
        ReminderReceiver().onReceive(app,intent)
        assertEquals(1,shadowOf(manager).size())
        manager.cancelAll()
        ReminderReceiver().onReceive(app,intent)
        assertEquals(0,shadowOf(manager).size())
        Integration.publish(app,JSONObject("""{"version":1,"tasks":[]}"""))
        ReminderReceiver().onReceive(app,intent)
        assertEquals(0,shadowOf(manager).size())
    }
    @Test fun staleAlarmDoesNotNotifyAfterReschedule() {
        Integration.publish(app,data(System.currentTimeMillis()+120000))
        ReminderReceiver().onReceive(app,Intent("REMIND").putExtra("id","a").putExtra("at",1L))
        assertEquals(0,shadowOf(app.getSystemService(NotificationManager::class.java)).size())
    }
    @Test fun rebootRestoresAlarmFromPersistentProjection() {
        Integration.publish(app,data())
        val alarms=shadowOf(app.getSystemService(AlarmManager::class.java))
        val existing=alarms.scheduledAlarms.single()
        app.getSystemService(AlarmManager::class.java).cancel(existing.operation!!)
        assertEquals(0,alarms.scheduledAlarms.size)
        ReminderReceiver().onReceive(app,Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(1,alarms.scheduledAlarms.size)
    }
    @Test fun widgetRendersAndFiltersTasks() {
        Integration.publish(app,data())
        val widgets=shadowOf(AppWidgetManager.getInstance(app))
        val id=widgets.createWidget(PoulpointsWidget::class.java,R.layout.poulpoints_widget)
        PoulpointsWidget.refresh(app)
        val view=PoulpointsWidget.render(app,id).apply(app,android.appwidget.AppWidgetHostView(app))
        val list = view.findViewById<ListView>(R.id.widget_tasks)
        assertEquals("Rappel A",list.adapter.getView(0,null,list).findViewById<TextView>(R.id.task_title).text.toString())
        Integration.prefs(app).edit().putString("widget-list-$id","Travail").commit()
        PoulpointsWidget.refresh(app)
        assertEquals(0,PoulpointsWidget.render(app,id).apply(app,android.appwidget.AppWidgetHostView(app)).findViewById<ListView>(R.id.widget_tasks).adapter.count)
    }
    @Test fun widgetActionCarriesStableRevisionAndPrivateAuthorization() {
        val task=data().getJSONArray("tasks").getJSONObject(0)
        val pending=Integration.open(app,"complete",task)
        assertTrue(pending.isBroadcast)
        assertFalse(pending.isActivity)
        val intent=shadowOf(pending).savedIntent
        assertEquals(WidgetActionReceiver::class.java.name,intent.component!!.className)
        assertEquals("42",intent.getStringExtra("revision"))
        assertEquals("a",intent.getStringExtra("id"))
        assertEquals(Integration.actionKey(app),intent.getStringExtra("authorization"))
    }
    @Test fun widgetKeepsAllRowsWhenResized() {
        val data = data()
        val tasks = data.getJSONArray("tasks")
        for (n in 1..12) tasks.put(JSONObject(tasks.getJSONObject(0).toString()).put("id","task$n"))
        Integration.publish(app,data)
        val manager = AppWidgetManager.getInstance(app)
        val widgets = shadowOf(manager)
        val id = widgets.createWidget(PoulpointsWidget::class.java,R.layout.poulpoints_widget)
        fun resize(height: Int): Int {
            val options = android.os.Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,150)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,height)
            }
            manager.updateAppWidgetOptions(id,options)
            PoulpointsWidget().onAppWidgetOptionsChanged(app,manager,id,options)
            return PoulpointsWidget.render(app,id).apply(app,android.appwidget.AppWidgetHostView(app)).findViewById<ListView>(R.id.widget_tasks).adapter.count
        }
        assertEquals(13,resize(110))
        assertEquals(13,resize(400))
        assertEquals(13,resize(110))
    }
    @Test fun modernCollectionCanScrollToLastTask() {
        val source = data()
        val tasks = source.getJSONArray("tasks")
        for (n in 1..80) tasks.put(JSONObject(tasks.getJSONObject(0).toString()).put("id","row$n").put("title","Task $n"))
        Integration.publish(app,source)
        val root = PoulpointsWidget.render(app,99).apply(app,android.appwidget.AppWidgetHostView(app))
        val list = root.findViewById<ListView>(R.id.widget_tasks)
        val exact = android.view.View.MeasureSpec.EXACTLY
        fun layout() {
            root.measure(android.view.View.MeasureSpec.makeMeasureSpec(240,exact),android.view.View.MeasureSpec.makeMeasureSpec(240,exact))
            root.layout(0,0,240,240)
        }
        layout()
        assertEquals(81,list.adapter.count)
        assertTrue(list.canScrollVertically(1))
        list.setSelection(80)
        layout()
        assertEquals(80,list.lastVisiblePosition)
        assertEquals("Task 80",list.adapter.getView(80,null,list).findViewById<TextView>(R.id.task_title).text.toString())
    }
    @Test fun legacyCollectionKeepsAllTasksAndRefreshesFilter() {
        val source = data()
        val tasks = source.getJSONArray("tasks")
        for (n in 1..80) tasks.put(JSONObject(tasks.getJSONObject(0).toString()).put("id","row$n").put("title","Task $n"))
        Integration.publish(app,source)
        val rows = TaskRows(app,99)
        rows.onCreate()
        assertEquals(81,rows.count)
        assertNotNull(rows.getViewAt(80))
        Integration.prefs(app).edit().putString("widget-list-99","Travail").commit()
        rows.onDataSetChanged()
        assertEquals(0,rows.count)
    }
    @Test fun collectionCompletionUsesBroadcastAndFilledTaskVersion() {
        val pending = WidgetTasks.template(app,99)
        assertTrue(pending.isBroadcast)
        assertFalse(pending.isImmutable)
        val intent = Intent(shadowOf(pending).savedIntent)
        intent.fillIn(Intent().putExtra("id","last-row").putExtra("revision","51"),0)
        Integration.acceptAction(app,intent)
        val commands = JSONObject(Integration.prefs(app).getString("commands","{}")!!)
        val command = commands.getJSONObject(commands.keys().next())
        assertEquals("last-row",command.getString("id"))
        assertEquals("51",command.getString("revision"))
    }
    @Test fun onlyAuthorizedWidgetIntentsEnterQueueAndRepeatedClickIsIdempotent() {
        val forged=Intent("org.poulapp.poulpoints.WIDGET").putExtra("operation","complete").putExtra("id","a").putExtra("revision","42")
        Integration.acceptAction(app,forged)
        assertEquals("{}",Integration.prefs(app).getString("commands","{}"))
        val task=data().getJSONArray("tasks").getJSONObject(0)
        val authorized=shadowOf(Integration.open(app,"complete",task)).savedIntent
        Integration.acceptAction(app,Intent(authorized))
        Integration.acceptAction(app,Intent(authorized))
        val commands=JSONObject(Integration.prefs(app).getString("commands","{}")!!)
        assertEquals(1,commands.length())
        assertEquals("42",commands.getJSONObject(commands.keys().next()).getString("revision"))
    }

}
