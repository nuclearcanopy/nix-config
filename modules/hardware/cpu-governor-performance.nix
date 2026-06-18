{
  # Performance CPU governor. Kuraokami uses this for desktop responsiveness.
  # Laptop intentionally does NOT import this; TLP manages the governor
  # per AC/BAT state instead.
  nixos.modules.cpu-governor-performance = {
    powerManagement.cpuFreqGovernor = "performance";
  };
}
