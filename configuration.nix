{ config, lib, pkgs, username, secrets, ... }:

{
  system.stateVersion = "25.11";

  imports = [
    ./hardware
    ./system
  ];

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = true;

    users.${username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
      hashedPassword = secrets.user.hashedPassword;
    };

    users.root.hashedPassword = "!";
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  environment.variables = {
    EDITOR = "nvim";
  };
}
