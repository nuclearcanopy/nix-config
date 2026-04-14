NIX_FLAKE_DIR="$HOME/nix-config"
: ${NIX_FLAKE_HOST:="$(hostname)"}

_nix_eval_check() {
  echo "󱄅 Evaluating config..."
  if ! nix eval "${NIX_FLAKE_DIR}#nixosConfigurations.${NIX_FLAKE_HOST}.config.system.build.toplevel.drvPath" \
      --option warn-dirty false 2>&1; then
    echo "󰚌 Eval failed — aborting"
    return 1
  fi
}

nix-commit() {
  echo " Changes"
  git -C "$NIX_FLAKE_DIR" diff --stat --color=always

  echo ""
  echo -n "󰏪 Commit message: "
  read COMMIT_MSG
  if [ -z "$COMMIT_MSG" ]; then
    echo "󰚌 Aborted (no commit message)"
    return 1
  fi

  git -C "$NIX_FLAKE_DIR" add .

  if ! _nix_eval_check; then
    git -C "$NIX_FLAKE_DIR" reset --quiet
    return 1
  fi

  echo "󱄅 Rebuilding..."

  if elevate nixos-rebuild switch --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi

  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1}')

    git -C "$NIX_FLAKE_DIR" commit -m "$COMMIT_MSG (Gen $GEN_NUM)" --quiet

    echo "󰊢 Syncing..."
    git -C "$NIX_FLAKE_DIR" push origin main --quiet > /dev/null 2>&1
    git -C "$NIX_FLAKE_DIR" push github main --quiet > /dev/null 2>&1

    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
    git -C "$NIX_FLAKE_DIR" reset --quiet
  fi
}

nix-clone() {
  echo "󰊢 Pulling latest from Codeberg..."
  git -C "$NIX_FLAKE_DIR" pull origin main || { echo "󰚌 Pull failed"; return 1; }

  echo "󱄅 Rebuilding..."
  if elevate nixos-rebuild switch --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    GEN_NUM=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1}')
    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}

nix-upd() {
  echo " Changes"
  git -C "$NIX_FLAKE_DIR" diff --stat --color=always

  git -C "$NIX_FLAKE_DIR" add .

  if ! _nix_eval_check; then
    git -C "$NIX_FLAKE_DIR" reset --quiet
    return 1
  fi

  echo "󱄅 Rebuilding..."

  if elevate nixos-rebuild switch --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    BUILD_SUCCESS=true
  else
    BUILD_SUCCESS=false
  fi

  git -C "$NIX_FLAKE_DIR" reset --quiet

  if [ "$BUILD_SUCCESS" = true ]; then
    GEN=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1 " (" $2 " " $3 ")"}')
    GEN_NUM=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1}')

    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}
