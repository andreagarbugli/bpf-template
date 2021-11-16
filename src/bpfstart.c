#include <signal.h> 
#include <stdio.h>
#include <stdbool.h>
#include <time.h>
#include <unistd.h>

#include <bpf/bpf.h> /* maps functions */
#include <bpf/libbpf.h>

#include <sys/resource.h>

#include "logger.h"

#include "bpfstart.skel.h"

static bool g_running = true;

static void handler(int signum) {
    fprintf(stderr, "\n");
    LOG_INFO("Received a CTRL+C: exiting...");

    g_running = false;
}

int bump_memlock_rlimit(void) {
	struct rlimit rlim_new = {
		.rlim_cur	= RLIM_INFINITY,
		.rlim_max	= RLIM_INFINITY,
	};

	return setrlimit(RLIMIT_MEMLOCK, &rlim_new);
}

int log_libbpf(enum libbpf_print_level level, const char *fmt, va_list ap) {
    switch (level)
    {
    case LIBBPF_WARN:
        break;
    
    default:
        VLOG_TRACE(fmt, ap);
        break;
    }
}

int main() {
    LOG_INFO("Starting BFP program example");

    // libbpf_set_print(log_libbpf);

    int err = bump_memlock_rlimit();
    if (err) {
        LOG_ERROR("Failed to increase rlimit: %d", err);
        return 1;
    }

    struct bpfstart_bpf *skel = bpfstart_bpf__open_and_load();
    if (!skel) {
        LOG_ERROR("Failed to open BPF skeleton");
        goto cleanup;
    }

    err = bpfstart_bpf__attach(skel);
    if (err) {
        LOG_ERROR("Failed to attach BPF skeleton");
        goto cleanup;
    }

    signal(SIGINT, handler);

    int map_fd = bpf_object__find_map_fd_by_name(skel->obj, "my_array_map");
    if (map_fd < 0) {
        LOG_WARN("No map found");
    }

    LOG_INFO("Successfully started!");
    LOG_INFO("Please run `sudo cat /sys/kernel/debug/tracing/trace_pipe` to see output of the BPF program");

    struct timespec ts = { .tv_nsec = 0, .tv_sec = 1 };

    __u32 key = -2, next_key;
    __u32 val = 0;
    while (g_running) {
        if (bpf_map_get_next_key(map_fd, &key, &next_key) == 0) {
            LOG_TRACE("key = %d\tnext_key = %d", key, next_key);
            err = bpf_map_lookup_and_delete_elem(map_fd, &next_key, &val);
            if (err >= 0) {
                LOG_INFO("key = %d\tvalue =  %d", key, val);
            }
            key = -2;
        } else {
            LOG_TRACE("No valid key found");
        }
        
        nanosleep(&ts, NULL);
    }

cleanup:
    bpfstart_bpf__destroy(skel);

    return -err;
}
