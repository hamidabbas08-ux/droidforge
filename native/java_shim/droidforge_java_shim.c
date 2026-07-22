#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *real_java = getenv("DROIDFORGE_REAL_JAVA");
    const char *java_home = getenv("JAVA_HOME");

    if (real_java == NULL || real_java[0] == '\0') {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: "
            "DROIDFORGE_REAL_JAVA is not set\n"
        );
        return 126;
    }

    if (java_home == NULL || java_home[0] == '\0') {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: JAVA_HOME is not set\n"
        );
        return 126;
    }

    const char *linker = "/system/bin/linker64";
    const char *property_prefix = "-Djava.home=";
    const size_t property_length =
        strlen(property_prefix) + strlen(java_home) + 1;

    char *java_home_property = malloc(property_length);

    if (java_home_property == NULL) {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: malloc failed: %s\n",
            strerror(errno)
        );
        return 125;
    }

    snprintf(
        java_home_property,
        property_length,
        "%s%s",
        property_prefix,
        java_home
    );

    /*
     * New command:
     * /system/bin/linker64 REAL_JAVA -Djava.home=JAVA_HOME original-arguments...
     *
     * The explicit java.home value is essential. Without it, Gradle probes the
     * real executable and records the app-private JDK path, then tries to launch
     * that path directly and Android rejects it with error=13. Reporting the
     * synthetic JAVA_HOME keeps Gradle daemon launches routed through this shim.
     */
    /*
     * Android linker64 requires:
     *
     * linker64 REAL_JAVA REAL_JAVA java-arguments...
     *
     * The second REAL_JAVA becomes argv[0] for the Java launcher.
     * Without it, -Djava.home becomes argv[0] and Java reports:
     * expected absolute path: "-Djava.home=..."
     */
    char **command = calloc((size_t)argc + 4, sizeof(char *));

    if (command == NULL) {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: calloc failed: %s\n",
            strerror(errno)
        );
        free(java_home_property);
        return 125;
    }

    command[0] = (char *)linker;
    command[1] = (char *)real_java;
    command[2] = (char *)real_java;
    command[3] = java_home_property;

    for (int index = 1; index < argc; index++) {
        command[index + 3] = argv[index];
    }

    command[argc + 3] = NULL;

    execv(linker, command);

    fprintf(
        stderr,
        "DROIDFORGE_JAVA_SHIM_ERROR: "
        "execv(%s) failed: %s\n",
        linker,
        strerror(errno)
    );

    free(command);
    free(java_home_property);
    return 127;
}
