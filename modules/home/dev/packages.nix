{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # build tools
    gnumake
    gcc

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
