{
  # ThinkPad TrackPoint: middle-button scroll wheel + sensitivity tuning.
  nixos.modules.trackpoint = {
    hardware.trackpoint = {
      enable = true;
      emulateWheel = true;
      sensitivity = 200;
      speed = 97;
    };
  };
}
