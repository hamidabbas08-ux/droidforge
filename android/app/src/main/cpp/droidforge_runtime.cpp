#include <jni.h>
#include <unistd.h>
#include <sys/wait.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <string>
#include <vector>
#include <ctime>

extern "C" JNIEXPORT jstring JNICALL
Java_com_hamid_droidforge_MainActivity_nativeHealthCheck(
    JNIEnv* env,
    jobject /* thiz */) {
  std::string message = "droidforge-native-ok|pid=" + std::to_string(getpid());
#if defined(__aarch64__)
  message += "|arch=arm64";
#else
  message += "|arch=unsupported";
#endif
  return env->NewStringUTF(message.c_str());
}

using JliLaunch = int (*)(int, char**, int, const char**, int, const char**,
                          const char*, const char*, const char*, const char*,
                          jboolean, jboolean, jboolean, jint);

static std::string readAll(int fd) {
  std::string out;
  char buffer[4096];
  for (;;) {
    const ssize_t count = read(fd, buffer, sizeof(buffer));
    if (count > 0) {
      out.append(buffer, static_cast<size_t>(count));
      continue;
    }
    if (count < 0 && errno == EINTR) continue;
    break;
  }
  return out;
}

static void putString(JNIEnv* env, jobject map, jmethodID put,
                      const char* key, const std::string& value) {
  jstring jKey = env->NewStringUTF(key);
  jstring jValue = env->NewStringUTF(value.c_str());
  env->CallObjectMethod(map, put, jKey, jValue);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(jValue);
}

static void putInt(JNIEnv* env, jobject map, jmethodID put,
                   const char* key, int value) {
  jclass integerClass = env->FindClass("java/lang/Integer");
  jmethodID integerValueOf = env->GetStaticMethodID(
      integerClass, "valueOf", "(I)Ljava/lang/Integer;");
  jobject integer = env->CallStaticObjectMethod(integerClass, integerValueOf, value);
  jstring jKey = env->NewStringUTF(key);
  env->CallObjectMethod(map, put, jKey, integer);
  env->DeleteLocalRef(jKey);
  env->DeleteLocalRef(integer);
  env->DeleteLocalRef(integerClass);
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_hamid_droidforge_MainActivity_nativeLaunchJava(
    JNIEnv* env,
    jobject /* thiz */,
    jstring javaHomeValue,
    jstring nativeLibraryDirValue,
    jstring /* diagnosticPathValue */) {
  const char* javaHomeChars = env->GetStringUTFChars(javaHomeValue, nullptr);
  const char* nativeLibraryDirChars = env->GetStringUTFChars(nativeLibraryDirValue, nullptr);
  const std::string javaHome(javaHomeChars ? javaHomeChars : "");
  const std::string nativeLibraryDir(nativeLibraryDirChars ? nativeLibraryDirChars : "");
  env->ReleaseStringUTFChars(javaHomeValue, javaHomeChars);
  env->ReleaseStringUTFChars(nativeLibraryDirValue, nativeLibraryDirChars);

  int stdoutPipe[2] = {-1, -1};
  int stderrPipe[2] = {-1, -1};
  int exitCode = 127;
  std::string stdoutText;
  std::string stderrText;

  if (pipe(stdoutPipe) != 0 || pipe(stderrPipe) != 0) {
    stderrText = std::string("pipe failed: ") + std::strerror(errno);
  } else {
    const pid_t child = fork();
    if (child == 0) {
      close(stdoutPipe[0]);
      close(stderrPipe[0]);
      dup2(stdoutPipe[1], STDOUT_FILENO);
      dup2(stderrPipe[1], STDERR_FILENO);
      close(stdoutPipe[1]);
      close(stderrPipe[1]);

      setenv("JAVA_HOME", javaHome.c_str(), 1);
      const std::string libraryPath = javaHome + "/lib:" + javaHome + "/lib/server:" + nativeLibraryDir;
      setenv("LD_LIBRARY_PATH", libraryPath.c_str(), 1);
      setenv("TMPDIR", "/data/local/tmp", 0);

      const std::string jliPath = nativeLibraryDir + "/libjli.so";
      void* handle = dlopen(jliPath.c_str(), RTLD_NOW | RTLD_GLOBAL);
      if (!handle) {
        dprintf(STDERR_FILENO, "dlopen libjli failed: %s\n", dlerror());
        _exit(126);
      }
      auto launch = reinterpret_cast<JliLaunch>(dlsym(handle, "JLI_Launch"));
      if (!launch) {
        dprintf(STDERR_FILENO, "JLI_Launch not found: %s\n", dlerror());
        _exit(125);
      }

      const std::string javaPath = javaHome + "/bin/java";
      std::vector<std::string> values = {javaPath, "-version"};
      std::vector<char*> argv;
      argv.reserve(values.size());
      for (auto& value : values) argv.push_back(value.data());

      const int result = launch(
          static_cast<int>(argv.size()), argv.data(),
          0, nullptr, 0, nullptr,
          "17", "17", "java", "java",
          JNI_FALSE, JNI_FALSE, JNI_FALSE, 0);
      fflush(stdout);
      fflush(stderr);
      _exit(result);
    } else if (child < 0) {
      stderrText = std::string("fork failed: ") + std::strerror(errno);
      close(stdoutPipe[0]); close(stdoutPipe[1]);
      close(stderrPipe[0]); close(stderrPipe[1]);
    } else {
      close(stdoutPipe[1]);
      close(stderrPipe[1]);
      stdoutText = readAll(stdoutPipe[0]);
      stderrText = readAll(stderrPipe[0]);
      close(stdoutPipe[0]);
      close(stderrPipe[0]);
      int status = 0;
      while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
      if (WIFEXITED(status)) exitCode = WEXITSTATUS(status);
      else if (WIFSIGNALED(status)) exitCode = 128 + WTERMSIG(status);
    }
  }

  jclass mapClass = env->FindClass("java/util/HashMap");
  jmethodID ctor = env->GetMethodID(mapClass, "<init>", "()V");
  jmethodID put = env->GetMethodID(
      mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  jobject map = env->NewObject(mapClass, ctor);
  putInt(env, map, put, "exitCode", exitCode);
  putString(env, map, put, "stdout", stdoutText);
  putString(env, map, put, "stderr", stderrText);
  env->DeleteLocalRef(mapClass);
  return map;
}

using CreateJavaVm = jint (*)(JavaVM**, void**, void*);
static JavaVM* g_embedded_vm = nullptr;

static void appendDiagnostic(const std::string& path, const std::string& stage) {
  if (path.empty()) return;
  const int fd = open(path.c_str(), O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0600);
  if (fd < 0) return;
  timespec ts{};
  clock_gettime(CLOCK_REALTIME, &ts);
  const std::string line = std::to_string(ts.tv_sec) + "." +
      std::to_string(ts.tv_nsec / 1000000) + "|pid=" +
      std::to_string(getpid()) + "|" + stage + "\n";
  const char* data = line.data();
  size_t remaining = line.size();
  while (remaining > 0) {
    const ssize_t written = write(fd, data, remaining);
    if (written > 0) {
      data += written;
      remaining -= static_cast<size_t>(written);
    } else if (written < 0 && errno == EINTR) {
      continue;
    } else {
      break;
    }
  }
  fsync(fd);
  close(fd);
}

static std::string jstringToUtf8(JNIEnv* env, jstring value) {
  if (value == nullptr) return "";
  const char* chars = env->GetStringUTFChars(value, nullptr);
  std::string result(chars ? chars : "");
  if (chars) env->ReleaseStringUTFChars(value, chars);
  return result;
}

static std::string describeAndClearJavaException(JNIEnv* env) {
  if (!env->ExceptionCheck()) return "";
  jthrowable throwable = env->ExceptionOccurred();
  env->ExceptionClear();
  std::string message = "Embedded JVM raised an exception";
  jclass throwableClass = env->FindClass("java/lang/Throwable");
  if (throwableClass != nullptr) {
    jmethodID toString = env->GetMethodID(throwableClass, "toString", "()Ljava/lang/String;");
    if (toString != nullptr && throwable != nullptr) {
      auto text = static_cast<jstring>(env->CallObjectMethod(throwable, toString));
      if (!env->ExceptionCheck() && text != nullptr) message = jstringToUtf8(env, text);
      if (env->ExceptionCheck()) env->ExceptionClear();
      if (text != nullptr) env->DeleteLocalRef(text);
    }
    env->DeleteLocalRef(throwableClass);
  }
  if (throwable != nullptr) env->DeleteLocalRef(throwable);
  return message;
}

static jobject startEmbeddedJvmImpl(
    JNIEnv* artEnv,
    jstring javaHomeValue,
    jstring nativeLibraryDirValue,
    jstring diagnosticPathValue,
    jstring probeModeValue) {
  const std::string javaHome = jstringToUtf8(artEnv, javaHomeValue);
  const std::string nativeLibraryDir = jstringToUtf8(artEnv, nativeLibraryDirValue);
  const std::string diagnosticPath = jstringToUtf8(artEnv, diagnosticPathValue);
  const std::string probeMode = jstringToUtf8(artEnv, probeModeValue);
  appendDiagnostic(diagnosticPath, "01-native-entry mode=" + probeMode);
  appendDiagnostic(diagnosticPath, "02-java-home=" + javaHome);
  appendDiagnostic(diagnosticPath, "03-native-lib-dir=" + nativeLibraryDir);

  int exitCode = 1;
  std::string stdoutText;
  std::string stderrText;

  if (javaHome.empty() || nativeLibraryDir.empty()) {
    appendDiagnostic(diagnosticPath, "04-invalid-empty-path");
    stderrText = "JAVA_HOME or nativeLibraryDir is empty";
  } else {
    JNIEnv* jvmEnv = nullptr;
    if (g_embedded_vm != nullptr) {
      const jint attach = g_embedded_vm->AttachCurrentThread(&jvmEnv, nullptr);
      if (attach != JNI_OK) {
        stderrText = "Existing embedded JVM could not attach current thread: " + std::to_string(attach);
      }
    } else {
      const std::string runtimeLibDir = javaHome + "/lib";
      const std::string serverLibDir = runtimeLibDir + "/server";
      const std::string tmpDir = javaHome + "/tmp";
      const std::string libraryPath = serverLibDir + ":" + runtimeLibDir + ":" + nativeLibraryDir;
      setenv("JAVA_HOME", javaHome.c_str(), 1);
      setenv("HOME", javaHome.c_str(), 1);
      setenv("TMPDIR", tmpDir.c_str(), 1);
      setenv("LD_LIBRARY_PATH", libraryPath.c_str(), 1);
      appendDiagnostic(diagnosticPath, "04-environment-configured");
      if (chdir(javaHome.c_str()) != 0) {
        appendDiagnostic(diagnosticPath, "05-chdir-failed errno=" + std::to_string(errno));
      } else {
        appendDiagnostic(diagnosticPath, "05-chdir-success");
      }

      const std::vector<std::string> preloadNames = {
          "libjimage.so", "libjava.so", "libverify.so", "libzip.so"};
      for (const auto& name : preloadNames) {
        const std::string path = runtimeLibDir + "/" + name;
        appendDiagnostic(diagnosticPath, "06-preload-start " + name);
        void* preload = dlopen(path.c_str(), RTLD_NOW | RTLD_GLOBAL);
        if (preload == nullptr) {
          const char* error = dlerror();
          stderrText = "preload " + name + " failed: " + std::string(error ? error : "unknown");
          appendDiagnostic(diagnosticPath, "07-preload-failed " + name + "|" + stderrText);
          break;
        }
        appendDiagnostic(diagnosticPath, "07-preload-success " + name);
      }

      const std::string jvmPath = serverLibDir + "/libjvm.so";
      appendDiagnostic(diagnosticPath, "08-dlopen-libjvm-start " + jvmPath);
      void* handle = stderrText.empty() ? dlopen(jvmPath.c_str(), RTLD_NOW | RTLD_GLOBAL) : nullptr;
      if (handle == nullptr) {
        if (stderrText.empty()) {
          const char* error = dlerror();
          stderrText = std::string("dlopen libjvm failed: ") + (error ? error : "unknown");
        }
        appendDiagnostic(diagnosticPath, "09-dlopen-libjvm-failed|" + stderrText);
      } else {
        appendDiagnostic(diagnosticPath, "09-dlopen-libjvm-success");
        dlerror();
        auto createVm = reinterpret_cast<CreateJavaVm>(dlsym(handle, "JNI_CreateJavaVM"));
        if (createVm == nullptr) {
          const char* error = dlerror();
          stderrText = std::string("JNI_CreateJavaVM not found: ") + (error ? error : "unknown");
          appendDiagnostic(diagnosticPath, "10-dlsym-failed|" + stderrText);
        } else {
          appendDiagnostic(diagnosticPath, "10-dlsym-success");
          std::vector<std::string> optionStorage;
          bool ignoreUnrecognized = false;
          if (probeMode == "absolute-minimum") {
            // Final compatibility decision: only JAVA_HOME and a memory ceiling.
            optionStorage = {
                "-Djava.home=" + javaHome,
                "-Xmx128m",
            };
            ignoreUnrecognized = true;
          } else {
            // Test 1: smallest practical embedded JVM configuration.
            optionStorage = {
                "-Djava.home=" + javaHome,
                "-Djava.io.tmpdir=" + tmpDir,
                "-Xms16m",
                "-Xmx128m",
                "-Xrs",
            };
          }
          for (size_t i = 0; i < optionStorage.size(); ++i) {
            appendDiagnostic(diagnosticPath, "11-option[" + std::to_string(i) + "]=" + optionStorage[i]);
          }
          std::vector<JavaVMOption> options(optionStorage.size());
          for (size_t i = 0; i < optionStorage.size(); ++i) {
            options[i].optionString = optionStorage[i].data();
            options[i].extraInfo = nullptr;
          }
          JavaVMInitArgs args{};
          args.version = JNI_VERSION_1_6;
          args.nOptions = static_cast<jint>(options.size());
          args.options = options.data();
          args.ignoreUnrecognized = ignoreUnrecognized ? JNI_TRUE : JNI_FALSE;
          appendDiagnostic(diagnosticPath, "11-JNI_CreateJavaVM-call options=" + std::to_string(options.size()));
          const jint created = createVm(&g_embedded_vm, reinterpret_cast<void**>(&jvmEnv), &args);
          appendDiagnostic(diagnosticPath, "12-JNI_CreateJavaVM-return code=" + std::to_string(created));
          if (created != JNI_OK || g_embedded_vm == nullptr || jvmEnv == nullptr) {
            stderrText = "JNI_CreateJavaVM failed with code " + std::to_string(created);
            g_embedded_vm = nullptr;
          }
        }
      }
    }

    if (jvmEnv != nullptr && stderrText.empty()) {
      appendDiagnostic(diagnosticPath, "13-find-System-start");
      jclass systemClass = jvmEnv->FindClass("java/lang/System");
      if (systemClass == nullptr) {
        stderrText = describeAndClearJavaException(jvmEnv);
        appendDiagnostic(diagnosticPath, "14-find-System-failed|" + stderrText);
        if (stderrText.empty()) stderrText = "java/lang/System was not found";
      } else {
        appendDiagnostic(diagnosticPath, "14-find-System-success");
        jmethodID getProperty = jvmEnv->GetStaticMethodID(
            systemClass,
            "getProperty",
            "(Ljava/lang/String;)Ljava/lang/String;");
        if (getProperty == nullptr) {
          stderrText = describeAndClearJavaException(jvmEnv);
        appendDiagnostic(diagnosticPath, "14-find-System-failed|" + stderrText);
          if (stderrText.empty()) stderrText = "System.getProperty was not found";
        } else {
          jstring key = jvmEnv->NewStringUTF("java.version");
          auto value = static_cast<jstring>(jvmEnv->CallStaticObjectMethod(systemClass, getProperty, key));
          if (jvmEnv->ExceptionCheck()) {
            stderrText = describeAndClearJavaException(jvmEnv);
        appendDiagnostic(diagnosticPath, "14-find-System-failed|" + stderrText);
          } else {
            const std::string version = jstringToUtf8(jvmEnv, value);
            stdoutText = "embedded-jvm-ok|java.version=" + version;
            appendDiagnostic(diagnosticPath, "15-java-version=" + version);
            exitCode = version.empty() ? 2 : 0;
          }
          if (key != nullptr) jvmEnv->DeleteLocalRef(key);
          if (value != nullptr) jvmEnv->DeleteLocalRef(value);
        }
        jvmEnv->DeleteLocalRef(systemClass);
      }
    }
  }

  appendDiagnostic(diagnosticPath, "99-native-return exitCode=" + std::to_string(exitCode) + "|stderr=" + stderrText);
  jclass mapClass = artEnv->FindClass("java/util/HashMap");
  jmethodID ctor = artEnv->GetMethodID(mapClass, "<init>", "()V");
  jmethodID put = artEnv->GetMethodID(
      mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  jobject map = artEnv->NewObject(mapClass, ctor);
  putInt(artEnv, map, put, "exitCode", exitCode);
  putString(artEnv, map, put, "stdout", stdoutText);
  putString(artEnv, map, put, "stderr", stderrText);
  artEnv->DeleteLocalRef(mapClass);
  return map;
}


extern "C" JNIEXPORT jobject JNICALL
Java_com_hamid_droidforge_MainActivity_nativeStartEmbeddedJvm(
    JNIEnv* env,
    jobject /* thiz */,
    jstring javaHomeValue,
    jstring nativeLibraryDirValue,
    jstring diagnosticPathValue,
    jstring probeModeValue) {
  return startEmbeddedJvmImpl(env, javaHomeValue, nativeLibraryDirValue, diagnosticPathValue, probeModeValue);
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_hamid_droidforge_RuntimeProbeService_nativeProbeEmbeddedJvm(
    JNIEnv* env,
    jobject /* thiz */,
    jstring javaHomeValue,
    jstring nativeLibraryDirValue,
    jstring diagnosticPathValue,
    jstring probeModeValue) {
  return startEmbeddedJvmImpl(env, javaHomeValue, nativeLibraryDirValue, diagnosticPathValue, probeModeValue);
}
