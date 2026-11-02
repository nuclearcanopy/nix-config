{
  homeManager.modules.user-packages = { pkgs, ... }: {
    home.packages = (import ./user-packages-common.data.nix pkgs) ++ (with pkgs; [
      kdePackages.kdenlive

      mangohud
      vkbasalt
      protontricks
      gamescope

      bottles
      protonup-qt
      xivlauncher
      prismlauncher

      feishin
      qjackctl
    ]);
  };
}
