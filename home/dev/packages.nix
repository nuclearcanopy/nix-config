{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python

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
