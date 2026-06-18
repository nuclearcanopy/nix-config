{
  # CPU undervolting for i5-8350U (Kaby Lake-R), BIOS N24ET81W 1.56.
  # Start conservative; deepen if stable under stress-ng. If the system
  # freezes, reduce offsets and rebuild.
  nixos.modules.undervolt = {
    services.undervolt = {
      enable = true;
      coreOffset    = -115;
      gpuOffset     = -45;
      uncoreOffset  = -115;
      analogioOffset = 0;
    };
  };
}
