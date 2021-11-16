#include <vmlinux/vmlinux.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __type(key, u32);
    __type(value, u32);
    __uint(max_entries, 128);
} my_array_map SEC(".maps");

__u32 current_key = 0;

// SEC("kprobe/do_unlinkat")
SEC("kprobe/udp_sendmsg")
// int BPF_KPROBE(do_unlinkat, int dfd, struct filename *name) 
int BPF_KPROBE(handle_probe, struct sock *sk, struct msghdr *msg, size_t len)
{
    pid_t pid = bpf_get_current_pid_tgid() >> 32;

    __u32 priority = BPF_CORE_READ(sk, sk_priority);
    bpf_map_update_elem(&my_array_map, &pid, &priority, BPF_ANY /* flags */);
    
    bpf_printk("hello BPF: %d", pid);

    return 0;
}

char LICENSE[] SEC("license") = "Dual BSD/GPL";