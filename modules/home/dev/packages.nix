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
    ghidra
    tcpdump
    wireshark
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
    zsteg
    scalpel
    hexedit
    gnupg
  ];
}
