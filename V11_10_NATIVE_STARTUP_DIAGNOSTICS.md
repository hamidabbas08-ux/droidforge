# V11.10 Native JVM Startup Diagnostics

The isolated runtime process now writes each native JVM startup stage to
`filesDir/jvm_startup.log` using synchronous native writes. If HotSpot crashes
or hangs inside `JNI_CreateJavaVM`, the UI reports the last completed stage.
