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
      # prismlauncher is NOT listed here: it comes from the shared
      # prism-mullvad module (wrapped in mullvad-exclude, jdks pinned).
      # Listing it here too would collide on the binary name.

      feishin
      qjackctl
    ]);
  };
}
