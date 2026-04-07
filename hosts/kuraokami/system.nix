{ config, pkgs, username, ... }:

{
  system.stateVersion = "25.11";

  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = true;

    users.${username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
      hashedPasswordFile = config.age.secrets.user-password.path;
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
    memoryPercent = 33;
  };

  environment.variables.EDITOR = "nvim";
}
