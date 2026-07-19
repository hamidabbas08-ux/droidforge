#include <jni.h>
#include <unistd.h>
#include <string>

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
