#include <jni.h>
#include <unistd.h>
#include <sys/wait.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <cerrno>
#include <cstring>
#include <string>
#include <vector>

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
    jstring nativeLibraryDirValue) {
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
