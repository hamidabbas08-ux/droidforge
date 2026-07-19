package com.hamid.droidforge

import android.os.Build
import android.system.Os
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newCachedThreadPool()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hamid.droidforge/runtime"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "runtimeInfo" -> result.success(
                    mapOf(
                        "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"),
                        "nativeLibraryDir" to applicationInfo.nativeLibraryDir,
                        "filesDir" to filesDir.absolutePath,
                        "cacheDir" to cacheDir.absolutePath,
                        "sdkInt" to Build.VERSION.SDK_INT
                    )
                )

                "chmodExecutable" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("BAD_ARGUMENT", "Missing executable path", null)
                    } else {
                        try {
                            Os.chmod(path, 448) // 0700
                            result.success(null)
                        } catch (error: Throwable) {
                            result.error("CHMOD_FAILED", error.message, null)
                        }
                    }
                }

                "runProcess" -> {
                    val executable = call.argument<String>("executable")
                    val arguments = call.argument<List<String>>("arguments") ?: emptyList()
                    val workingDirectory = call.argument<String>("workingDirectory")
                    val environment = call.argument<Map<String, String>>("environment") ?: emptyMap()
                    if (executable.isNullOrBlank()) {
                        result.error("BAD_ARGUMENT", "Missing executable", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val command = mutableListOf(executable)
                            command.addAll(arguments)
                            val builder = ProcessBuilder(command)
                            if (!workingDirectory.isNullOrBlank()) {
                                builder.directory(File(workingDirectory))
                            }
                            builder.environment().putAll(environment)
                            val process = builder.start()
                            val stdout = process.inputStream.bufferedReader().use { it.readText() }
                            val stderr = process.errorStream.bufferedReader().use { it.readText() }
                            val exitCode = process.waitFor()
                            runOnUiThread {
                                result.success(
                                    mapOf(
                                        "exitCode" to exitCode,
                                        "stdout" to stdout,
                                        "stderr" to stderr
                                    )
                                )
                            }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("PROCESS_FAILED", error.message, error.javaClass.name)
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }
}
