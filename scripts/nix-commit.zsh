NIX_FLAKE_DIR="$HOME/nix-config"
: ${NIX_FLAKE_HOST:="$(hostname)"}

# pipefail is load-bearing in all three functions below: the rebuild is piped
# into `tee`, and without it the `if` tests tee's status, which is ~always 0.
# A failed rebuild therefore took the success branch, printed the *previous*
# generation number as if it were new, and committed and pushed the broken
# config; the `git reset` rollback was unreachable. localoptions scopes the
# setopt to the function so it never leaks into the interactive shell.
nix-commit() {
  setopt localoptions pipefail

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
    if ! git -C "$NIX_FLAKE_DIR" push github main --quiet; then
      echo "󰚌 Push failed; commit is local only"
      return 1
    fi

    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
    git -C "$NIX_FLAKE_DIR" reset --quiet
  fi
}

nix-clone() {
  setopt localoptions pipefail

  echo "󰊢 Pulling latest from GitHub..."
  git -C "$NIX_FLAKE_DIR" pull github main || { echo "󰚌 Pull failed"; return 1; }

  echo "󱄅 Rebuilding..."
  if elevate nixos-rebuild switch --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" --show-trace --option warn-dirty false 2>&1 | tee /tmp/nix-build-log; then
    GEN_NUM=$(nixos-rebuild list-generations --flake "$NIX_FLAKE_DIR/#${NIX_FLAKE_HOST}" | grep True | awk '{print $1}')
    echo " Done. (Gen $GEN_NUM)"
  else
    echo "󰚌 Build Failed"
  fi
}

nix-upd() {
  setopt localoptions pipefail

  echo " Changes"
  git -C "$NIX_FLAKE_DIR" diff --stat --color=always

  git -C "$NIX_FLAKE_DIR" add .

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
