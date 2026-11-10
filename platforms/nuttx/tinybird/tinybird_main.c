/****************************************************************************
 * platforms/nuttx/tinybird/tinybird_main.c
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.  The
 * ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 ****************************************************************************/

/****************************************************************************
 * Included Files
 ****************************************************************************/

#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#if defined(__has_include)
#if __has_include(<wasm_export.h>)
#include <wasm_export.h>
#else
#include "wasm_export.h"
#endif
#else
#include "wasm_export.h"
#endif

/****************************************************************************
 * Pre-processor Definitions
 ****************************************************************************/

#ifndef CONFIG_INTERPRETERS_TINYBIRD_APP_STACK_SIZE
#define CONFIG_INTERPRETERS_TINYBIRD_APP_STACK_SIZE (16 * 1024)
#endif

#ifndef CONFIG_INTERPRETERS_TINYBIRD_APP_HEAP_SIZE
#define CONFIG_INTERPRETERS_TINYBIRD_APP_HEAP_SIZE (16 * 1024)
#endif

/****************************************************************************
 * Private Functions: Native Callbacks
 ****************************************************************************/

static void tinybird_native_log(wasm_exec_env_t exec_env, int32_t value)
{
    (void)exec_env;
    printf("%ld\n", (long)value);
}

static void tinybird_native_log_str(wasm_exec_env_t exec_env, int32_t offset, int32_t len)
{
    wasm_module_inst_t module_inst = wasm_runtime_get_module_inst(exec_env);
    if (!module_inst || len <= 0) {
        return;
    }

    if (!wasm_runtime_validate_app_addr(module_inst, (uint32_t)offset, (uint32_t)len)) {
        return;
    }

    const char *str = (const char *)wasm_runtime_addr_app_to_native(module_inst, (uint32_t)offset);
    if (str) {
        fwrite(str, 1, (size_t)len, stdout);
        putchar('\n');
    }
}

static uint32_t tinybird_native_uptime_ms(wasm_exec_env_t exec_env)
{
    (void)exec_env;
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
        return (uint32_t)((ts.tv_sec * 1000) + (ts.tv_nsec / 1000000));
    }
    return 0;
}

static void tinybird_native_delay_ms(wasm_exec_env_t exec_env, uint32_t ms)
{
    struct timespec remaining = {
        .tv_sec = ms / 1000,
        .tv_nsec = (ms % 1000) * 1000000L,
    };
    while (nanosleep(&remaining, &remaining) != 0) {
        if (errno != EINTR) {
            wasm_runtime_set_exception(wasm_runtime_get_module_inst(exec_env),
                                       "delay_ms failed");
            return;
        }
    }
}

static int32_t tinybird_native_gpio_write(wasm_exec_env_t exec_env, uint32_t pin, uint32_t value)
{
    (void)exec_env;
    (void)pin;
    (void)value;
    // shortcut: GPIO is unavailable, add board bindings before enabling hardware access.
    return -ENOSYS;
}

static int32_t tinybird_native_gpio_read(wasm_exec_env_t exec_env, uint32_t pin)
{
    (void)exec_env;
    (void)pin;
    return -ENOSYS;
}

/****************************************************************************
 * Private Data
 ****************************************************************************/

/* WAMR sorts arrays in place via qsort during registration.
 * Provide distinct arrays for the "tinybird" and "env" namespaces.
 */
static NativeSymbol g_tinybird_native_symbols[] = {
    { "log", (void *)tinybird_native_log, "(i)", NULL },
    { "log_str", (void *)tinybird_native_log_str, "(ii)", NULL },
    { "uptime_ms", (void *)tinybird_native_uptime_ms, "()i", NULL },
    { "delay_ms", (void *)tinybird_native_delay_ms, "(i)", NULL },
    { "gpio_write", (void *)tinybird_native_gpio_write, "(ii)i", NULL },
    { "gpio_read", (void *)tinybird_native_gpio_read, "(i)i", NULL },
};

static NativeSymbol g_env_native_symbols[] = {
    { "log", (void *)tinybird_native_log, "(i)", NULL },
    { "log_str", (void *)tinybird_native_log_str, "(ii)", NULL },
    { "uptime_ms", (void *)tinybird_native_uptime_ms, "()i", NULL },
    { "delay_ms", (void *)tinybird_native_delay_ms, "(i)", NULL },
    { "gpio_write", (void *)tinybird_native_gpio_write, "(ii)i", NULL },
    { "gpio_read", (void *)tinybird_native_gpio_read, "(i)i", NULL },
};

/****************************************************************************
 * Private Functions: Helpers
 ****************************************************************************/

static void print_usage(void)
{
    printf("Tinybird WebAssembly Runner for NuttX\n\n");
    printf("Usage:\n");
    printf("  tinybird <file.wasm> [args...]\n");
    printf("  tinybird run <file.wasm> [function] [args...]\n");
    printf("  tinybird -f <function> <file.wasm> [args...]\n");
    printf("  tinybird --version\n");
    printf("  tinybird --help\n\n");
    printf("Options:\n");
    printf("  -f, --function <name>  Specify an exported function to execute\n");
    printf("  --stack-size=<bytes>   Execution stack size (default: %d)\n",
           CONFIG_INTERPRETERS_TINYBIRD_APP_STACK_SIZE);
    printf("  --heap-size=<bytes>    Instance heap size (default: %d)\n",
           CONFIG_INTERPRETERS_TINYBIRD_APP_HEAP_SIZE);
    printf("  -v, --version          Show version information\n");
    printf("  -h, --help             Show this help message\n");
}

static void print_version(void)
{
    printf("tinybird 0.1.0 (NuttX runner)\n");
}

static uint8_t *read_file_to_buffer(const char *filename, uint32_t *out_size)
{
    FILE *file = fopen(filename, "rb");
    if (!file) {
        printf("Error: failed to open file '%s'\n", filename);
        return NULL;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        printf("Error: failed to seek file '%s'\n", filename);
        fclose(file);
        return NULL;
    }

    long file_size = ftell(file);
    if (file_size <= 0 || (uintmax_t)file_size > UINT32_MAX) {
        printf("Error: file '%s' is empty or invalid size\n", filename);
        fclose(file);
        return NULL;
    }

    if (fseek(file, 0, SEEK_SET) != 0) {
        printf("Error: failed to rewind file '%s'\n", filename);
        fclose(file);
        return NULL;
    }

    uint8_t *buffer = (uint8_t *)wasm_runtime_malloc((uint32_t)file_size);
    if (!buffer) {
        printf("Error: failed to allocate %ld bytes for file buffer\n", file_size);
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, (size_t)file_size, file);
    fclose(file);

    if (bytes_read != (size_t)file_size) {
        printf("Error: failed to read complete file '%s' (read %zu of %ld bytes)\n",
               filename, bytes_read, file_size);
        wasm_runtime_free(buffer);
        return NULL;
    }

    *out_size = (uint32_t)file_size;
    return buffer;
}

/****************************************************************************
 * Public Functions
 ****************************************************************************/

#if defined(main)
int main(int argc, char *argv[])
#elif defined(__NuttX__) || defined(CONFIG_INTERPRETERS_TINYBIRD)
int tinybird_main(int argc, char *argv[])
#else
int main(int argc, char *argv[])
#endif
{
    const char *wasm_file = NULL;
    const char *func_name = NULL;
    uint32_t stack_size = CONFIG_INTERPRETERS_TINYBIRD_APP_STACK_SIZE;
    uint32_t heap_size = CONFIG_INTERPRETERS_TINYBIRD_APP_HEAP_SIZE;
    int app_argc = 0;
    char **app_argv = NULL;

    int i = 1;
    while (i < argc && argv[i][0] == '-') {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage();
            return 0;
        } else if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--version") == 0) {
            print_version();
            return 0;
        } else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--function") == 0) {
            i++;
            if (i >= argc) {
                printf("Error: missing function name after '%s'\n", argv[i - 1]);
                print_usage();
                return 1;
            }
            func_name = argv[i++];
        } else if (strncmp(argv[i], "--stack-size=", 13) == 0) {
            stack_size = (uint32_t)strtoul(argv[i] + 13, NULL, 10);
            i++;
        } else if (strncmp(argv[i], "--heap-size=", 12) == 0) {
            heap_size = (uint32_t)strtoul(argv[i] + 12, NULL, 10);
            i++;
        } else {
            printf("Error: unknown option '%s'\n\n", argv[i]);
            print_usage();
            return 1;
        }
    }

    if (i >= argc) {
        printf("Error: missing .wasm file path\n\n");
        print_usage();
        return 1;
    }

    if (strcmp(argv[i], "help") == 0) {
        print_usage();
        return 0;
    } else if (strcmp(argv[i], "version") == 0) {
        print_version();
        return 0;
    } else if (strcmp(argv[i], "run") == 0) {
        i++;
        if (i >= argc) {
            printf("Error: missing .wasm file path after 'run'\n\n");
            print_usage();
            return 1;
        }
        wasm_file = argv[i++];
        if (i < argc && func_name == NULL) {
            func_name = argv[i++];
        }
        app_argc = argc - i;
        app_argv = (app_argc > 0) ? &argv[i] : NULL;
    } else {
        wasm_file = argv[i++];
        app_argc = argc - i;
        app_argv = (app_argc > 0) ? &argv[i] : NULL;
    }

    if (!wasm_runtime_init()) {
        printf("Error: failed to initialize WAMR runtime\n");
        return 1;
    }

    uint32_t n_symbols = (uint32_t)(sizeof(g_tinybird_native_symbols) / sizeof(NativeSymbol));
    if (!wasm_runtime_register_natives("tinybird", g_tinybird_native_symbols, n_symbols)) {
        printf("Error: failed to register native symbols for 'tinybird'\n");
        wasm_runtime_destroy();
        return 1;
    }

    if (!wasm_runtime_register_natives("env", g_env_native_symbols, n_symbols)) {
        printf("Error: failed to register native symbols for 'env'\n");
        wasm_runtime_unregister_natives("tinybird", g_tinybird_native_symbols);
        wasm_runtime_destroy();
        return 1;
    }

    uint32_t wasm_size = 0;
    uint8_t *wasm_buf = read_file_to_buffer(wasm_file, &wasm_size);
    if (!wasm_buf) {
        wasm_runtime_unregister_natives("env", g_env_native_symbols);
        wasm_runtime_unregister_natives("tinybird", g_tinybird_native_symbols);
        wasm_runtime_destroy();
        return 1;
    }

    char error_buf[128] = { 0 };
    wasm_module_t wasm_module = wasm_runtime_load(wasm_buf, wasm_size, error_buf, sizeof(error_buf));
    if (!wasm_module) {
        printf("Error loading module: %s\n", error_buf[0] ? error_buf : "unknown error");
        wasm_runtime_free(wasm_buf);
        wasm_runtime_unregister_natives("env", g_env_native_symbols);
        wasm_runtime_unregister_natives("tinybird", g_tinybird_native_symbols);
        wasm_runtime_destroy();
        return 1;
    }

    wasm_module_inst_t wasm_module_inst = wasm_runtime_instantiate(
        wasm_module, stack_size, heap_size, error_buf, sizeof(error_buf));
    if (!wasm_module_inst) {
        printf("Error instantiating module: %s\n", error_buf[0] ? error_buf : "unknown error");
        wasm_runtime_unload(wasm_module);
        wasm_runtime_free(wasm_buf);
        wasm_runtime_unregister_natives("env", g_env_native_symbols);
        wasm_runtime_unregister_natives("tinybird", g_tinybird_native_symbols);
        wasm_runtime_destroy();
        return 1;
    }

    int ret = 0;
    if (func_name) {
        if (!wasm_application_execute_func(wasm_module_inst, func_name, app_argc, app_argv)) {
            const char *exception = wasm_runtime_get_exception(wasm_module_inst);
            if (exception && exception[0] != '\0') {
                printf("Exception: %s\n", exception);
            } else {
                printf("Error: execution of function '%s' failed\n", func_name);
            }
            ret = 1;
        }
    } else {
        if (!wasm_application_execute_main(wasm_module_inst, app_argc, app_argv)) {
            const char *exception = wasm_runtime_get_exception(wasm_module_inst);
            if (exception && exception[0] != '\0') {
                printf("Exception: %s\n", exception);
            } else {
                printf("Error: execution failed\n");
            }
            ret = 1;
        }
    }

    wasm_runtime_deinstantiate(wasm_module_inst);
    wasm_runtime_unload(wasm_module);
    wasm_runtime_free(wasm_buf);
    wasm_runtime_unregister_natives("env", g_env_native_symbols);
    wasm_runtime_unregister_natives("tinybird", g_tinybird_native_symbols);
    wasm_runtime_destroy();

    return ret;
}
