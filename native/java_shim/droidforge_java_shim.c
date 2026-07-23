#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *file_name(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash == NULL ? path : slash + 1;
}

int main(int argc, char **argv) {
    const char *real_java = getenv("DROIDFORGE_REAL_JAVA");
    const char *java_home = getenv("JAVA_HOME");

    if (real_java == NULL || real_java[0] == '\0') {
        fprintf(stderr, "DROIDFORGE_REAL_JAVA is not configured\n");
        return 64;
    }

    if (java_home == NULL || java_home[0] == '\0') {
        fprintf(stderr, "JAVA_HOME is not configured\n");
        return 65;
    }

    const char *requested_tool = file_name(argv[0]);
    const int use_javac = strcmp(requested_tool, "javac") == 0;

    char *real_tool = NULL;

    if (use_javac) {
        const char *java_suffix = "/bin/java";
        const size_t real_java_length = strlen(real_java);
        const size_t suffix_length = strlen(java_suffix);

        if (real_java_length >= suffix_length &&
            strcmp(real_java + real_java_length - suffix_length,
                   java_suffix) == 0) {
            const size_t prefix_length = real_java_length - strlen("java");
            real_tool = malloc(prefix_length + strlen("javac") + 1);

            if (real_tool == NULL) {
                fprintf(stderr, "Unable to allocate javac path\n");
                return 66;
            }

            memcpy(real_tool, real_java, prefix_length);
            strcpy(real_tool + prefix_length, "javac");
        } else {
            const size_t path_length =
                strlen(java_home) + strlen("/bin/javac") + 1;

            real_tool = malloc(path_length);

            if (real_tool == NULL) {
                fprintf(stderr, "Unable to allocate javac path\n");
                return 67;
            }

            snprintf(real_tool, path_length, "%s/bin/javac", java_home);
        }
    } else {
        real_tool = strdup(real_java);

        if (real_tool == NULL) {
            fprintf(stderr, "Unable to allocate java path\n");
            return 68;
        }
    }

    const char *linker = "/system/bin/linker64";

    if (use_javac) {
        /*
         * Android linker layout:
         *
         * linker64 REAL_JAVAC REAL_JAVAC original-arguments...
         */
        char **command = calloc((size_t)argc + 3, sizeof(char *));

        if (command == NULL) {
            fprintf(stderr, "Unable to allocate javac command\n");
            free(real_tool);
            return 69;
        }

        command[0] = (char *)linker;
        command[1] = real_tool;
        command[2] = real_tool;

        for (int index = 1; index < argc; index++) {
            command[index + 2] = argv[index];
        }

        command[argc + 2] = NULL;

        execv(linker, command);

        fprintf(
            stderr,
            "execv(%s) for javac failed: %s\n",
            linker,
            strerror(errno)
        );

        free(command);
        free(real_tool);
        return 70;
    }

    const char *property_prefix = "-Djava.home=";
    const size_t property_length =
        strlen(property_prefix) + strlen(java_home) + 1;

    char *java_home_property = malloc(property_length);

    if (java_home_property == NULL) {
        fprintf(stderr, "Unable to allocate java.home property\n");
        free(real_tool);
        return 71;
    }

    snprintf(
        java_home_property,
        property_length,
        "%s%s",
        property_prefix,
        java_home
    );

    /*
     * Android linker layout:
     *
     * linker64 REAL_JAVA REAL_JAVA -Djava.home=JAVA_HOME arguments...
     */
    char **command = calloc((size_t)argc + 4, sizeof(char *));

    if (command == NULL) {
        fprintf(stderr, "Unable to allocate Java command\n");
        free(java_home_property);
        free(real_tool);
        return 72;
    }

    command[0] = (char *)linker;
    command[1] = real_tool;
    command[2] = real_tool;
    command[3] = java_home_property;

    for (int index = 1; index < argc; index++) {
        command[index + 3] = argv[index];
    }

    command[argc + 3] = NULL;

    execv(linker, command);

    fprintf(
        stderr,
        "execv(%s) for java failed: %s\n",
        linker,
        strerror(errno)
    );

    free(command);
    free(java_home_property);
    free(real_tool);
    return 73;
}
