package org.poulapp.poulpoints

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        IntegrationEngine.schedule(this)
        acceptAction(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acceptAction(intent)
    }
    private fun acceptAction(intent: Intent) = Integration.acceptAction(this, intent)
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine = IntegrationEngine.engine(context)
    override fun shouldDestroyEngineWithHost() = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        IntegrationEngine.activity = this
    }
    override fun onDestroy() {
        if (IntegrationEngine.activity === this) IntegrationEngine.activity = null
        permissionResult?.error("CLOSED", "Fenêtre fermée", null)
        permissionResult = null
        super.onDestroy()
    }
    fun permissions(request: Boolean, exact: Boolean, result: MethodChannel.Result) {
        Integration.channel(this)
        if (exact && Build.VERSION.SDK_INT >= 31) {
            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
            result.success("Vérifiez l’autorisation dans Android, puis revenez dans Poulpoints.")
        } else if (request && Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            if (permissionResult != null) result.error("BUSY", "Demande déjà en cours", null)
            else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 600) }
        } else result.success(Integration.status(this))
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 600) { permissionResult?.success(Integration.status(this)); permissionResult = null }
    }
}
