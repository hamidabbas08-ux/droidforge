package com.hamid.droidforge

import android.app.Service
import android.content.Intent
import android.os.IBinder
import java.io.File
import java.util.concurrent.Executors

/**
 * Runs the experimental HotSpot/JDK probe in a dedicated Android process.
 * A native crash kills only :runtime_probe, not the Flutter UI process.
 */
class RuntimeProbeService : Service() {
    companion object {
        const val ACTION_PROBE = "com.hamid.droidforge.PROBE_EMBEDDED_JVM"
        const val EXTRA_JAVA_HOME = "javaHome"
        const val EXTRA_NATIVE_LIBRARY_DIR = "nativeLibraryDir"
        const val RESULT_FILE = "runtime-probe-result.txt"
        const val DIAGNOSTIC_FILE = "jvm_startup.log"

        init {
            System.loadLibrary("droidforge_runtime")
        }
    }

    private external fun nativeProbeEmbeddedJvm(
        javaHome: String,
        nativeLibraryDir: String,
        diagnosticPath: String,
    ): HashMap<String, Any>

    private val executor = Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_PROBE) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val javaHome = intent.getStringExtra(EXTRA_JAVA_HOME).orEmpty()
        val nativeLibraryDir = intent.getStringExtra(EXTRA_NATIVE_LIBRARY_DIR).orEmpty()
        val resultFile = File(filesDir, RESULT_FILE)
        val diagnosticFile = File(filesDir, DIAGNOSTIC_FILE)
        resultFile.delete()
        diagnosticFile.delete()

        executor.execute {
            val text = try {
                val result = nativeProbeEmbeddedJvm(javaHome, nativeLibraryDir, diagnosticFile.absolutePath)
                val exitCode = (result["exitCode"] as? Number)?.toInt() ?: -1
                val stdout = result["stdout"]?.toString().orEmpty()
                val stderr = result["stderr"]?.toString().orEmpty()
                listOf(exitCode.toString(), encode(stdout), encode(stderr)).joinToString("\n")
            } catch (error: Throwable) {
                listOf("-1", "", encode("${error.javaClass.name}: ${error.message.orEmpty()}"))
                    .joinToString("\n")
            }

            runCatching { resultFile.writeText(text) }
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun encode(value: String): String =
        android.util.Base64.encodeToString(value.toByteArray(Charsets.UTF_8), android.util.Base64.NO_WRAP)
}
