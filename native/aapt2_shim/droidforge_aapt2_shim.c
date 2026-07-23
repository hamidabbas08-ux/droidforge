#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *real_aapt2 = getenv("DROIDFORGE_REAL_AAPT2");

    if (real_aapt2 == NULL || real_aapt2[0] == '\0') {
        fprintf(
            stderr,
            "DROIDFORGE_REAL_AAPT2 is not configured\n"
        );
        return 64;
    }

    const char *linker = "/system/bin/linker64";

    /*
     * Android linker command layout:
     *
     * linker64 REAL_AAPT2 REAL_AAPT2 original-arguments...
     */
    char **command = calloc((size_t)argc + 3, sizeof(char *));

    if (command == NULL) {
        fprintf(stderr, "Unable to allocate AAPT2 command\n");
        return 65;
    }

    command[0] = (char *)linker;
    command[1] = (char *)real_aapt2;
    command[2] = (char *)real_aapt2;

    for (int index = 1; index < argc; index++) {
        command[index + 2] = argv[index];
    }

    command[argc + 2] = NULL;

    execv(linker, command);

    fprintf(
        stderr,
        "execv(%s) for AAPT2 failed: %s\n",
        linker,
        strerror(errno)
    );

    free(command);
    return 66;
}
