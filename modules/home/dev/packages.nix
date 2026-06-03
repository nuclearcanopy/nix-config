{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # programming
    gnumake
    gcc
    (python313.withPackages (ps: [ ps.pip ]))
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    # ai slop tools
    mcp-nixos
    codex

    # cybersec stuff
    # NOTE: wireshark is enabled at the system level via programs.wireshark
    # for dumpcap capabilities — not listed here.
    ghidra
    tcpdump
    ffuf
    nmap
    netcat-gnu
    gobuster
    nikto
    binwalk
    binutils
    masscan
    wfuzz
    cyberchef
    john
    hashcat
    hash-identifier
    zsteg
    scalpel
    hexedit
    gnupg
    burpsuite
  ];
}
