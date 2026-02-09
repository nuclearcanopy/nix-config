nix-commit() {
  echo " Changes"
  git -C ~/nix-config/ diff --stat --color=always
  
  echo "󱄅 Rebuilding..."
  
  if sudo nixos-rebuild switch --flake ~/nix-config/#kuraokami --impure --show-trace 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi
  
  
  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami --impure | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1}')
      
    git -C ~/nix-config/ add .
    git -C ~/nix-config/ commit -m "Rebuild: $GEN" --quiet
      
    echo "󰊢 Syncing..."
    git -C ~/nix-config/ push origin main --quiet > /dev/null 2>&1
      
    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}
