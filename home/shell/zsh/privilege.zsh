elevate() {
  if command -v doas >/dev/null 2>&1; then
    doas -E "$@"
    return $?
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo -E "$@"
    return $?
  fi
  echo "Neither doas nor sudo is available." >&2
  return 127
}

snvim() {
  elevate nvim "$@"
}
