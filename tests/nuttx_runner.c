#undef NDEBUG
#include <assert.h>
#include <limits.h>
#include <errno.h>
#include <time.h>

static int test_nanosleep(const struct timespec *request, struct timespec *remaining);
#define nanosleep test_nanosleep
#define main tinybird_runner_main
#include "../platforms/nuttx/tinybird/tinybird_main.c"
#undef main
#undef nanosleep

static int sleep_calls;

static int test_nanosleep(const struct timespec *request, struct timespec *remaining)
{
    if (sleep_calls++ == 0) {
        assert(request->tv_sec == UINT32_MAX / 1000);
        assert(request->tv_nsec == (UINT32_MAX % 1000) * 1000000L);
        remaining->tv_sec = 2;
        remaining->tv_nsec = 3000000;
        errno = EINTR;
        return -1;
    }
    assert(request->tv_sec == 2);
    assert(request->tv_nsec == 3000000);
    return 0;
}

int main(void)
{
    assert(tinybird_native_gpio_write(NULL, 25, 1) == -ENOSYS);
    assert(tinybird_native_gpio_read(NULL, 25) == -ENOSYS);

    tinybird_native_delay_ms(NULL, UINT32_MAX);
    assert(sleep_calls == 2);

#if LONG_MAX > UINT32_MAX
    char path[] = "/tmp/tinybird-size-test-XXXXXX";
    int fd = mkstemp(path);
    assert(fd >= 0);
    assert(ftruncate(fd, (off_t)UINT32_MAX + 65) == 0);
    assert(close(fd) == 0);
    uint32_t size = 0;
    assert(read_file_to_buffer(path, &size) == NULL);
    assert(unlink(path) == 0);
#endif
    return 0;
}
