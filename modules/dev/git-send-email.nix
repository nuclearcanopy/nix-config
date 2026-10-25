{
  # git send-email via Proton's send-only SMTP token service. No Bridge
  # daemon: a token only sends mail, which is all git-send-email needs, and
  # nixpkgs' git already bundles the Perl SMTP/SASL/SSL deps it requires.
  #
  # Identity (email + display name) and the SMTP token both live in agenix,
  # never as literal strings here: this file is public, and git-send-email
  # needs the real sending address to match the Proton SMTP token's owner
  # (it does NOT reuse a patch's own From: line as the sender by design, so
  # a static identity has to be supplied somehow). The `git-send-email-proton`
  # wrapper below reads both at runtime and passes them as flags, so the
  # actual values never touch the nix store or this repo.
  #
  # Setup:
  #   1. Generate an SMTP token in Proton Mail's web UI (Settings > All
  #      settings > IMAP/SMTP > SMTP tokens), scoped to the sending address.
  #   2. cd secrets && nix run github:ryantm/agenix -- -e smtp-protonmail.age
  #      (paste just the token)
  #   3. nix run github:ryantm/agenix -- -e git-send-email-identity.age
  #      (two lines: the bare email, then "Display Name <email>")
  homeManager.modules.git-send-email = { pkgs, ... }: {
    programs.git.settings = {
      sendemail = {
        smtpServer = "smtp.protonmail.ch";
        smtpServerPort = 587;
        smtpEncryption = "tls";
      };

      credential."smtp://smtp.protonmail.ch:587".helper = toString (
        pkgs.writeShellScript "git-credential-protonmail-smtp" ''
          [ "$1" = get ] || exit 0
          echo "username=$(sed -n 1p /run/agenix/git-send-email-identity)"
          echo "password=$(cat /run/agenix/smtp-protonmail)"
        ''
      );
    };

    home.packages = [
      (pkgs.writeShellScriptBin "git-send-email-proton" ''
        identity=/run/agenix/git-send-email-identity
        smtp_user=$(sed -n 1p "$identity")
        from=$(sed -n 2p "$identity")
        exec git send-email --smtp-user="$smtp_user" --from="$from" "$@"
      '')
    ];
  };
}
