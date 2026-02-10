{ ... }:

{
  # Network performance tuning optimized for VPN tunnels
  # Addresses TCP buffer asymmetry, congestion control, and queueing issues

  boot.kernelModules = [ "tcp_bbr" ];

  boot.kernel.sysctl = {
    # === TCP Congestion Control ===
    # BBRv3: Optimized for high-latency/variable paths (VPNs)
    # Maintains better throughput than cubic over tunnels
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";  # Fair Queue (required for BBR)

    # === TCP Buffer Tuning ===
    # Increased send buffers to match receive buffers (fixes upload bottleneck)
    # Format: min default max (in bytes)
    "net.core.rmem_max" = 67108864;        # 64MB max receive buffer
    "net.core.wmem_max" = 67108864;        # 64MB max send buffer (was 4MB!)
    "net.core.rmem_default" = 1048576;     # 1MB default receive
    "net.core.wmem_default" = 1048576;     # 1MB default send

    "net.ipv4.tcp_rmem" = "4096 1048576 67108864";  # TCP receive: min default max
    "net.ipv4.tcp_wmem" = "4096 1048576 67108864";  # TCP send: min default max (was 4MB max!)
    "net.ipv4.udp_rmem_min" = 8192;
    "net.ipv4.udp_wmem_min" = 8192;

    # === Path MTU Discovery ===
    # Enable probing to handle PMTUD blackholes (common with VPNs)
    "net.ipv4.tcp_mtu_probing" = 1;

    # === TCP Performance Tweaks ===
    "net.ipv4.tcp_slow_start_after_idle" = 0;  # Don't reduce cwnd after idle
    "net.ipv4.tcp_notsent_lowat" = 16384;      # Reduce bufferbloat

    # === Connection Tracking ===
    # Increase for VPN + high connection count scenarios
    "net.netfilter.nf_conntrack_max" = 262144;
    "net.nf_conntrack_max" = 262144;

    # === IPv6 ===
    # Ensure IPv6 buffers match IPv4
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv6.conf.default.forwarding" = 0;

    # IPv6 privacy and VPN compatibility
    "net.ipv6.conf.all.accept_ra" = 1;  # Accept Router Advertisements (needed for VPN IPv6)
    "net.ipv6.conf.default.accept_ra" = 1;
    "net.ipv6.conf.all.autoconf" = 1;  # Allow IPv6 autoconfiguration
    "net.ipv6.conf.default.autoconf" = 1;
  };
}
