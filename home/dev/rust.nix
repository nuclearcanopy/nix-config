{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
  ];
}
