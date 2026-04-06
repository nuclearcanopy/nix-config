{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python313

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
