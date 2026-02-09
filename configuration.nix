{ config, lib, pkgs, username, ... }:

{
  system.stateVersion = "25.11";

  imports = [
    ./hardware
    ./system
  ];

  # localization
  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # users
  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = true;

    users.${username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "input" ];
      hashedPassword = secrets.user.hashedPassword;
    };

    users.root.hashedPassword = secrets.user.hashedPassword;
  };

  # security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };

  # zram
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # environment
  environment.variables = {
    EDITOR = "nvim";

    # telemetry
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    POWERSHELL_TELEMETRY_OPTOUT = "1";
    AZURE_CORE_COLLECT_TELEMETRY = "0";
    DO_NOT_TRACK = "1";
  };
}
