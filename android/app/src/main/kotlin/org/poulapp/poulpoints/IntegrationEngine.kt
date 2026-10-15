package org.poulapp.poulpoints

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.work.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONArray
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Main-thread owned engine, shared by the activity and durable background work. */
object IntegrationEngine {
    private var shared: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private val pending = mutableListOf<() -> Unit>()
    var activity: MainActivity? = null
    fun engine(context: Context): FlutterEngine {
        check(Looper.myLooper() == Looper.getMainLooper())
        shared?.let { return it }
        val c = context.applicationContext
        val engine = FlutterEngine(c)
        shared = engine
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "org.poulapp.poulpoints/integration").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scheduleSync" -> { requestSync(c); result.success(null) }
                        "ready" -> {
                            ready = true
                            result.success(null)
                            val callbacks = pending.toList(); pending.clear()
                            callbacks.forEach { it() }
                        }
                        "publish" -> { Integration.publish(c, JSONObject(call.arguments as String)); result.success(null) }
                        "commands" -> {
                            val commands = JSONObject(Integration.prefs(c).getString("commands","{}")!!)
                            val list = JSONArray()
                            commands.keys().forEach { list.put(commands.getJSONObject(it)) }
                            result.success(list.toString())
                        }
                        "ack" -> {
                            val commands = JSONObject(Integration.prefs(c).getString("commands","{}")!!)
                            commands.remove(call.arguments as String)
                            check(Integration.prefs(c).edit().putString("commands",commands.toString()).commit())
                            PoulpointsWidget.refresh(c)
                            result.success(null)
                        }
                        "widgetError" -> {
                            check(Integration.prefs(c).edit().putString("widgetError",call.arguments as String).commit())
                            PoulpointsWidget.refresh(c)
                            result.success(null)
                        }
                        "permissions" -> {
                            val host = activity
                            if (host == null) result.success(Integration.status(c))
                            else host.permissions(call.argument<Boolean>("request") == true, call.argument<Boolean>("exact") == true, result)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("INTEGRATION", "Sauvegarde ou widget indisponible", null) }
            }
        }
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        return engine
    }
    fun sync(c: Context, done: (Boolean) -> Unit) {
        engine(c)
        val action = {
            channel!!.invokeMethod("syncCloud", null, object : MethodChannel.Result {
                override fun success(result: Any?) = done(true)
                override fun error(code: String, message: String?, details: Any?) = done(false)
                override fun notImplemented() = done(false)
            })
        }
        if (ready) action() else pending.add(action)
    }
    fun requestSync(c: Context) {
        WorkManager.getInstance(c).enqueueUniqueWork("poulpoints-cloud-soon", ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<CloudSyncWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build())
    }
    fun schedule(c: Context) {
        WorkManager.getInstance(c).enqueueUniquePeriodicWork("poulpoints-cloud",
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<CloudSyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build())
    }
    fun process(c: Context, done: () -> Unit) {
        engine(c)
        channel!!.invokeMethod("processWidgetCommands", null, object : MethodChannel.Result {
            override fun success(result: Any?) = done()
            override fun error(code: String, message: String?, details: Any?) = done()
            override fun notImplemented() = done()
        })
    }
}

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        Integration.acceptAction(c, intent)
        if (Integration.hasCompletions(c)) {
            PoulpointsWidget.refresh(c)
            val pending = goAsync()
            try {
                val operation = WorkManager.getInstance(c).enqueueUniqueWork("poulpoints-widget", ExistingWorkPolicy.APPEND_OR_REPLACE,
                    OneTimeWorkRequestBuilder<WidgetCommandWorker>()
                        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS).build())
                operation.result.addListener({ pending.finish() }, androidx.core.content.ContextCompat.getMainExecutor(c))
            } catch (_: Exception) { pending.finish() }
        }
    }
}

class WidgetCommandWorker(c: Context, parameters: WorkerParameters) : Worker(c, parameters) {
    override fun doWork(): Result {
        if (!Integration.hasCompletions(applicationContext)) return Result.success()
        val latch = CountDownLatch(1)
        Handler(Looper.getMainLooper()).post {
            try { IntegrationEngine.process(applicationContext) { latch.countDown() } }
            catch (_: Exception) { latch.countDown() }
        }
        latch.await(30, TimeUnit.SECONDS)
        return if (Integration.hasCompletions(applicationContext)) Result.retry() else Result.success()
    }
}

/** Scheduled by Android, with no activity launch and no Google services. */
class CloudSyncWorker(c: Context, parameters: WorkerParameters) : Worker(c, parameters) {
    override fun doWork(): Result {
        val latch = CountDownLatch(1)
        var succeeded = false
        Handler(Looper.getMainLooper()).post {
            try { IntegrationEngine.sync(applicationContext) { ok -> succeeded = ok; latch.countDown() } }
            catch (_: Exception) { latch.countDown() }
        }
        return if (latch.await(120, TimeUnit.SECONDS) && succeeded) Result.success() else Result.retry()
    }
}
