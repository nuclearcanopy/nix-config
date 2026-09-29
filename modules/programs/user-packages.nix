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

      # calibre     # temporarily out: pulls onnxruntime which fails to build
      texliveFull

      feishin
      qjackctl
    ]);
  };
}
