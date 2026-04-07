nix-commit() {
  echo " Changes"
  git -C ~/nix-config/ diff --stat --color=always

  # Stage all changes so flake can see new files
  git -C ~/nix-config/ add .

  echo "󱄅 Rebuilding..."

  if elevate nixos-rebuild switch --flake ~/nix-config/#kuraokami --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi


  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1}')

    git -C ~/nix-config/ commit -m "Rebuild: $GEN" --quiet

    echo "󰊢 Syncing..."
    git -C ~/nix-config/ push origin main --quiet > /dev/null 2>&1

    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
    # Unstage on failure so you can fix things
    git -C ~/nix-config/ reset --quiet
  fi
}

nix-clone() {
  echo "󰊢 Pulling latest from Codeberg..."
  git -C ~/nix-config/ pull origin main || { echo "󰚌 Pull failed"; return 1; }

  echo "󱄅 Rebuilding..."
  if elevate nixos-rebuild switch --flake ~/nix-config/#kuraokami --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1}')
    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}

nix-upd() {
  echo " Changes"
  git -C ~/nix-config/ diff --stat --color=always

  # Stage all changes so flake can see new files
  git -C ~/nix-config/ add .

  echo "󱄅 Rebuilding..."

  if elevate nixos-rebuild switch --flake ~/nix-config/#kuraokami --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi

  # Always unstage so this stays "rebuild only"
  git -C ~/nix-config/ reset --quiet

  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake ~/nix-config/#kuraokami | grep True | awk '{print $1}')

    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}
