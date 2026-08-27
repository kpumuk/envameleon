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

static VALUE
scrub_proc_data(VALUE environment)
{
    unsigned long env_start;
    unsigned long env_end;

    (void)environment;
    read_env_range(&env_start, &env_end);
    ensure_environment_is_detached(env_start, env_end);
    memset((void *)env_start, 0, env_end - env_start);
    return Qnil;
}

static VALUE
mask_proc_data(VALUE environment)
{
    unsigned long env_start;
    unsigned long env_end;
    char *entry;

    (void)environment;
    read_env_range(&env_start, &env_end);
    ensure_environment_is_detached(env_start, env_end);

    for (entry = (char *)env_start; entry < (char *)env_end;) {
        size_t remaining = (char *)env_end - entry;
        char *terminator = memchr(entry, '\0', remaining);
        char *equals;
        char *value;
        size_t value_length;

        if (terminator == NULL)
            rb_raise(rb_eRuntimeError, "invalid environment data");

        equals = memchr(entry, '=', terminator - entry);
        if (equals != NULL) {
            value = equals + 1;
            value_length = terminator - value;
            if (value_length > 2)
                memset(value + 1, '*', value_length - 2);
        }

        entry = terminator + 1;
    }

    return Qnil;
}
#else
static VALUE
scrub_proc_data(VALUE environment)
{
    (void)environment;
    return Qnil;
}

static VALUE
mask_proc_data(VALUE environment)
{
    (void)environment;
    return Qnil;
}
#endif

void
Init_proc_environ(void)
{
    ID environment_id = rb_intern2("ENV", 3);
    VALUE environment = rb_const_get(rb_cObject, environment_id);

    rb_define_singleton_method(environment, "scrub_proc_data", scrub_proc_data, 0);
    rb_define_singleton_method(environment, "mask_proc_data", mask_proc_data, 0);
}
