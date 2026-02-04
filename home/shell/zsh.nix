{ config, ... }:

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
      snvim = "sudo -E nvim";
      nvfx = "nvim .";
      nasmount = "sudo mount -t cifs //192.168.0.123/nuclearcanopy /mnt/nas -o username=mihaita,iocharset=utf8,vers=3.1.1";
      sysd-ui = "systemd-manager-tui";
    };

    initContent = ''
      # prompt
      precmd() { echo }

      setopt prompt_subst
      
      fg_custom() { echo "%{\e[38;2;''${1}m%}"; }
      bg_custom() { echo "%{\e[48;2;''${1}m%}"; }

      C1="35;35;35"
      C3="28;28;28"
      LIGHTGRAY="140;140;140"
      WHITE="180;180;180"

      PROMPT=" $(fg_custom $C1)"
      PROMPT+="$(fg_custom $LIGHTGRAY)$(bg_custom $C1) "
      PROMPT+="$(fg_custom $C1)$(bg_custom $C3)"
      PROMPT+="$(fg_custom $WHITE)$(bg_custom $C3) %~ "
      PROMPT+="$(fg_custom $C3)$(bg_custom $C1)"
      PROMPT+="$(fg_custom $C1)%k%k%f "

      # functions
      nix-commit() {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo " Changes"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        git -C ~/.nix/ diff --stat --color=always
        
        echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "󱄅 Rebuilding..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        if sudo nixos-rebuild switch --flake ~/.nix/#kuraokami --show-trace 2>&1 | tee /tmp/nix-build-log; then
          BUILD_SUCCESS=true
        else
          BUILD_SUCCESS=false
        fi
        
        echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if [ "$BUILD_SUCCESS" = true ]; then
          GEN=$(nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
          GEN_NUM=$(nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1}')
            
          git -C ~/.nix/ add .
          git -C ~/.nix/ commit -m "Rebuild: $GEN" --quiet
            
          echo "󰊢 Syncing..."
          git -C ~/.nix/ push origin main --quiet > /dev/null 2>&1
            
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo " Done. (Gen $GEN_NUM)"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
          echo "󰚌 Build Failed"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
      }

      # startup
      [[ $- == *i* ]] && fastfetch
      
      typeset -A ZSH_HIGHLIGHT_STYLES
      ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
    '';
  };
}
