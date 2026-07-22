# V12.1 Gradle Java Home Shim Fix

The packaged ARM64 Java shim now injects `-Djava.home=$JAVA_HOME` before all
original JVM arguments.

This prevents Gradle's JVM installation probe from resolving the executable
back to the real app-private JDK path. Gradle should now retain the synthetic
`gradle-java-home` path and launch its daemon through:

`fake JAVA_HOME/bin/java -> packaged shim -> /system/bin/linker64 -> real java`

Expected daemon command prefix:

`.../DroidForge/runtime/gradle-java-home/bin/java`
