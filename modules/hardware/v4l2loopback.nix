{
  # v4l2loopback kernel module for OBS Virtual Camera. Bound to the currently
  # booted kernelPackages so it works on both hosts regardless of kernel.
  # exclusive_caps=1 makes the fake device advertise CAPTURE-only, which is
  # what Chromium/Firefox/Teams require to pick it up as a webcam source.
  nixos.modules.v4l2loopback = { config, ... }: {
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"
    '';
  };
}
