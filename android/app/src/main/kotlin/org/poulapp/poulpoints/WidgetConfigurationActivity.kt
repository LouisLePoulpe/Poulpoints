package org.poulapp.poulpoints

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle

class WidgetConfigurationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        val tasks = Integration.snapshot(this).getJSONArray("tasks")
        val lists = sortedSetOf<String>()
        for(n in 0 until tasks.length()) lists.add(tasks.getJSONObject(n).getString("list"))
        val choices = listOf("Toutes les listes") + lists.toList()
        AlertDialog.Builder(this).setTitle("Poulpoints — liste du widget")
            .setItems(choices.toTypedArray()) { _, which ->
                Integration.prefs(this).edit().putString("widget-list-$id", if(which==0) "" else choices[which]).commit()
                PoulpointsWidget.refresh(this)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id))
                finish()
            }.setOnCancelListener { finish() }.show()
    }
}
