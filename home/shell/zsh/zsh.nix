{ config, secrets, ... }:

{
  programs.zsh = {
    enable = true;

    # plugins
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;

    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
    };

    # aliases
    shellAliases = {
      snvim = "sudo HOME=/root nvim";
      nvfx = "nvim .";
      nasmount = "sudo mount -t cifs //${secrets.nas.ip}/${secrets.nas.share} /mnt/nas -o username=${secrets.nas.username},iocharset=utf8,vers=3.1.1";
      sysd-ui = "systemd-manager-tui";
      vpnissue = "ip -s link show proton0 && sudo wg show";
    };

    initContent = ''
      ${builtins.readFile ./prompt.zsh}
      ${builtins.readFile ./nix-commit.zsh}
    '';
  };
}
