package com.hamid.droidforge

import android.os.Build
import android.os.Looper
import android.system.Os
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        init {
            System.loadLibrary("droidforge_runtime")
        }
    }

    private external fun nativeHealthCheck(): String
    private external fun nativeLaunchJava(javaHome: String, nativeLibraryDir: String): HashMap<String, Any>
    private val executor = Executors.newCachedThreadPool()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hamid.droidforge/runtime"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "runtimeInfo" -> result.success(runtimeInfoMap())
                "prepareEnvironment" -> executor.execute {
                    try {
                        val layout = prepareEnvironment()
                        runOnUiThread { result.success(layout) }
                    } catch (error: Throwable) {
                        runOnUiThread {
                            result.error("ENVIRONMENT_FAILED", safeMessage(error), null)
                        }
                    }
                }
                "foundationHealthCheck" -> executor.execute {
                    val report = runFoundationHealthCheck()
                    runOnUiThread { result.success(report) }
                }
                "chmodExecutable" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("BAD_ARGUMENT", "Missing executable path", null)
                    } else {
                        try {
                            Os.chmod(path, 448) // 0700
                            result.success(null)
                        } catch (error: Throwable) {
                            result.error("CHMOD_FAILED", safeMessage(error), null)
                        }
                    }
                }
                "prepareEmbeddedJdk" -> executor.execute {
                    try {
                        val javaHome = prepareEmbeddedJdk()
                        runOnUiThread { result.success(javaHome) }
                    } catch (error: Throwable) {
                        runOnUiThread {
                            result.error("EMBEDDED_JDK_PREPARE_FAILED", safeMessage(error), error.javaClass.name)
                        }
                    }
                }
                "startEmbeddedJvm" -> {
                    val javaHome = call.argument<String>("javaHome")
                    if (javaHome.isNullOrBlank()) {
                        result.error("BAD_ARGUMENT", "Missing JAVA_HOME", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        val vmResult = probeEmbeddedJvmSafely(javaHome)
                        runOnUiThread { result.success(vmResult) }
                    }
                }
                "launchJava" -> {
                    val javaHome = call.argument<String>("javaHome")
                    if (javaHome.isNullOrBlank()) {
                        result.error("BAD_ARGUMENT", "Missing JAVA_HOME", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val processResult = nativeLaunchJava(
                                javaHome,
                                applicationInfo.nativeLibraryDir
                            )
                            runOnUiThread { result.success(processResult) }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("JAVA_LAUNCH_FAILED", safeMessage(error), error.javaClass.name)
                            }
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
                            val processResult = runProcess(
                                executable,
                                arguments,
                                workingDirectory,
                                environment
                            )
                            runOnUiThread { result.success(processResult) }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("PROCESS_FAILED", safeMessage(error), error.javaClass.name)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }


    private fun probeEmbeddedJvmSafely(javaHome: String): HashMap<String, Any> {
        val resultFile = File(filesDir, RuntimeProbeService.RESULT_FILE)
        resultFile.delete()

        val intent = android.content.Intent(this, RuntimeProbeService::class.java).apply {
            action = RuntimeProbeService.ACTION_PROBE
            putExtra(RuntimeProbeService.EXTRA_JAVA_HOME, javaHome)
            putExtra(RuntimeProbeService.EXTRA_NATIVE_LIBRARY_DIR, applicationInfo.nativeLibraryDir)
        }

        val started = try {
            startService(intent) != null
        } catch (error: Throwable) {
            return hashMapOf(
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to "Could not start isolated JVM probe: ${safeMessage(error)}",
            )
        }
        if (!started) {
            return hashMapOf(
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to "Android refused to start the isolated JVM probe service.",
            )
        }

        val deadline = System.currentTimeMillis() + 20_000L
        while (System.currentTimeMillis() < deadline) {
            if (resultFile.exists()) {
                return try {
                    val lines = resultFile.readLines()
                    hashMapOf(
                        "exitCode" to (lines.getOrNull(0)?.toIntOrNull() ?: -1),
                        "stdout" to decodeProbeValue(lines.getOrNull(1).orEmpty()),
                        "stderr" to decodeProbeValue(lines.getOrNull(2).orEmpty()),
                    )
                } catch (error: Throwable) {
                    hashMapOf(
                        "exitCode" to -1,
                        "stdout" to "",
                        "stderr" to "Invalid isolated JVM probe result: ${safeMessage(error)}",
                    )
                } finally {
                    resultFile.delete()
                }
            }
            Thread.sleep(100L)
        }

        return hashMapOf(
            "exitCode" to 134,
            "stdout" to "",
            "stderr" to "The isolated JVM process stopped or timed out. DroidForge remained open safely.",
        )
    }

    private fun decodeProbeValue(value: String): String = try {
        String(android.util.Base64.decode(value, android.util.Base64.DEFAULT), Charsets.UTF_8)
    } catch (_: Throwable) {
        value
    }

    private fun runtimeInfoMap(): Map<String, Any> = mapOf(
        "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"),
        "nativeLibraryDir" to applicationInfo.nativeLibraryDir,
        "filesDir" to filesDir.absolutePath,
        "cacheDir" to cacheDir.absolutePath,
        "sdkInt" to Build.VERSION.SDK_INT
    )

    private fun prepareEnvironment(): Map<String, String> {
        val root = File(filesDir, "DroidForge/runtime")
        val layout = linkedMapOf(
            "root" to root,
            "home" to File(root, "home"),
            "tmp" to File(cacheDir, "droidforge-tmp"),
            "downloads" to File(root, "downloads"),
            "payloads" to File(root, "payloads"),
            "logs" to File(root, "logs"),
            "jdk" to File(root, "jdk"),
            "sdk" to File(root, "sdk"),
            "gradle" to File(root, "gradle")
        )
        layout.values.forEach { directory ->
            if (!directory.exists() && !directory.mkdirs()) {
                error("Could not create ${directory.absolutePath}")
            }
        }
        return layout.mapValues { it.value.absolutePath }
    }

    private fun prepareEmbeddedJdk(): String {
        val javaHome = File(filesDir, "DroidForge/runtime/jdk/jdk17-embedded")
        val marker = File(javaHome, ".foundation-ready")
        val expectedFoundationVersion = "v11.9"
        val installedFoundationVersion = marker.takeIf { it.isFile }?.readText()?.trim()

        if (installedFoundationVersion != expectedFoundationVersion || !embeddedJdkImageIsComplete(javaHome)) {
            if (javaHome.exists() && !javaHome.deleteRecursively()) {
                error("Could not remove previous embedded JDK")
            }
            if (!javaHome.mkdirs() && !javaHome.isDirectory) {
                error("Could not create embedded JDK directory")
            }

            copyEmbeddedJdkFromManifest(javaHome)
            installNativeRuntimeLibraries(javaHome)

            val verificationErrors = embeddedJdkVerificationErrors(javaHome)
            if (verificationErrors.isNotEmpty()) {
                marker.delete()
                error("Embedded JDK extraction verification failed: " + verificationErrors.joinToString("; "))
            }
            marker.writeText(expectedFoundationVersion)
        } else {
            installNativeRuntimeLibraries(javaHome)
        }

        File(javaHome, "tmp").mkdirs()
        return javaHome.absolutePath
    }

    private fun copyEmbeddedJdkFromManifest(javaHome: File) {
        val entries = assets.open("jdk17/asset-files.txt", android.content.res.AssetManager.ACCESS_STREAMING)
            .bufferedReader()
            .useLines { lines ->
                lines.map { it.trim() }
                    .filter { it.isNotEmpty() && it != "asset-files.txt" }
                    .toList()
            }

        if (entries.isEmpty()) error("Embedded JDK asset manifest is empty")

        entries.forEach { relativePath ->
            val destination = File(javaHome, relativePath)
            destination.parentFile?.mkdirs()
            val temporary = File(destination.parentFile, destination.name + ".part")
            if (temporary.exists()) temporary.delete()

            assets.open("jdk17/$relativePath", android.content.res.AssetManager.ACCESS_STREAMING).use { input ->
                FileOutputStream(temporary).use { output ->
                    input.copyTo(output, 1024 * 1024)
                    output.fd.sync()
                }
            }

            if (destination.exists()) destination.delete()
            if (!temporary.renameTo(destination)) {
                temporary.copyTo(destination, overwrite = true)
                temporary.delete()
            }
        }
    }

    private fun installNativeRuntimeLibraries(javaHome: File) {
        val libDir = File(javaHome, "lib").apply { mkdirs() }
        val serverDir = File(libDir, "server").apply { mkdirs() }
        val nativeNames = assets.open("jdk17/native-libs.txt").bufferedReader().useLines { it.toList() }

        nativeNames.filter { it.isNotBlank() }.forEach { name ->
            val source = File(applicationInfo.nativeLibraryDir, name)
            val destination = if (name == "libjvm.so") File(serverDir, name) else File(libDir, name)
            if (!source.isFile) error("APK native library missing: $name")
            val temporary = File(destination.parentFile, destination.name + ".part")
            source.inputStream().use { input ->
                FileOutputStream(temporary).use { output ->
                    input.copyTo(output, 1024 * 1024)
                    output.fd.sync()
                }
            }
            if (destination.exists()) destination.delete()
            if (!temporary.renameTo(destination)) {
                temporary.copyTo(destination, overwrite = true)
                temporary.delete()
            }
            destination.setReadable(true, false)
            destination.setExecutable(true, false)
        }
    }

    private fun embeddedJdkImageIsComplete(javaHome: File): Boolean =
        embeddedJdkVerificationErrors(javaHome).isEmpty()

    private fun embeddedJdkVerificationErrors(javaHome: File): List<String> {
        val errors = mutableListOf<String>()
        val expectedModulesSize = 128_712_865L
        val modules = File(javaHome, "lib/modules")
        val release = File(javaHome, "release")
        val javaSecurity = File(javaHome, "conf/security/java.security")
        val libJvm = File(javaHome, "lib/server/libjvm.so")

        if (!modules.isFile) {
            errors += "lib/modules missing"
        } else if (modules.length() != expectedModulesSize) {
            errors += "lib/modules size=${modules.length()} expected=$expectedModulesSize"
        }
        if (!release.isFile) errors += "release missing"
        if (!javaSecurity.isFile) errors += "conf/security/java.security missing"
        if (!libJvm.isFile) {
            errors += "lib/server/libjvm.so missing (nativeLibraryDir=${applicationInfo.nativeLibraryDir})"
        } else if (libJvm.length() < 1_000_000L) {
            errors += "lib/server/libjvm.so incomplete size=${libJvm.length()}"
        }

        return errors
    }

    private fun File.isSymbolicLink(): Boolean = try {
        Os.readlink(absolutePath)
        true
    } catch (_: Throwable) {
        false
    }

    private fun copyAssetTree(assetPath: String, destination: File) {
        val children = assets.list(assetPath) ?: emptyArray()
        if (children.isEmpty()) {
            destination.parentFile?.mkdirs()
            assets.open(assetPath).use { input ->
                FileOutputStream(destination).use { output -> input.copyTo(output, 1024 * 1024) }
            }
            return
        }
        destination.mkdirs()
        children.forEach { child ->
            copyAssetTree("$assetPath/$child", File(destination, child))
        }
    }

    private fun runFoundationHealthCheck(): Map<String, Any> {
        val logs = mutableListOf<String>()
        val checks = linkedMapOf<String, Boolean>()
        val details = linkedMapOf<String, String>()

        fun record(name: String, passed: Boolean, detail: String) {
            checks[name] = passed
            details[name] = detail
            logs += "${if (passed) "PASS" else "FAIL"}: $name — $detail"
        }

        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
        record("arm64", abi == "arm64-v8a", "Detected ABI: $abi")

        try {
            val nativeResult = nativeHealthCheck()
            record(
                "nativeLibrary",
                nativeResult.startsWith("droidforge-native-ok") && nativeResult.contains("arch=arm64"),
                nativeResult
            )
        } catch (error: Throwable) {
            record("nativeLibrary", false, safeMessage(error))
        }

        record(
            "backgroundWorker",
            Looper.myLooper() != Looper.getMainLooper(),
            "Health check thread: ${Thread.currentThread().name}"
        )

        val layout = try {
            prepareEnvironment().also {
                record("directoryLayout", true, "Created ${it.size} runtime directories")
            }
        } catch (error: Throwable) {
            record("directoryLayout", false, safeMessage(error))
            emptyMap()
        }

        try {
            val tmpPath = layout["tmp"] ?: cacheDir.absolutePath
            val probe = File(tmpPath, "foundation-probe-${System.nanoTime()}.txt")
            val expected = "droidforge-file-io-ok"
            probe.writeText(expected)
            val actual = probe.readText()
            val deleted = probe.delete()
            record("fileIo", actual == expected && deleted, "Write/read/delete test completed")
        } catch (error: Throwable) {
            record("fileIo", false, safeMessage(error))
        }

        try {
            val process = runProcess(
                "/system/bin/sh",
                listOf("-c", "printf droidforge-process-ok"),
                layout["home"],
                mapOf(
                    "HOME" to (layout["home"] ?: filesDir.absolutePath),
                    "TMPDIR" to (layout["tmp"] ?: cacheDir.absolutePath),
                    "PATH" to "/system/bin:/system/xbin"
                )
            )
            val stdout = process["stdout"] as? String ?: ""
            val exitCode = process["exitCode"] as? Int ?: -1
            record(
                "processRunner",
                exitCode == 0 && stdout == "droidforge-process-ok",
                "exit=$exitCode stdout=$stdout"
            )
        } catch (error: Throwable) {
            record("processRunner", false, safeMessage(error))
        }

        val required = listOf(
            "arm64",
            "nativeLibrary",
            "backgroundWorker",
            "directoryLayout",
            "fileIo",
            "processRunner"
        )
        val ready = required.all { checks[it] == true }
        return mapOf(
            "ready" to ready,
            "checks" to checks,
            "details" to details,
            "logs" to logs,
            "environment" to layout,
            "runtimeInfo" to runtimeInfoMap()
        )
    }

    private fun runProcess(
        executable: String,
        arguments: List<String>,
        workingDirectory: String?,
        environment: Map<String, String>
    ): Map<String, Any> {
        val command = mutableListOf(executable)
        command.addAll(arguments)
        val builder = ProcessBuilder(command)
        if (!workingDirectory.isNullOrBlank()) {
            builder.directory(File(workingDirectory))
        }
        builder.environment().putAll(environment)
        val process = builder.start()

        val stdoutFuture = executor.submit<String> {
            process.inputStream.bufferedReader().use { it.readText() }
        }
        val stderrFuture = executor.submit<String> {
            process.errorStream.bufferedReader().use { it.readText() }
        }
        val exitCode = process.waitFor()
        return mapOf(
            "exitCode" to exitCode,
            "stdout" to stdoutFuture.get(),
            "stderr" to stderrFuture.get()
        )
    }

    private fun safeMessage(error: Throwable): String =
        error.message?.take(500) ?: error.javaClass.simpleName

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }
}
