#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv) {
    printf("DROIDFORGE_NATIVE_EXEC_OK\n");
    printf("PID=%d\n", getpid());
    printf("ARGC=%d\n", argc);

    for (int i = 0; i < argc; i++) {
        printf("ARGV_%d=%s\n", i, argv[i]);
    }

    const char *java_home = getenv("JAVA_HOME");

    if (java_home != NULL) {
        printf("JAVA_HOME=%s\n", java_home);
    } else {
        printf("JAVA_HOME=NOT_SET\n");
    }

    fflush(stdout);
    return 0;
}
