nix-commit() {
  echo " Changes"
  git -C ~/.nix/ diff --stat --color=always
  
  echo "󱄅 Rebuilding..."
  
  if sudo nixos-rebuild switch --flake ~/.nix/#kuraokami --show-trace 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi
  
  
  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake ~/.nix/#kuraokami | grep True | awk '{print $1}')
      
    git -C ~/.nix/ add .
    git -C ~/.nix/ commit -m "Rebuild: $GEN" --quiet
      
    echo "󰊢 Syncing..."
    git -C ~/.nix/ push origin main --quiet > /dev/null 2>&1
      
    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}
