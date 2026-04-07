{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    gcc
    python313
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    claude-code
    codex
  ];
}
