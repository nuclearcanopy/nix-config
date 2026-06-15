{ config, pkgs, username, ... }:

let
  askpass = pkgs.writeShellScript "askpass-zenity" ''
    exec ${pkgs.systemd}/bin/systemd-run \
      --user --pipe --quiet --wait --collect \
      ${pkgs.zenity}/bin/zenity --password --title="Authentication"
  '';
in
{
  time.timeZone = "Europe/Bucharest";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = true;

    users.${username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "docker" "wireshark" ];
      hashedPasswordFile = config.age.secrets.user-password.path;
    };

    users.root.hashedPassword = "!";
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    execWheelOnly = true;
    extraConfig = ''
      Defaults env_keep += "XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS SUDO_ASKPASS"
    '';
  };

  environment.systemPackages = [ pkgs.zenity ];
  environment.sessionVariables.SUDO_ASKPASS = "${askpass}";

  environment.variables.EDITOR = "nvim";

  programs.ssh.knownHosts."github.com" = {
    hostNames = [ "github.com" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
}
