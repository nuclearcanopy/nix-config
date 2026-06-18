{
  nixos.modules.thinkfan = {
    services.thinkfan = {
      enable = true;
      settings = {
        sensors = [
          {
            hwmon = "/sys/devices/platform/coretemp.0";
            indices = [ 1 2 3 4 5 ];
          }
        ];
        fans = [ { tpacpi = "/proc/acpi/ibm/fan"; } ];
        levels = [
          [ 0   0  55 ]
          [ 1  52  60 ]
          [ 2  57  65 ]
          [ 3  62  70 ]
          [ 5  67  75 ]
          [ 7  72 255 ]
        ];
      };
    };
  };
}
