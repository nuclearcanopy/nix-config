{ config, lib, username, ... }:

{
  systemd.services.persist-migration = {
    description = "One-time migration from /persist to home";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];

    # Only run if marker doesn't exist
    unitConfig = {
      ConditionPathExists = "!/var/lib/persist-migration-done";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      PERSIST_HOME="/persist/home/${username}"
      REAL_HOME="/home/${username}"

      # Exit gracefully if persist home doesn't exist
      if [ ! -d "$PERSIST_HOME" ]; then
        echo "No persist home found at $PERSIST_HOME, skipping migration"
        touch /var/lib/persist-migration-done
        exit 0
      fi

      echo "Starting migration from $PERSIST_HOME to $REAL_HOME"

      # Ensure real home exists with correct ownership
      mkdir -p "$REAL_HOME"
      chown ${username}:users "$REAL_HOME"

      # Move each item from persist to real home
      cd "$PERSIST_HOME"
      for item in * .[!.]* ..?*; do
        # Skip if glob didn't match anything
        [ -e "$item" ] || continue

        TARGET="$REAL_HOME/$item"

        if [ -e "$TARGET" ]; then
          # Target exists - check if it's empty dir we can remove
          if [ -d "$TARGET" ] && [ -z "$(ls -A "$TARGET" 2>/dev/null)" ]; then
            echo "Removing empty directory: $TARGET"
            rmdir "$TARGET"
          else
            echo "SKIPPING (target exists): $item"
            continue
          fi
        fi

        echo "Moving: $item"
        mv -v "$item" "$REAL_HOME/"
      done

      # Fix ownership recursively
      chown -R ${username}:users "$REAL_HOME"

      # Mark migration as complete
      touch /var/lib/persist-migration-done

      echo "Migration complete!"
    '';
  };
}
