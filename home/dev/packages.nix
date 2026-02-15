{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python2

    # rust
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    claude-code
    codex
  ];
}
