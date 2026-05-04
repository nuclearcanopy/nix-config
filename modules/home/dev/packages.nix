{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    gcc
    (python313.withPackages (ps: [ ps.pip ]))
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    mcp-nixos
    codex

    ghidra
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
  ];
}
