{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python315

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
