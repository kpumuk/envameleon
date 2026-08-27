#include <ruby.h>

#ifdef __linux__
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void
read_env_range(unsigned long *env_start, unsigned long *env_end)
{
    char stat[4096];
    char *field;
    char *end;
    FILE *file = fopen("/proc/self/stat", "r");
    int number;

    if (file == NULL)
        rb_sys_fail("fopen(/proc/self/stat)");

    if (fgets(stat, sizeof(stat), file) == NULL) {
        int error = errno;
        fclose(file);
        if (error != 0) {
            errno = error;
            rb_sys_fail("fgets(/proc/self/stat)");
        }
        rb_raise(rb_eRuntimeError, "empty /proc/self/stat");
    }
    fclose(file);

    field = strrchr(stat, ')');
    if (field == NULL || field[1] != ' ')
        rb_raise(rb_eRuntimeError, "invalid /proc/self/stat");
    field += 2;

    for (number = 3; number < 50; number++) {
        field = strchr(field, ' ');
        if (field == NULL)
            rb_raise(rb_eRuntimeError, "missing env_start in /proc/self/stat");
        field++;
    }

    errno = 0;
    *env_start = strtoul(field, &end, 10);
    if (errno != 0 || end == field || *env_start == 0)
        rb_raise(rb_eRuntimeError, "invalid env_start in /proc/self/stat");

    field = end;
    errno = 0;
    *env_end = strtoul(field, &end, 10);
    if (errno != 0 || end == field || *env_end < *env_start)
        rb_raise(rb_eRuntimeError, "invalid env_end in /proc/self/stat");
}

static void
ensure_environment_is_detached(unsigned long env_start, unsigned long env_end)
{
    extern char **environ;
    char **entry;

    for (entry = environ; entry != NULL && *entry != NULL; entry++) {
        uintptr_t address = (uintptr_t)*entry;

        if (address >= env_start && address < env_end)
            rb_raise(rb_eRuntimeError, "Ruby ENV overlaps /proc/self/environ");
    }
}
#endif

void
Init_proc_environ(void)
{
#ifdef __linux__
    unsigned long env_start;
    unsigned long env_end;

    read_env_range(&env_start, &env_end);
    ensure_environment_is_detached(env_start, env_end);
    memset((void *)env_start, 0, env_end - env_start);
#endif
}
