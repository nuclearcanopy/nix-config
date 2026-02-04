{ ... }:

{
  programs.wofi = {
    enable = true;

    settings = {
      allow_images = true;
      show = "drun";
      prompt = "Search";
      width = 400;
      lines = 5;
      term = "kitty";
      hide_scroll = true;
      print_command = true;
      insensitive = true;
      no_actions = true;
      filter_rate = 10;
      close_on_focus_loss = false;
    };

    style = builtins.readFile ./style.css;
  };
}
