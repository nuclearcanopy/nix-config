{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;
    
    shellAliases = {
      snvim = "sudo -E nvim";
      nvfx = "nvim .";
      nasmount = "sudo mount -t cifs //192.168.0.123/nuclearcanopy /mnt/nas -o username=mihaita,iocharset=utf8,vers=3.1.1";
      sysd-ui = "systemd-manager-tui";
      bright = ''ssh -p 1208 homeserver@192.168.0.111 'current=$(cat /sys/class/backlight/intel_backlight/brightness); max=$(cat /sys/class/backlight/intel_backlight/max_brightness); target=$((max * 70 / 100)); [ "$current" -eq 0 ] && echo $target | sudo tee /sys/class/backlight/intel_backlight/brightness || echo 0 | sudo tee /sys/class/backlight/intel_backlight/brightness' '';
    };
    
    interactiveShellInit = ''
      set fish_greeting
      set fish_color_command green
      set fish_color_cerror red
      set fish_color_param cyan

      set fish_cursor_default block
      set fish_cursor_insert line
      set fish_cursor_replace_one underscore
      set fish_cursor_visual block

      
      function fish_prompt
        echo

        set_color 1c1c1c
        echo -n " "

        set_color -b 1c1c1c
        set_color 808080
        echo -n " "
  
        set_color -b 232323
        set_color 1c1c1c
        echo -n ""

        set_color -b 232323
        set_color b4b4b4
        echo -n " "(prompt_pwd)" "

        set_color -b 1c1c1c
        set_color 232323
        echo -n ""

        set_color 1c1c1c
        set_color -b normal
        echo -n " "
      end
      
      function nix-commit
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " Changes"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        git -C ~/.nix/ diff --stat --color=always
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "󱄅 Rebuilding..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        
        if sudo nixos-rebuild switch --flake ~/.nix/#kuraokami --show-trace 2>&1 | tee /tmp/nix-build-log
          set BUILD_SUCCESS true
        else
          set BUILD_SUCCESS false
        end
        
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if test "$BUILD_SUCCESS" = true
          set GEN (nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
          set GEN_NUM (nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1}')
          
          git -C ~/.nix/ add .
          git -C ~/.nix/ commit -m "Rebuild: $GEN" --quiet
          
          echo "󰊢 Syncing..."
          git -C ~/.nix/ push origin main --quiet >/dev/null 2>&1
          
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo " Done. (Gen $GEN_NUM)"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
          echo "󰚌 Build Failed"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        end
      end
      
      if status is-interactive
        fastfetch
      end
    '';
    
    plugins = [
    ];
  };
}
