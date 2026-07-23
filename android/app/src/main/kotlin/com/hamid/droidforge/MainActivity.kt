package com.hamid.droidforge

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    companion object {
        private const val PROCESS_CHANNEL = "com.hamid.droidforge/process"
        private const val MAX_OUTPUT_CHARS = 200_000
    }

    private val processExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROCESS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBundledPointerTagDisablerPath" -> {
                    val library = java.io.File(
                        applicationInfo.nativeLibraryDir,
                        "libdroidforge_disable_tags.so"
                    )

                    if (!library.exists()) {
                        result.error(
                            "POINTER_TAG_LIBRARY_NOT_FOUND",
                            "Bundled pointer-tag library not found: ${library.absolutePath}",
                            null
                        )
                    } else {
                        result.success(library.absolutePath)
                    }
                }

                "getBundledJavaShimPath" -> {
                    val shim = java.io.File(
                        applicationInfo.nativeLibraryDir,
                        "libdroidforge_java_shim.so"
                    )

                    if (!shim.exists()) {
                        result.error(
                            "JAVA_SHIM_NOT_FOUND",
                            "Bundled Java shim not found: ${shim.absolutePath}",
                            null
                        )
                    } else {
                        result.success(shim.absolutePath)
                    }
                }

                "getBundledAapt2ShimPath" -> {
                    val packagedShim = java.io.File(
                        applicationInfo.nativeLibraryDir,
                        "libdroidforge_aapt2_shim.so"
                    )

                    if (!packagedShim.isFile || packagedShim.length() <= 0L) {
                        result.error(
                            "AAPT2_SHIM_NOT_FOUND",
                            "Bundled AAPT2 shim not found or empty: " +
                                packagedShim.absolutePath,
                            null
                        )
                    } else {
                        try {
                            val runtimeToolsDirectory = java.io.File(
                                filesDir,
                                "DroidForge/runtime-tools"
                            )

                            if (!runtimeToolsDirectory.exists() &&
                                !runtimeToolsDirectory.mkdirs()
                            ) {
                                throw java.io.IOException(
                                    "Could not create directory: " +
                                        runtimeToolsDirectory.absolutePath
                                )
                            }

                            val finalShim = java.io.File(
                                runtimeToolsDirectory,
                                "aapt2"
                            )

                            val temporaryShim = java.io.File(
                                runtimeToolsDirectory,
                                "aapt2.tmp"
                            )

                            if (temporaryShim.exists() &&
                                !temporaryShim.delete()
                            ) {
                                throw java.io.IOException(
                                    "Could not remove old temporary AAPT2: " +
                                        temporaryShim.absolutePath
                                )
                            }

                            packagedShim.copyTo(
                                target = temporaryShim,
                                overwrite = true
                            )

                            if (temporaryShim.length() != packagedShim.length()) {
                                throw java.io.IOException(
                                    "AAPT2 copy size mismatch: source=" +
                                        packagedShim.length() +
                                        ", copied=" +
                                        temporaryShim.length()
                                )
                            }

                            if (!temporaryShim.setReadable(true, false)) {
                                throw java.io.IOException(
                                    "Could not make AAPT2 readable."
                                )
                            }

                            if (!temporaryShim.setWritable(true, true)) {
                                throw java.io.IOException(
                                    "Could not make AAPT2 writable."
                                )
                            }

                            if (!temporaryShim.setExecutable(true, false)) {
                                throw java.io.IOException(
                                    "Could not make AAPT2 executable."
                                )
                            }

                            if (finalShim.exists() && !finalShim.delete()) {
                                throw java.io.IOException(
                                    "Could not replace old AAPT2: " +
                                        finalShim.absolutePath
                                )
                            }

                            if (!temporaryShim.renameTo(finalShim)) {
                                temporaryShim.copyTo(
                                    target = finalShim,
                                    overwrite = true
                                )

                                if (!temporaryShim.delete()) {
                                    temporaryShim.deleteOnExit()
                                }
                            }

                            finalShim.setReadable(true, false)
                            finalShim.setWritable(true, true)
                            finalShim.setExecutable(true, false)

                            if (!finalShim.isFile || finalShim.length() <= 0L) {
                                throw java.io.IOException(
                                    "Final AAPT2 executable was not created: " +
                                        finalShim.absolutePath
                                )
                            }

                            result.success(finalShim.absolutePath)
                        } catch (error: Throwable) {
                            result.error(
                                "AAPT2_SHIM_PREPARE_FAILED",
                                error.message ?: error.toString(),
                                null
                            )
                        }
                    }
                }

                "runBundledNativeTest" -> {
                    processExecutor.execute {
                        try {
                            val executable = java.io.File(
                                applicationInfo.nativeLibraryDir,
                                "libdroidforge_exec.so"
                            )

                            if (!executable.exists()) {
                                throw java.io.FileNotFoundException(
                                    "Bundled native executable not found: ${executable.absolutePath}"
                                )
                            }

                            val response = runProcess(
                                executable = executable.absolutePath,
                                arguments = listOf(
                                    "DroidForge",
                                    "ARM64",
                                    "Native-Test"
                                ),
                                workingDirectory = executable.parent,
                                environment = mapOf(
                                    "JAVA_HOME" to filesDir.absolutePath,
                                    "TMPDIR" to cacheDir.absolutePath
                                ),
                                timeoutSeconds = 30
                            )

                            mainHandler.post {
                                result.success(response)
                            }
                        } catch (error: Throwable) {
                            mainHandler.post {
                                result.error(
                                    "NATIVE_TEST_FAILED",
                                    error.message ?: error.javaClass.simpleName,
                                    error.stackTraceToString()
                                )
                            }
                        }
                    }
                }

                "runProcess" -> {
                    val executable = call.argument<String>("executable")
                    val arguments =
                        call.argument<List<String>>("arguments") ?: emptyList()
                    val workingDirectory =
                        call.argument<String>("workingDirectory")
                    val environment =
                        call.argument<Map<String, String>>("environment")
                            ?: emptyMap()
                    val timeoutSeconds =
                        call.argument<Int>("timeoutSeconds") ?: 30

                    if (executable.isNullOrBlank()) {
                        result.error(
                            "INVALID_EXECUTABLE",
                            "Executable path is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    processExecutor.execute {
                        try {
                            val response = runProcess(
                                executable = executable,
                                arguments = arguments,
                                workingDirectory = workingDirectory,
                                environment = environment,
                                timeoutSeconds = timeoutSeconds.coerceIn(1, 3600)
                            )

                            mainHandler.post {
                                result.success(response)
                            }
                        } catch (error: Throwable) {
                            mainHandler.post {
                                result.error(
                                    "PROCESS_EXECUTION_FAILED",
                                    error.message ?: error.javaClass.simpleName,
                                    error.stackTraceToString()
                                )
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun runProcess(
        executable: String,
        arguments: List<String>,
        workingDirectory: String?,
        environment: Map<String, String>,
        timeoutSeconds: Int
    ): Map<String, Any?> {
        val command = mutableListOf(executable)
        command.addAll(arguments)

        val builder = ProcessBuilder(command)

        if (!workingDirectory.isNullOrBlank()) {
            builder.directory(java.io.File(workingDirectory))
        }

        builder.environment().putAll(environment)
        builder.redirectErrorStream(false)

        val startedAt = System.nanoTime()
        val process = builder.start()

        val stdoutFuture = processExecutor.submit<String> {
            readStream(process.inputStream)
        }

        val stderrFuture = processExecutor.submit<String> {
            readStream(process.errorStream)
        }

        val deadline =
            System.nanoTime() + TimeUnit.SECONDS.toNanos(timeoutSeconds.toLong())

        var timedOut = false
        var exitCode: Int? = null

        while (System.nanoTime() < deadline) {
            try {
                exitCode = process.exitValue()
                break
            } catch (_: IllegalThreadStateException) {
                Thread.sleep(100)
            }
        }

        if (exitCode == null) {
            timedOut = true
            process.destroy()

            Thread.sleep(300)

            try {
                exitCode = process.exitValue()
            } catch (_: IllegalThreadStateException) {
                process.destroyForcibly()
                exitCode = -1
            }
        }

        val stdout = try {
            stdoutFuture.get(5, TimeUnit.SECONDS)
        } catch (_: Throwable) {
            stdoutFuture.cancel(true)
            ""
        }

        val stderr = try {
            stderrFuture.get(5, TimeUnit.SECONDS)
        } catch (_: Throwable) {
            stderrFuture.cancel(true)
            ""
        }

        val durationMs =
            TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt)

        return mapOf(
            "command" to command,
            "exitCode" to exitCode,
            "stdout" to stdout,
            "stderr" to stderr,
            "timedOut" to timedOut,
            "durationMs" to durationMs
        )
    }

    private fun readStream(stream: InputStream): String {
        val output = StringBuilder()

        BufferedReader(InputStreamReader(stream)).use { reader ->
            val buffer = CharArray(4096)

            while (true) {
                val count = reader.read(buffer)

                if (count < 0) {
                    break
                }

                if (output.length < MAX_OUTPUT_CHARS) {
                    val remaining = MAX_OUTPUT_CHARS - output.length
                    output.append(buffer, 0, minOf(count, remaining))
                }
            }
        }

        return output.toString()
    }

    override fun onDestroy() {
        processExecutor.shutdownNow()
        super.onDestroy()
    }
}
