#include <ruby.h>

#ifdef __linux__
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <linux/prctl.h>

static unsigned long
read_env_start(void)
{
    char stat[4096];
    char *field;
    char *end;
    FILE *file = fopen("/proc/self/stat", "r");
    int number;
    unsigned long address;

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
    address = strtoul(field, &end, 10);
    if (errno != 0 || end == field || address == 0)
        rb_raise(rb_eRuntimeError, "invalid env_start in /proc/self/stat");

    return address;
}
#endif

void
Init_proc_environ(void)
{
#ifdef __linux__
    unsigned long env_start = read_env_start();

    if (prctl(PR_SET_MM, PR_SET_MM_ENV_END, env_start, 0L, 0L) == -1)
        rb_sys_fail("prctl(PR_SET_MM_ENV_END)");
#endif
}
