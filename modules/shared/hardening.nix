{ ... }:

# Kernel hardening common to all desktop/laptop hosts.
# Host-specific params (amd_pstate, intel_pstate, power-saving, etc.) stay
# in the per-host boot.nix. Laptop-specific hardening (IOMMU, lockdown,
# USBGuard, Thunderbolt blacklist, AppArmor) lives in
# modules/laptop/system/hardening.nix.
{
  boot = {
    kernelParams = [
      "pti=on"
      "vsyscall=none"
      "init_on_alloc=1"
      "init_on_free=1"                 # sanitize freed pages — defeats use-after-free reads
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"     # per-syscall kernel stack offset — breaks ROP/JOP gadget chains
      "extra_latent_entropy"           # mix boot entropy into more random pools
      "preempt=full"
    ];

    blacklistedKernelModules = [ "dccp" "sctp" "rds" "tipc" ];

    kernel.sysctl = {
      "net.ipv4.conf.all.rp_filter"               = 2;
      "net.ipv4.conf.default.rp_filter"            = 2;
      "net.ipv4.conf.all.accept_redirects"         = 0;
      "net.ipv4.conf.default.accept_redirects"     = 0;
      "net.ipv6.conf.all.accept_redirects"         = 0;
      "net.ipv6.conf.default.accept_redirects"     = 0;
      "net.ipv4.conf.all.accept_source_route"      = 0;
      "net.ipv4.conf.default.accept_source_route"  = 0;
      "net.ipv6.conf.all.accept_source_route"      = 0;
      "net.ipv6.conf.default.accept_source_route"  = 0;
      "net.ipv4.conf.all.log_martians"             = 0;
      "net.ipv4.conf.all.send_redirects"           = 0;
      "net.ipv4.conf.default.send_redirects"       = 0;
      "fs.protected_symlinks"                      = 1;
      "fs.protected_hardlinks"                     = 1;
      "fs.protected_regular"                       = 2;
      "fs.protected_fifos"                         = 2;

      # Hide kernel addresses from non-root readers — denies %pK to /proc/kallsyms
      # etc., which kASLR-bypass gadget-hunting tools rely on.
      "kernel.kptr_restrict"                       = 2;
      "kernel.dmesg_restrict"                      = 1;
      "kernel.perf_event_paranoid"                 = 3;   # no perf_event_open for unprivileged
      "kernel.unprivileged_bpf_disabled"           = 1;   # no eBPF for unprivileged
      "net.core.bpf_jit_harden"                    = 2;   # constant blinding in BPF JIT — kills JIT spray
      "kernel.yama.ptrace_scope"                   = 2;   # ptrace only with CAP_SYS_PTRACE
      "kernel.kexec_load_disabled"                 = 1;   # one-way: blocks live-kernel replacement
      "kernel.sysrq"                               = 4;   # only Alt-SysRq-K (Secure Attention Key)
      "vm.unprivileged_userfaultfd"                = 0;   # closes a use-after-free exploitation primitive
    };
  };
}
