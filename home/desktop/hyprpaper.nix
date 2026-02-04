{ ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;

      preload = [
        "~/Wallpapers/Wallpaper_Monitor_1.png"
        "~/Wallpapers/Wallpaper_Monitor_2.png"
        "~/Wallpapers/Wallpaper_No_Bar.jpg"
      ];

      wallpaper = [
        "DP-1,~/Wallpapers/Wallpaper_Monitor_1.png"
        "HDMI-A-1,~/Wallpapers/Wallpaper_Monitor_2.png"
        "HDMI-A-2,~/Wallpapers/Wallpaper_No_Bar.jpg"
      ];
    };
  };
}

