{
  # Firmware updates via LVFS. Scoped to kuraokami only (wired in
  # modules/computers/kuraokami.nix), NOT desktop-base.
  #
  # nidhoggr deliberately does without: it runs Libreboot, which has no UEFI
  # capsule path, so the only updatable device fwupd could ever see there was
  # the NVMe -- for the price of a resident daemon plus a periodic outbound
  # LVFS refresh on a kernel-lockdown Mullvad host. It was removed from that
  # host on 2026-09-06 and should stay removed; use the ad hoc form instead:
  #   nix shell nixpkgs#fwupd -c fwupdmgr get-updates
  #
  # On kuraokami the board, GPU and NVMe all have real capsule update paths,
  # so the daemon earns its keep.
  nixos.modules.fwupd = {
    services.fwupd.enable = true;
  };
}
