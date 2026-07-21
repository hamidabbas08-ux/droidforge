#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *real_java = getenv("DROIDFORGE_REAL_JAVA");

    if (real_java == NULL || real_java[0] == '\0') {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: "
            "DROIDFORGE_REAL_JAVA is not set\n"
        );
        return 126;
    }

    const char *linker = "/system/bin/linker64";

    /*
     * New command:
     * /system/bin/linker64 REAL_JAVA original-arguments...
     */
    char **command = calloc((size_t)argc + 2, sizeof(char *));

    if (command == NULL) {
        fprintf(
            stderr,
            "DROIDFORGE_JAVA_SHIM_ERROR: calloc failed: %s\n",
            strerror(errno)
        );
        return 125;
    }

    command[0] = (char *)linker;
    command[1] = (char *)real_java;

    for (int index = 1; index < argc; index++) {
        command[index + 1] = argv[index];
    }

    command[argc + 1] = NULL;

    execv(linker, command);

    fprintf(
        stderr,
        "DROIDFORGE_JAVA_SHIM_ERROR: "
        "execv(%s) failed: %s\n",
        linker,
        strerror(errno)
    );

    free(command);
    return 127;
}
