# Room constructs its generated database implementation by reflection.
# Full-mode R8 must retain the no-argument constructor explicitly.
# Without it WorkManagerInitializer crashes before MainActivity starts.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}

-keep class org.poulapp.poulpoints.CloudSyncWorker { public <init>(android.content.Context, androidx.work.WorkerParameters); }
