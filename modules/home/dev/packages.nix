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
    claude-code
    codex
  ];
}
